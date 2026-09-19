import sys
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import run_physical_device as device  # noqa: E402


class PhysicalDeviceRunnerTests(unittest.TestCase):
    def test_parse_adb_devices_keeps_only_authorized_devices(self):
        output = (
            "List of devices attached\n"
            "R52X123456\tdevice product:gts10fewifi model:SM-X520\n"
            "emulator-5554\toffline\n"
            "R58M000000\tunauthorized\n\n"
        )
        self.assertEqual(device.parse_adb_devices(output), ["R52X123456"])

    def test_model_match_uses_model_or_market_name(self):
        facts = {
            "manufacturer": "samsung",
            "brand": "samsung",
            "model": "SM-X520",
            "market_name": "Galaxy Tab S10 FE",
            "device": "gts10fewifi",
            "product": "gts10fewifixx",
        }
        self.assertTrue(device.model_matches("SM-X520", facts))
        self.assertTrue(device.model_matches("Galaxy Tab S10 FE", facts))
        self.assertFalse(device.model_matches("SM-X920", facts))

    def test_parse_battery_converts_android_tenths_celsius(self):
        parsed = device.parse_battery("  level: 82\n  temperature: 317\n")
        self.assertEqual(parsed, {"level_percent": 82, "temperature_c": 31.7})

    def test_filter_logcat_excludes_prior_same_pid_entries(self):
        logs = (
            "1758240000.100 1200 1200 I godot : OLD\n"
            "1758240010.000 1200 1200 I godot : YARDSCAPE_BENCHMARK_READY={}\n"
            "--------- beginning of system\n"
        )
        filtered = device.filter_logcat_since(logs, 1758240009.0)
        self.assertNotIn("OLD", filtered)
        self.assertIn("YARDSCAPE_BENCHMARK_READY", filtered)
        self.assertNotIn("beginning of system", filtered)

    def test_validate_exact_hardware_benchmark(self):
        benchmark = {
            "recipe": device.EXPECTED_RECIPE,
            **device.EXPECTED_WORKLOAD,
            "sample_count": 720,
            "rendering_method": "gl_compatibility",
            "viewport_width": 1920,
            "viewport_height": 1200,
            "video_adapter": "ANGLE (Samsung Xclipse)",
            "video_vendor": "Samsung",
            "visual_capture": {"sampled_colors": 256},
        }
        device.validate_benchmark(benchmark)

    def test_validate_rejects_software_renderer(self):
        benchmark = {
            "recipe": device.EXPECTED_RECIPE,
            **device.EXPECTED_WORKLOAD,
            "sample_count": 100,
            "rendering_method": "gl_compatibility",
            "viewport_width": 1920,
            "viewport_height": 1200,
            "video_adapter": "ANGLE (Google, Vulkan 1.3.0 SwiftShader Device)",
            "video_vendor": "Google",
            "visual_capture": {"sampled_colors": 256},
        }
        with self.assertRaisesRegex(RuntimeError, "software renderer"):
            device.validate_benchmark(benchmark)


if __name__ == "__main__":
    unittest.main()
