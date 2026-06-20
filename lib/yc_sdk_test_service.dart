import 'dart:async';

import 'package:yc_product_plugin/yc_product_plugin.dart';

import 'sdk_models.dart';
import 'test_log_service.dart';

class YcSdkTestService {
  YcSdkTestService(this._log);

  final TestLogService _log;
  final YcProductPlugin _plugin = YcProductPlugin();
  final StreamController<SdkTestEvent> _events =
      StreamController<SdkTestEvent>.broadcast();

  bool _initialized = false;

  Stream<SdkTestEvent> get events => _events.stream;

  Future<void> initialize() async {
    try {
      _plugin.initPlugin(isReconnectEnable: true, isLogEnable: true);
      _plugin.onListening(_handleSdkEvent);
      _initialized = true;
      _log.add('sdk_initialized');
    } catch (error) {
      _log.add('sdk_init_failed', error.toString());
      rethrow;
    }
  }

  Future<List<SdkRingDevice>> scanDevices() async {
    _ensureInitialized();
    _log.add('scan_started');
    try {
      final dynamic rawDevices = await _plugin.scanDevice(time: 5);
      final List<SdkRingDevice> devices = <SdkRingDevice>[];
      if (rawDevices is Iterable) {
        for (final Object? raw in rawDevices) {
          if (raw == null) {
            continue;
          }
          devices.add(SdkRingDevice.fromSdkDevice(raw));
        }
      }
      _log.add('scan_result_received', {'count': devices.length});
      _log.add('scan_finished');
      return devices;
    } catch (error) {
      _log.add('scan_failed', error.toString());
      rethrow;
    }
  }

  Future<void> connect(SdkRingDevice device) async {
    _ensureInitialized();
    _log.add('connect_started', device.toLogMap());
    try {
      final dynamic rawDevice = device.raw;
      final dynamic result = await _plugin.connectDevice(rawDevice);
      if (result == true) {
        _log.add('connect_success', device.toLogMap());
        return;
      }
      throw StateError('YC SDK connectDevice returned: $result');
    } catch (error) {
      _log.add('connect_failed', error.toString());
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _ensureInitialized();
    try {
      final dynamic result = await _plugin.disconnectDevice();
      _log.add('disconnect', result.toString());
    } catch (error) {
      _log.add('error', {'disconnect': error.toString()});
      rethrow;
    }
  }

  Future<void> queryBasicInfo() async {
    await _runCommand('query_basic_info', () {
      return _plugin.queryDeviceBasicInfo();
    });
  }

  Future<void> queryBattery() {
    throw UnimplementedError('Not confirmed in SDK');
  }

  Future<void> startHeartRateTest() {
    return _measure(
      'start_hr',
      true,
      DeviceAppControlMeasureHealthDataType.heartRate,
    );
  }

  Future<void> stopHeartRateTest() {
    return _measure(
      'stop_hr',
      false,
      DeviceAppControlMeasureHealthDataType.heartRate,
    );
  }

  Future<void> startBloodOxygenTest() {
    return _measure(
      'start_spo2',
      true,
      DeviceAppControlMeasureHealthDataType.bloodOxygen,
    );
  }

  Future<void> stopBloodOxygenTest() {
    return _measure(
      'stop_spo2',
      false,
      DeviceAppControlMeasureHealthDataType.bloodOxygen,
    );
  }

  Future<void> startBloodPressureTest() {
    return _measure(
      'start_bp',
      true,
      DeviceAppControlMeasureHealthDataType.bloodPressure,
    );
  }

  Future<void> stopBloodPressureTest() {
    return _measure(
      'stop_bp',
      false,
      DeviceAppControlMeasureHealthDataType.bloodPressure,
    );
  }

  Future<void> startTemperatureTest() {
    return _measure(
      'start_temperature',
      true,
      DeviceAppControlMeasureHealthDataType.bodyTemperature,
    );
  }

  Future<void> stopTemperatureTest() {
    return _measure(
      'stop_temperature',
      false,
      DeviceAppControlMeasureHealthDataType.bodyTemperature,
    );
  }

  Future<void> startEcgTest() {
    return _runCommand('start_ecg', () {
      return _plugin.startECGMeasurement();
    });
  }

  Future<void> stopEcgTest() {
    return _runCommand('stop_ecg', () {
      return _plugin.stopECGMeasurement();
    });
  }

  Future<void> dispose() async {
    try {
      if (_initialized) {
        _plugin.cancelListening();
      }
    } finally {
      await _events.close();
    }
  }

  Future<void> _measure(
    String command,
    bool start,
    dynamic measureType,
  ) {
    return _runCommand(command, () {
      return _plugin.appControlMeasureHealthData(start, measureType);
    });
  }

  Future<void> _runCommand(
    String command,
    Future<dynamic> Function() run,
  ) async {
    _ensureInitialized();
    _log.add('command_started', command);
    try {
      final dynamic result = await run();
      _log.add('command_success', {command: result.toString()});
    } catch (error) {
      _log.add('command_failed', {command: error.toString()});
      rethrow;
    }
  }

  void _handleSdkEvent(dynamic event) {
    final raw = event.toString();
    final knownEvents = <String, Object?>{};

    void addKnown(String name, Object key) {
      try {
        final dynamic value = event[key];
        if (value != null) {
          knownEvents[name] = value;
          _events.add(SdkTestEvent(name: name, raw: raw, value: value));
          _log.add('measurement_value_received', {
            'callback': name,
            'value': value.toString(),
          });
        }
      } catch (_) {
        // Event payload shape is SDK-owned; ignore keys not present.
      }
    }

    addKnown('bluetoothStateChange', NativeEventType.bluetoothStateChange);
    addKnown('deviceHealthDataMeasureStateChange',
        NativeEventType.deviceHealthDataMeasureStateChange);
    addKnown('deviceRealHeartRate', NativeEventType.deviceRealHeartRate);
    addKnown('deviceRealBloodPressure', NativeEventType.deviceRealBloodPressure);
    addKnown('deviceRealBloodOxygen', NativeEventType.deviceRealBloodOxygen);
    addKnown('deviceRealTemperature', NativeEventType.deviceRealTemperature);
    addKnown('deviceRealECGFilteredData',
        NativeEventType.deviceRealECGFilteredData);
    addKnown('deviceRealECGData', NativeEventType.deviceRealECGData);
    addKnown('deviceRealECGAlgorithmHRV',
        NativeEventType.deviceRealECGAlgorithmHRV);
    addKnown('deviceEndECG', NativeEventType.deviceEndECG);
    addKnown('appECGPPGStatus', NativeEventType.appECGPPGStatus);

    _log.add('sdk_event_received', raw);
    if (knownEvents.isNotEmpty) {
      _log.add('sdk_raw_callback', knownEvents.toString());
    }
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('Initialize SDK first.');
    }
  }
}
