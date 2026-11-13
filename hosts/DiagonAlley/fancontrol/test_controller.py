from __future__ import annotations

import copy
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock


CONTROLLER_PATH = Path(__file__).with_name("controller.py")
SPEC = importlib.util.spec_from_file_location("diagonalley_fan_control", CONTROLLER_PATH)
assert SPEC is not None and SPEC.loader is not None
controller_module = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = controller_module
SPEC.loader.exec_module(controller_module)


class ControllerTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        root = Path(self.temporary.name)
        self.sys_root = root / "sys"
        self.hwmon_root = self.sys_root / "class" / "hwmon"
        self.hwmon_root.mkdir(parents=True)
        self.it87 = self.add_hwmon(
            7,
            "it8689",
            "devices/platform/it87.2624",
            {
                "fan1_input": "1646\n",
                "fan3_input": "589\n",
                "fan4_input": "608\n",
                "pwm1": "96\n",
                "pwm3": "64\n",
                "pwm4": "64\n",
                "pwm1_enable": "2\n",
                "pwm3_enable": "2\n",
                "pwm4_enable": "2\n",
            },
        )
        self.k10temp = self.add_hwmon(
            2,
            "k10temp",
            "devices/pci0000:00/0000:00:18.3",
            {"temp1_input": "51125\n"},
        )
        self.paths = controller_module.Paths(
            sysfs_root=self.hwmon_root,
            sys_root=self.sys_root,
            state_file=root / "state" / "state.json",
            config_file=root / "run" / "fancontrol.conf",
            lock_file=root / "run" / "control.lock",
            systemctl="/bin/systemctl-test",
            pkexec="/bin/pkexec-test",
            helper="/bin/helper-test",
            fancontrol="/bin/fancontrol-test",
        )
        self.controller = controller_module.Controller(self.paths)

    def add_hwmon(
        self,
        index: int,
        name: str,
        device_path: str,
        files: dict[str, str],
    ) -> Path:
        device = self.sys_root / device_path
        device.mkdir(parents=True)
        hwmon = self.hwmon_root / f"hwmon{index}"
        hwmon.mkdir()
        (hwmon / "name").write_text(name + "\n", encoding="utf-8")
        (hwmon / "device").symlink_to(device)
        for filename, content in files.items():
            (hwmon / filename).write_text(content, encoding="utf-8")
        return hwmon

    def write_state(self, state: dict[str, object]) -> None:
        self.paths.state_file.parent.mkdir(parents=True, exist_ok=True)
        self.paths.state_file.write_text(json.dumps(state), encoding="utf-8")

    def test_status_discovers_devices_without_fixed_hwmon_numbers(self) -> None:
        with mock.patch.object(self.controller, "service_active", return_value=False):
            status = self.controller.status()

        self.assertTrue(status["available"])
        self.assertEqual(status["controlMode"], "bios")
        self.assertEqual(status["temperature"], 51)
        self.assertEqual(status["fans"]["cpu"]["rpm"], 1646)
        self.assertEqual(status["fans"]["case1"]["rpm"], 589)
        self.assertEqual(status["fans"]["case2"]["rpm"], 608)

    def test_status_requires_every_managed_channel_for_bios_ownership(self) -> None:
        (self.it87 / "pwm4_enable").unlink()

        with mock.patch.object(self.controller, "service_active", return_value=False):
            status = self.controller.status()

        self.assertEqual(status["controlMode"], "degraded")

    def test_separate_cpu_and_case_curves_are_rendered_for_fancontrol(self) -> None:
        state = copy.deepcopy(controller_module.DEFAULT_STATE)
        state["mode"] = "software"
        state["cpu"].update({"minPwm": 104, "startTemp": 52, "fullTemp": 82})
        state["case"].update({"minPwm": 72, "startTemp": 48, "fullTemp": 78})

        config = self.controller.build_config(state)

        self.assertIn(
            "DEVPATH=hwmon7=devices/platform/it87.2624 "
            "hwmon2=devices/pci0000:00/0000:00:18.3",
            config,
        )
        self.assertIn(
            "FCTEMPS=hwmon7/pwm1=hwmon2/temp1_input "
            "hwmon7/pwm3=hwmon2/temp1_input hwmon7/pwm4=hwmon2/temp1_input",
            config,
        )
        self.assertIn("MINTEMP=hwmon7/pwm1=52 hwmon7/pwm3=48 hwmon7/pwm4=48", config)
        self.assertIn("MINPWM=hwmon7/pwm1=104 hwmon7/pwm3=72 hwmon7/pwm4=72", config)

    def test_zero_rpm_keeps_temperature_protection(self) -> None:
        state = copy.deepcopy(controller_module.DEFAULT_STATE)
        state["mode"] = "software"
        state["cpu"]["zeroRpm"] = True
        state["case"]["zeroRpm"] = True

        config = self.controller.build_config(state)

        self.assertIn("MINPWM=hwmon7/pwm1=0 hwmon7/pwm3=0 hwmon7/pwm4=0", config)
        self.assertIn("MINSTART=hwmon7/pwm1=128 hwmon7/pwm3=96 hwmon7/pwm4=96", config)
        self.assertIn("MINSTOP=hwmon7/pwm1=96 hwmon7/pwm3=64 hwmon7/pwm4=64", config)
        self.assertIn("MAXPWM=hwmon7/pwm1=255 hwmon7/pwm3=255 hwmon7/pwm4=255", config)

    def test_validation_rejects_unsafe_or_unknown_values(self) -> None:
        state = copy.deepcopy(controller_module.DEFAULT_STATE)
        with self.assertRaisesRegex(controller_module.ControlError, "at least 10 C"):
            controller_module.merge_patch(
                state,
                {"cpu": {"startTemp": 65, "fullTemp": 70}},
            )
        with self.assertRaisesRegex(controller_module.ControlError, "unknown case settings"):
            controller_module.merge_patch(state, {"case": {"command": "anything"}})
        with self.assertRaisesRegex(controller_module.ControlError, "between 64 and 128"):
            controller_module.merge_patch(state, {"case": {"minPwm": 32}})

    def test_restore_bios_updates_only_managed_channels(self) -> None:
        for channel in (1, 3, 4):
            (self.it87 / f"pwm{channel}_enable").write_text("1\n", encoding="ascii")

        with mock.patch.object(controller_module.os, "geteuid", return_value=0):
            self.controller.restore_bios()

        for channel in (1, 3, 4):
            self.assertEqual(
                (self.it87 / f"pwm{channel}_enable").read_text(encoding="ascii"),
                "2\n",
            )

    def test_failed_software_start_falls_back_to_bios(self) -> None:
        failed = controller_module.subprocess.CompletedProcess(
            args=[],
            returncode=1,
            stdout="",
            stderr="start failed",
        )
        stopped = controller_module.subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr="")
        with (
            mock.patch.object(controller_module.os, "geteuid", return_value=0),
            mock.patch.object(self.controller, "systemctl", side_effect=[failed, stopped]),
            self.assertRaisesRegex(controller_module.ControlError, "start failed"),
        ):
            self.controller.apply_root({"mode": "software"})

        stored = json.loads(self.paths.state_file.read_text(encoding="utf-8"))
        self.assertEqual(stored["mode"], "bios")
        for channel in (1, 3, 4):
            self.assertEqual(
                (self.it87 / f"pwm{channel}_enable").read_text(encoding="ascii"),
                "2\n",
            )

    @unittest.skipUnless(os.environ.get("FANCONTROL_UNDER_TEST"), "fancontrol executable not provided")
    def test_real_fancontrol_accepts_config_and_restores_fake_hwmon(self) -> None:
        state = copy.deepcopy(controller_module.DEFAULT_STATE)
        state["mode"] = "software"
        config = self.controller.build_config(state, absolute=True)
        config_path = Path(self.temporary.name) / "fancontrol.conf"
        config_path.write_text(config, encoding="utf-8")
        original_pwm = {
            channel: (self.it87 / f"pwm{channel}").read_text(encoding="ascii")
            for channel in (1, 3, 4)
        }

        output_path = Path(self.temporary.name) / "fancontrol.log"
        with output_path.open("w", encoding="utf-8") as log:
            process = subprocess.Popen(
                [os.environ["FANCONTROL_UNDER_TEST"], str(config_path)],
                stdout=log,
                stderr=subprocess.STDOUT,
                text=True,
            )
            try:
                # Enabling PWM precedes the fan spin-up checks. Wait for the
                # control loop too, including when running through qemu-user.
                deadline = time.monotonic() + 30
                while time.monotonic() < deadline:
                    if "Starting automatic fan control" in output_path.read_text(encoding="utf-8"):
                        break
                    if process.poll() is not None:
                        break
                    time.sleep(0.05)
                self.assertIsNone(process.poll())
                self.assertTrue(
                    all(
                        (self.it87 / f"pwm{channel}_enable").read_text(encoding="ascii").strip()
                        == "1"
                        for channel in (1, 3, 4)
                    )
                )
            finally:
                process.terminate()
                process.communicate(timeout=10)

        output = output_path.read_text(encoding="utf-8")
        self.assertIn("Starting automatic fan control", output)
        for channel in (1, 3, 4):
            self.assertEqual(
                (self.it87 / f"pwm{channel}_enable").read_text(encoding="ascii"),
                "2\n",
            )
            self.assertEqual(
                (self.it87 / f"pwm{channel}").read_text(encoding="ascii"),
                original_pwm[channel],
            )


if __name__ == "__main__":
    unittest.main()
