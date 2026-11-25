"""Policy and control tests use simulated temperatures and temporary files."""
import importlib.util
import json
import multiprocessing
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('cooling', Path(__file__).with_name('controller.py'))
c = importlib.util.module_from_spec(spec)
spec.loader.exec_module(c)


class CoolingTests(unittest.TestCase):
    def test_presets(self):
        p = c.Policy()
        self.assertEqual(p.step('quiet', 55, 0)[:2], ('power-saver', False))
        self.assertEqual(p.step('balanced', 55, 5)[:2], ('balanced', False))
        self.assertEqual(p.step('boost', 55, 10)[:2], ('balanced', True))

    def test_spike_does_not_start_boost(self):
        p = c.Policy()
        self.assertEqual(p.step('dynamic', 87, 0)[:2], ('balanced', False))
        self.assertEqual(p.step('dynamic', 60, 5)[:2], ('balanced', False))
        self.assertEqual(p.step('dynamic', 87, 10)[:2], ('balanced', False))

    def test_warm_uses_power_saver_before_fan_boost(self):
        p = c.Policy()
        p.step('dynamic', 81, 0)
        self.assertEqual(p.step('dynamic', 81, 10)[:2], ('balanced', False))
        self.assertEqual(p.step('dynamic', 81, 15)[:2], ('power-saver', False))

    def test_hot_boost_and_cooldown_hysteresis(self):
        p = c.Policy()
        p.step('dynamic', 87, 0)
        self.assertTrue(p.step('dynamic', 87, 10)[1])
        p.step('dynamic', 70, 15)
        self.assertTrue(p.step('dynamic', 70, 45)[1])
        self.assertEqual(p.step('dynamic', 70, 70)[:2], ('balanced', False))

    def test_interrupted_cooldown_does_not_stop_boost(self):
        p = c.Policy()
        p.step('dynamic', 87, 0)
        p.step('dynamic', 87, 10)
        p.step('dynamic', 70, 15)
        p.step('dynamic', 76, 40)
        p.step('dynamic', 70, 65)
        self.assertTrue(p.step('dynamic', 70, 70)[1])
        self.assertFalse(p.step('dynamic', 70, 95)[1])

    def test_manual_quiet_cancels_normal_dynamic_boost(self):
        p = c.Policy()
        p.step('dynamic', 87, 0)
        p.step('dynamic', 87, 10)
        self.assertEqual(p.step('quiet', 80, 15)[:2], ('power-saver', False))

    def test_emergency_overrides_quiet_and_survives_mode_change(self):
        p = c.Policy()
        self.assertEqual(p.step('quiet', 92, 0)[:2], ('power-saver', True))
        self.assertEqual(p.step('balanced', 82, 5)[:2], ('power-saver', True))
        p.step('balanced', 76, 10)
        self.assertTrue(p.step('balanced', 76, 40)[1])
        self.assertEqual(p.step('balanced', 76, 60)[:2], ('balanced', False))

    def test_missing_sensor_and_recovery(self):
        p = c.Policy()
        p.step('dynamic', 60, 0)
        self.assertFalse(p.step('dynamic', None, 5)[1])
        self.assertFalse(p.step('dynamic', None, 10)[1])
        self.assertEqual(p.step('dynamic', None, 15)[:2], ('power-saver', True))
        p.step('dynamic', 60, 20)
        self.assertTrue(p.step('dynamic', 60, 50)[1])
        self.assertFalse(p.step('dynamic', 60, 75)[1])

    def test_toggle_returns_to_each_previous_preset(self):
        for mode in c.MODES[:-1]:
            initial = {'mode': mode, 'return_mode': 'dynamic'}
            boost = c.next_configuration(initial, 'toggle')
            self.assertEqual(boost, {'mode': 'boost', 'return_mode': mode})
            self.assertEqual(c.next_configuration(boost, 'toggle')['mode'], mode)
            self.assertEqual(initial['mode'], mode)

    def test_cycle_and_reject_arbitrary_command(self):
        value = {'mode': 'quiet', 'return_mode': 'dynamic'}
        for expected in ['balanced', 'dynamic', 'boost', 'quiet']:
            value = c.next_configuration(value, 'cycle')
            self.assertEqual(value['mode'], expected)
        with self.assertRaises(ValueError):
            c.next_configuration(value, '/bin/sh')

    def test_control_write_and_status_atomic_save(self):
        with tempfile.TemporaryDirectory() as d, patch.object(c, 'EC', Path(d)):
            control = Path(d) / 'cooler_boost'
            control.write_text('off\n')
            c.set_control('cooler_boost', 'on')
            self.assertEqual(control.read_text(), 'on\n')
            c.set_control('cooler_boost', 'off')
            self.assertEqual(control.read_text(), 'off\n')
            status = Path(d) / 'status.json'
            c.save(status, {'mode': 'dynamic'})
            self.assertEqual(json.loads(status.read_text()), {'mode': 'dynamic'})

    def test_daemon_applies_modes_and_restores(self):
        # Real daemon loop and atomic state files; all hardware and D-Bus are fake.
        with tempfile.TemporaryDirectory() as d:
            base = Path(d)
            runtime, state, ec = base/'run', base/'state', base/'ec'
            for p in (runtime, state, ec):
                p.mkdir()
            (ec/'fan_mode').write_text('auto\n')
            (ec/'cooler_boost').write_text('off\n')
            profile = base/'profile'
            profile.write_text('balanced')
            status = runtime/'status.json'
            config = state/'mode.json'
            real_sleep = time.sleep
            patches = dict(RUNTIME=runtime, STATE=state, EC=ec, CONFIG=config, STATUS=status,
                           temperature=lambda: 55, rpm=lambda: 2200,
                           profile_get=lambda: profile.read_text(),
                           profile_set=lambda value: profile.write_text(value))
            def worker():
                with patch.object(c.time, 'sleep', lambda delay: real_sleep(min(delay, .01))):
                    c.daemon()
            def wait_for(predicate):
                deadline = time.monotonic()+3
                while time.monotonic()<deadline:
                    try:
                        value=json.loads(status.read_text())
                        if predicate(value):
                            return value
                    except (OSError, ValueError):
                        pass
                    real_sleep(.02)
                self.fail('Daemon did not reach expected state')
            with patch.multiple(c, **patches):
                proc=multiprocessing.get_context('fork').Process(target=worker)
                proc.start()
                try:
                    wait_for(lambda s: s.get('mode')=='dynamic' and s.get('profile')=='balanced')
                    c.save(config, {'mode':'quiet','return_mode':'dynamic'})
                    wait_for(lambda s: s.get('mode')=='quiet' and s.get('profile')=='power-saver')
                    self.assertEqual(profile.read_text(),'power-saver')
                    c.save(config, {'mode':'boost','return_mode':'quiet'})
                    wait_for(lambda s: s.get('mode')=='boost' and s.get('boost') is True)
                    self.assertEqual((ec/'cooler_boost').read_text().strip(),'on')
                finally:
                    proc.terminate()
                    proc.join(timeout=3)
                    if proc.is_alive():
                        proc.kill()
                        proc.join()
                self.assertEqual(proc.exitcode,0)
                c.restore()
                self.assertEqual(profile.read_text(),'balanced')
                self.assertEqual((ec/'cooler_boost').read_text().strip(),'off')
                self.assertFalse(status.exists())


if __name__ == '__main__':
    unittest.main()
