#!/usr/bin/python3 -I
"""Fixed MSI cooling controls. No user-supplied paths or shell commands."""
import contextlib
import fcntl
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

MODES = ('quiet', 'balanced', 'dynamic', 'boost')
EC = Path('/sys/devices/platform/msi-ec')
RUNTIME = Path('/run/msi-cooling')
STATE = Path('/var/lib/msi-cooling')
CONFIG = STATE / 'mode.json'
STATUS = RUNTIME / 'status.json'


class Policy:
    """Temperature thresholds are local defaults, not MSI specifications."""
    def __init__(self):
        self.mode = None
        self.stage = 'normal'
        self.emergency = False
        self.since = {}
        self.boost_since = None
        self.last = ('balanced', False, 'normal')

    def held(self, name, condition, seconds, now):
        if not condition:
            self.since.pop(name, None)
            return False
        return now - self.since.setdefault(name, now) >= seconds

    def step(self, mode, temperature, now):
        if mode not in MODES:
            raise ValueError('Unknown cooling mode')
        if mode != self.mode:
            self.mode, self.stage = mode, 'normal'
            # Keep emergency protection across manual mode changes.
            self.since = {k: v for k, v in self.since.items() if k.startswith('emergency') or k == 'missing'}
        missing = temperature is None
        sensor_failed = self.held('missing', missing, 10, now)
        if sensor_failed or (not missing and temperature >= 92):
            if not self.emergency:
                self.boost_since = now
            self.emergency = True
        if missing and not self.emergency:
            return self.last  # tolerate two missed sensor reads without reducing cooling
        if self.emergency:
            cool = self.held('emergency_cool', not missing and temperature <= 78, 30, now)
            if cool and now - self.boost_since >= 60:
                self.emergency = False
                self.stage = 'normal'
            else:
                self.last = ('power-saver', True, 'sensor protection' if missing else 'heat protection')
                return self.last
        if mode == 'dynamic':
            warm = self.held('warm', temperature >= 80, 15, now)
            hot = self.held('hot', temperature >= 86, 10, now)
            cool = self.held('cool', temperature <= 72, 30, now)
            if hot and self.stage != 'boost':
                self.stage, self.boost_since = 'boost', now
            elif warm and self.stage == 'normal':
                self.stage = 'reduce power'
            if cool and (self.stage != 'boost' or now - self.boost_since >= 60):
                self.stage = 'normal'
            self.last = ('balanced' if self.stage == 'normal' else 'power-saver',
                         self.stage == 'boost', self.stage)
        else:
            self.last = ('power-saver' if mode == 'quiet' else 'balanced', mode == 'boost', mode)
        return self.last


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True, timeout=8).stdout.strip()


def directories():
    RUNTIME.mkdir(mode=0o755, exist_ok=True)
    STATE.mkdir(mode=0o755, exist_ok=True)
    # Previous single-toggle setup used a private runtime directory.
    RUNTIME.chmod(0o755)


@contextlib.contextmanager
def locked(name, nonblocking=False):
    with (RUNTIME / name).open('a') as f:
        fcntl.flock(f, fcntl.LOCK_EX | (fcntl.LOCK_NB if nonblocking else 0))
        yield


def save(path, value):
    tmp = path.with_suffix('.tmp')
    tmp.write_text(json.dumps(value) + '\n')
    tmp.chmod(0o644)
    tmp.replace(path)


def configuration():
    if not CONFIG.exists():
        return {'mode': 'dynamic', 'return_mode': 'dynamic'}
    value = json.loads(CONFIG.read_text())
    if value.get('mode') not in MODES or value.get('return_mode') not in MODES[:-1]:
        raise ValueError('Invalid saved cooling mode')
    return value


def next_configuration(value, command):
    value = dict(value)
    current = value['mode']
    if command == 'toggle':
        selected = value['return_mode'] if current == 'boost' else 'boost'
    elif command == 'cycle':
        selected = MODES[(MODES.index(current) + 1) % len(MODES)]
    elif command in MODES:
        selected = command
    else:
        raise ValueError('Invalid mode command')
    if selected == 'boost' and current != 'boost':
        value['return_mode'] = current
    value['mode'] = selected
    return value


def select_mode(command):
    run('/usr/bin/systemctl', 'is-active', '--quiet', 'msi-cooling.service')
    with locked('mode.lock'):
        value = next_configuration(configuration(), command)
        save(CONFIG, value)
    print(value['mode'])


