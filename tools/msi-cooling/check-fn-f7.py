#!/usr/bin/env python3
"""Read only the MSI cooling key's events for 12 seconds; never grab the keyboard."""
import array
import fcntl
import os
from pathlib import Path
import select
import struct
import time

keyboard = next(p for p in Path('/sys/class/input').glob('event*')
                if (p / 'device/name').read_text().strip() == 'AT Translated Set 2 keyboard')
fd = os.open('/dev/input/' + keyboard.name, os.O_RDONLY | os.O_NONBLOCK)
mapping = array.array('I', [0x8a, 0])
fcntl.ioctl(fd, 0x80084504, mapping, True)  # EVIOCGKEYCODE, read only
print('Scan 0x8a currently maps to Linux keycode:', mapping[1], flush=True)
print('Press and release Fn+F7 ONCE now. Watching 12 seconds.', flush=True)
event = struct.Struct('@llHHi')
deadline = time.monotonic() + 12
count = 0
try:
    while time.monotonic() < deadline:
        ready, _, _ = select.select([fd], [], [], max(0, deadline - time.monotonic()))
        if not ready:
            break
        data = os.read(fd, event.size * 64)
        for pos in range(0, len(data), event.size):
            sec, usec, kind, code, value = event.unpack_from(data, pos)
            if kind == 4 and code == 4 and value == 0x8a:
                print(f'{sec}.{usec:06d} scan 0x8a', flush=True)
            elif kind == 1 and code == mapping[1] and code != 0:
                count += 1
                print(f'{sec}.{usec:06d} key {code}: ' + {0: 'release', 1: 'press', 2: 'repeat'}.get(value, str(value)), flush=True)
    print(f'Done: {count} matching key events.', flush=True)
finally:
    os.close(fd)
