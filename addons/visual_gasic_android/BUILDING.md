# Building the VGAndroidPlugin .aar

The Kotlin sources in `vg_android_plugin/` compile to a single
`VGAndroidPlugin.aar` (~15-40 KB) that lives next to `VGAndroidPlugin.gdap`
in this folder.  Godot's Android export pipeline picks both up automatically
when **"Use Gradle Build"** is enabled in the Android export preset.

On any non-Android target (desktop, headless) the engine never loads the
plugin, and the VG runtime falls back to the safe zero/`-1` stubs already
registered in `src/visual_gasic_builtins.cpp`.  So shipping the `.aar` is
only required for the Android export — the rest of the toolchain runs fine
without it.

## Prerequisites

- **JDK 17** (`sudo apt install openjdk-17-jdk` on Debian/Ubuntu).
- **Android SDK** with platforms `android-34` and build-tools `34.0.0`.
  Easiest source is Android Studio; otherwise grab the
  [commandline-tools] package and run `sdkmanager 'platforms;android-34'
  'build-tools;34.0.0'`.
- **`ANDROID_HOME`** environment variable pointing at the SDK root.
- The **Godot 4.x Android AAR** in your local Maven cache, matching the
  engine version you're shipping.  Get it once with:

  ```bash
  godot --export-debug-android-template --headless --quit  # not strictly
                                                            # needed; see below
  ```

  Or download `godot-lib.<version>.release.aar` from the
  [Godot Engine releases][gh-rel] page and install it locally:

  ```bash
  mvn install:install-file \
      -Dfile=godot-lib.4.6.1.stable.release.aar \
      -DgroupId=org.godotengine \
      -DartifactId=godot \
      -Dversion=4.6.1.stable \
      -Dpackaging=aar
  ```

  (Pin the version to match the Godot you build VisualGasic against.)

[commandline-tools]: https://developer.android.com/studio#command-line-tools-only
[gh-rel]: https://github.com/godotengine/godot/releases

## Build

```bash
cd addons/visual_gasic_android
./gradlew :vg_android_plugin:assembleRelease
cp vg_android_plugin/build/outputs/aar/VGAndroidPlugin-release.aar \
   ./VGAndroidPlugin.aar
```

That's it.  Re-export the Android template and the plugin gets bundled.

## What's inside

- **Permissions** — runtime `requestPermissions(...)` with result routed to
  Godot signals `permission_granted` / `permission_denied`, both forwarded
  to the VG global subs of the same names.
- **GPS** — `LocationManager` GPS + NETWORK providers, 1-Hz updates,
  emits `gps_updated(lat, lng, alt, accuracy_m, speed_mps)`.  Each scalar
  is also reachable via `GPS.Lat / .Lng / .Alt / .Speed / .Accuracy`.
- **Steps** — `SensorManager.TYPE_STEP_COUNTER`, with an automatic midnight
  baseline so `Steps.Today` rolls over without needing a service.  Emits
  `steps_detected(today, total)` on every sensor delivery (typically every
  few seconds while walking).  `Steps.Reset` re-anchors both baselines.

## Signal → VG sub mapping

All of these auto-wire to global `Sub` definitions in any `.vg` script.
Define any subset you care about:

```basic
Sub Permission_Granted(name As String)
    Print "User said yes to " & name
End Sub

Sub Permission_Denied(name As String)
    Print "User said no to " & name
End Sub

Sub GPS_Updated(lat As Double, lng As Double, alt As Double, _
                accuracy As Double, speed As Double)
    Print "Pos: " & lat & ", " & lng
End Sub

Sub Steps_Detected(today As Integer, total As Integer)
    Print "Walked " & today & " steps today (" & total & " session)"
End Sub
```

(Note: VG-BASIC currently has no `_` line continuation — split the GPS
sub across two definitions or write it on one line.)

## Size

The compiled `.aar` is tiny — about 20 KB before consumer-side ProGuard.
Bundled into VisualGasic; no installer download dance needed.