def number(path, divisor=1):
    try:
        return float(path.read_text()) / divisor
    except (OSError, ValueError):
        return None


def temperature():
    cpu = []
    for hw in Path('/sys/class/hwmon').glob('hwmon*'):
        try:
            if (hw / 'name').read_text().strip() != 'coretemp':
                continue
        except OSError:
            continue
        cpu.extend(number(p, 1000) for p in hw.glob('temp*_input'))
    cpu.append(number(EC / 'cpu/realtime_temperature'))
    cpu = [v for v in cpu if v is not None and 0 < v <= 130]
    if not cpu:
        return None
    gpu = number(EC / 'gpu/realtime_temperature')
    if gpu is not None and 0 < gpu <= 130:
        cpu.append(gpu)
    return max(cpu)


def rpm():
    for hw in Path('/sys/class/hwmon').glob('hwmon*'):
        try:
            if (hw / 'name').read_text().strip() == 'msi_wmi_platform':
                return number(hw / 'fan1_input')
        except OSError:
            pass
    return None


def set_control(name, value):
    path = EC / name
    if path.read_text().strip() != value:
        path.write_text(value + '\n')
        for _ in range(5):
            if path.read_text().strip() == value:
                return
            time.sleep(0.1)
        raise RuntimeError(f'{name} did not accept {value}')


def profile_get():
    # Use native busctl: Omarchy documents a Python/PyGObject shutdown race in get.
    raw = run('/usr/bin/busctl', '--system', 'get-property',
              'net.hadess.PowerProfiles', '/net/hadess/PowerProfiles',
              'net.hadess.PowerProfiles', 'ActiveProfile')
    return raw.removeprefix('s ').strip('"')


def profile_set(profile):
    run('/usr/bin/busctl', '--system', 'set-property',
        'net.hadess.PowerProfiles', '/net/hadess/PowerProfiles',
        'net.hadess.PowerProfiles', 'ActiveProfile', 's', profile)


def restore():
    # Stopping the service returns responsibility to the firmware and Omarchy.
    errors = []
    for name, value in [('fan_mode', 'auto'), ('cooler_boost', 'off')]:
        try:
            set_control(name, value)
        except Exception as e:
            errors.append(str(e))
    try:
        profile_set('balanced')
    except Exception as e:
        errors.append(str(e))
    STATUS.unlink(missing_ok=True)
    if errors:
        raise RuntimeError('; '.join(errors))


def daemon():
    with locked('daemon.lock', nonblocking=True):
        policy = Policy()
        stopping = False
        def stop(*_):
            nonlocal stopping
            stopping = True
        signal.signal(signal.SIGTERM, stop)
        signal.signal(signal.SIGINT, stop)
        last_profile_check = float('-inf')
        actual_profile = None
        last_log = None
        while not stopping:
            now = time.monotonic()
            status = {'updated': time.time()}
            try:
                mode = configuration()['mode']
                temp = temperature()
                profile, boost, stage = policy.step(mode, temp, now)
                status.update(mode=mode, temperature=temp, stage=stage)
                # Cooling is applied even if the power-profile service is unavailable.
                set_control('fan_mode', 'auto')
                set_control('cooler_boost', 'on' if boost else 'off')
                if profile != actual_profile or now - last_profile_check >= 30:
                    actual_profile = profile_get()
                    if actual_profile != profile:
                        profile_set(profile)
                        actual_profile = profile_get()
                        if actual_profile != profile:
                            raise RuntimeError('Power profile change did not take effect')
                    last_profile_check = now
                status.update(profile=actual_profile, boost=boost, rpm=rpm())
            except Exception as e:
                status['error'] = str(e)
                actual_profile = None
            save(STATUS, status)
            log = (status.get('mode'), status.get('stage'), status.get('error'))
            if log != last_log:
                print(json.dumps(status), flush=True)
                last_log = log
            for _ in range(10):
                if stopping:
                    break
                time.sleep(0.5)


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in (*MODES, 'toggle', 'cycle', 'daemon', 'restore'):
        raise ValueError('Expected quiet, balanced, dynamic, boost, toggle, cycle, daemon or restore')
    if os.geteuid() != 0:
        raise PermissionError('Run this fixed helper through pkexec or systemd')
    directories()
    command = sys.argv[1]
    if command == 'daemon':
        daemon()
    elif command == 'restore':
        restore()
    else:
        select_mode(command)


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
