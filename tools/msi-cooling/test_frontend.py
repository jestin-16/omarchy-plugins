"""Exercise notification timing and replacement without touching the real fans."""
import contextlib
import importlib.machinery
import importlib.util
import io
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest
from unittest.mock import patch

loader = importlib.machinery.SourceFileLoader('cooling_ui', str(Path(__file__).parent / 'bin/msi-cooling'))
spec = importlib.util.spec_from_loader(loader.name, loader)
ui = importlib.util.module_from_spec(spec)
loader.exec_module(ui)


class NotificationTests(unittest.TestCase):
    def test_mode_selection_does_not_wait_for_hardware_status(self):
        with tempfile.TemporaryDirectory() as d:
            base=Path(d)
            helper=base/'helper'
            helper.touch()
            calls=[]
            def fake_run(args, **kwargs):
                calls.append(args)
                return subprocess.CompletedProcess(args, 0, 'boost\n' if args[0].endswith('pkexec') else '73\n', '')
            with patch.object(ui,'HELPER',helper), patch.object(ui,'UI_STATE',base), \
                 patch.object(ui.subprocess,'run',side_effect=fake_run), \
                 patch.object(ui,'status',side_effect=AssertionError('Must not wait for sensor status')), \
                 patch.object(ui.time,'sleep',side_effect=AssertionError('Must not poll')), \
                 patch.object(ui.sys,'argv',['msi-cooling','cycle']), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(ui.main(),0)
            self.assertEqual(len(calls),2)
            self.assertIn('Boost selected',calls[1][-1])
            self.assertNotIn('RPM',calls[1][-1])

    def test_consecutive_selections_replace_previous_toast(self):
        with tempfile.TemporaryDirectory() as d:
            base=Path(d); helper=base/'helper'; helper.touch()
            modes=iter(['quiet','balanced','dynamic','boost'])
            notifications=[]
            def fake_run(args, **kwargs):
                if args[0].endswith('pkexec'):
                    return subprocess.CompletedProcess(args,0,next(modes)+'\n','')
                notifications.append(args)
                return subprocess.CompletedProcess(args,0,'81\n','')
            with patch.object(ui,'HELPER',helper), patch.object(ui,'UI_STATE',base), \
                 patch.object(ui.subprocess,'run',side_effect=fake_run), \
                 patch.object(ui.sys,'argv',['msi-cooling','cycle']), contextlib.redirect_stdout(io.StringIO()):
                for _ in range(4):
                    self.assertEqual(ui.main(),0)
            ids=[args[args.index('-r')+1] for args in notifications]
            self.assertEqual(ids,['0','81','81','81'])
            self.assertEqual([a[-1].splitlines()[0] for a in notifications],
                             ['Quiet selected','Balanced selected','Dynamic selected','Boost selected'])

    def test_old_notification_id_is_not_reused(self):
        with tempfile.TemporaryDirectory() as d:
            base=Path(d); f=base/'notification-id'; f.write_text('123')
            os.utime(f,(time.time()-60,time.time()-60))
            with patch.object(ui,'UI_STATE',base), patch.object(ui.subprocess,'run') as run:
                run.return_value=subprocess.CompletedProcess([],0,'82\n','')
                ui.notify('Balanced selected')
                args=run.call_args.args[0]
                self.assertEqual(args[args.index('-r')+1],'0')

    def test_failed_selection_does_not_claim_success(self):
        with tempfile.TemporaryDirectory() as d:
            base=Path(d); helper=base/'helper'; helper.touch()
            def fake_run(args, **kwargs):
                return subprocess.CompletedProcess(args,1,'','Service unavailable')
            with patch.object(ui,'HELPER',helper), patch.object(ui,'UI_STATE',base), \
                 patch.object(ui.subprocess,'run',side_effect=fake_run), patch.object(ui,'notify') as notify, \
                 patch.object(ui.sys,'argv',['msi-cooling','cycle']), contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(ui.main(),1)
                notify.assert_called_once_with('Service unavailable')

    def test_status_still_reports_measured_values(self):
        value=dict(mode='dynamic',stage='normal',temperature=48,rpm=2300,profile='balanced',boost=False)
        text=ui.describe(value)
        self.assertIn('48°C',text)
        self.assertIn('2300 RPM',text)
        self.assertIn('Boost OFF',text)


if __name__ == '__main__':
    unittest.main()
