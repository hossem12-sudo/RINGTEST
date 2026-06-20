# YC SDK Smoke Test

This app tests the real YC Flutter SDK/plugin.

This is not a generic BLE test.

This app does not search for one specific ring.

This app does not auto-select a device.

This app scans all devices returned by the YC SDK.

The user manually selects which device to test.

This must run on a real Android phone.

## Target Context

The target ring context is `TK30 9F37`, but the BLE advertised name may be different. The app displays every device returned by the YC SDK and lets the user manually choose the device.

Visual "Possible ring" hints are only labels. They never select or connect a device.

## Commands

```bash
cd BioPulseRingApp/tools/yc_sdk_smoke_test
flutter clean
flutter pub get
flutter doctor
flutter devices
flutter run
```

For logs:

```bash
flutter logs
```

For debug APK:

```bash
flutter build apk --debug
```

## Manual Test Steps

1. Connect a real Android phone.
2. Make sure Bluetooth is ON.
3. Make sure the ring is charged and near the phone.
4. Make sure the ring is not connected to another app/phone.
5. Run `flutter run`.
6. Tap Request Permissions.
7. Tap Initialize SDK.
8. Tap Scan Devices.
9. Review all SDK scan results.
10. Manually select the device that appears to be the ring.
11. Tap Connect Selected Device.
12. Run Query Basic Info or Query Battery if available.
13. Run HR/SpO2/BP/temperature/ECG commands only if available.
14. Export logs or run `flutter logs`.
15. Send logs/screenshots for analysis.

## Safety

This smoke test does not fuzz, brute force, send random bytes, attempt DFU, update firmware, reset the ring, erase the ring, modify ring settings, send unconfirmed commands, or fake SDK results.

## SDK Calls Used

- `YcProductPlugin().initPlugin(isReconnectEnable: true, isLogEnable: true)`
- `YcProductPlugin().onListening(...)`
- `YcProductPlugin().scanDevice(time: 5)`
- `YcProductPlugin().connectDevice(device)`
- `YcProductPlugin().disconnectDevice()`
- `YcProductPlugin().queryDeviceBasicInfo()`
- `YcProductPlugin().appControlMeasureHealthData(...)`
- `YcProductPlugin().startECGMeasurement()`
- `YcProductPlugin().stopECGMeasurement()`

## Not Confirmed

Battery query was not confirmed from the Flutter SDK example/API surface available in this workspace, so the Query Battery button is disabled and marked `Not confirmed in SDK`.
