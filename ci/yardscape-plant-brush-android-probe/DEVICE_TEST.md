# Galaxy Tab retained-planting device gate

This test collects physical-device evidence for the isolated retained planting
renderer. It does not modify or certify the production Yard-Scape application.

## What is automated

- confirms the selected ADB target is a physical Android device;
- optionally requires the named model before installing or launching;
- installs the exact debug APK and records its SHA-256;
- runs the fixed 3-Fan-Tex, 3-Palo-Verde, and 12-shrub scene three times;
- rejects a wrong recipe, wrong workload, portrait viewport, invalid capture,
  software renderer, shader/source failure, or crash;
- saves in-app and device screenshots, frame samples, `gfxinfo`, `meminfo`,
  battery, thermal-service, package, probe-window, and probe-process logcat
  evidence without collecting unrelated application logs;
- reports a provisional 30 FPS / 50 ms p95 renderer gate without presenting it
  as a full-app or sustained-thermal certification;
- creates a ZIP that can be attached to the implementation review.

No raw ADB serial is saved. The evidence contains only its SHA-256 fingerprint.

## Before running

1. Download and unzip the `retained-planting-android-debug-apk` artifact from
   the green GitHub Actions run.
2. Install Python 3.10 or newer and current Android SDK Platform-Tools on the
   computer running the test.
3. On the tablet, enable Developer options and USB debugging, connect USB, and
   approve that computer when Android asks.
4. Keep the tablet in landscape, unplug external displays, close floating or
   split-screen apps, and use the intended display resolution and refresh rate.
5. Check the exact model reported by ADB:

   ```text
   adb shell getprop ro.product.model
   ```

The script does not change display density, rotation, animation scales, or other
global tablet settings.

## Run the evidence collector

From the unzipped artifact directory, replace `SM-X520` with the value printed
by the command above:

```text
python run_physical_device.py --apk yardscape-retained-planting-debug.apk --expected-model SM-X520
```

On Windows, `py` can be used instead of `python`. Pass `--adb` if Platform-Tools
is not on `PATH`. Pass `--serial` only when more than one authorized Android
device is connected.

The test takes roughly one minute. It leaves the clearly named debug probe
installed so the scene can be reviewed again; it does not change production app
data. The output directory and neighboring ZIP contain the complete evidence.

## Human visual gate

After the screen reads `MEASUREMENT COMPLETE`, drag horizontally to inspect the
crowns from different angles. Do not touch the scene during the timed portion.
Complete `manual-review.json` in the evidence folder and add any notes about:

- whether the Fan-Tex reads as a full shade tree rather than a card cloud;
- whether Palo Verde remains open and visibly distinct from Fan-Tex;
- whether the shrubs read as low mounds rather than miniature trees;
- distracting card shingling, popping, holes, or corrupted foliage;
- whether the overall direction deserves further Northstar art refinement.

The automated test intentionally leaves selection/transform flows, touch
quality, S Pen behavior, and longer thermal testing as separate gates.
