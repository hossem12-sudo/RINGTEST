import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'sdk_models.dart';
import 'test_log_service.dart';
import 'yc_sdk_test_service.dart';

void main() {
  runApp(const YcSdkSmokeTestApp());
}

class YcSdkSmokeTestApp extends StatelessWidget {
  const YcSdkSmokeTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'YC SDK Smoke Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const SmokeTestScreen(),
    );
  }
}

class SmokeTestScreen extends StatefulWidget {
  const SmokeTestScreen({super.key});

  @override
  State<SmokeTestScreen> createState() => _SmokeTestScreenState();
}

class _SmokeTestScreenState extends State<SmokeTestScreen> {
  late final TestLogService _log;
  late final YcSdkTestService _sdk;
  StreamSubscription<SdkTestEvent>? _eventSubscription;

  String _sdkStatus = 'Not initialized';
  String _bluetoothPermissionStatus = 'Unknown';
  String _locationPermissionStatus = 'Unknown';
  String _scanStatus = 'Idle';
  String _connectionStatus = 'idle';
  String _lastSdkEvent = 'None';
  String _lastError = 'None';

  bool _isInitialized = false;
  bool _isScanning = false;
  bool _isBusy = false;

  List<SdkRingDevice> _devices = <SdkRingDevice>[];
  SdkRingDevice? _selectedDevice;

  bool get _hasSelectedDevice => _selectedDevice != null;
  bool get _isConnected => _connectionStatus == 'connected';

  @override
  void initState() {
    super.initState();
    _log = TestLogService()..add('app_open');
    _sdk = YcSdkTestService(_log);
    _eventSubscription = _sdk.events.listen((event) {
      setState(() {
        _lastSdkEvent = '${event.name}: ${event.value ?? event.raw}';
      });
    });
    _refreshPermissionStatuses();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _sdk.dispose();
    _log.dispose();
    super.dispose();
  }

  Future<void> _refreshPermissionStatuses() async {
    if (!Platform.isAndroid) {
      setState(() {
        _bluetoothPermissionStatus = 'Android phone required';
        _locationPermissionStatus = 'Android phone required';
      });
      return;
    }

    final scan = await Permission.bluetoothScan.status;
    final connect = await Permission.bluetoothConnect.status;
    final location = await Permission.locationWhenInUse.status;
    setState(() {
      _bluetoothPermissionStatus =
          'Scan: ${scan.name}, Connect: ${connect.name}';
      _locationPermissionStatus = location.name;
    });
  }

  Future<void> _requestPermissions() async {
    _log.add('permission_requested');
    try {
      final statuses = await <Permission>[
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();

      for (final entry in statuses.entries) {
        _log.add(
          entry.value.isGranted ? 'permission_granted' : 'permission_denied',
          '${entry.key}: ${entry.value.name}',
        );
      }
      await _refreshPermissionStatuses();
    } catch (error) {
      _setError(error);
    }
  }

  Future<void> _initializeSdk() async {
    await _guard(() async {
      await _sdk.initialize();
      setState(() {
        _isInitialized = true;
        _sdkStatus = 'Initialized';
      });
    });
  }

  Future<void> _scanDevices() async {
    if (!_isInitialized) {
      _setErrorText('Initialize SDK first.');
      return;
    }

    setState(() {
      _isScanning = true;
      _scanStatus = 'Scanning';
      _lastError = 'None';
    });

    try {
      final devices = await _sdk.scanDevices();
      setState(() {
        _devices = devices;
        _scanStatus = 'Finished';
      });
    } catch (error) {
      _setError(error);
      setState(() {
        _scanStatus = 'Failed';
      });
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  void _clearScanResults() {
    setState(() {
      _devices = <SdkRingDevice>[];
      _selectedDevice = null;
      _scanStatus = 'Cleared';
      _connectionStatus = 'idle';
    });
  }

  void _selectDevice(SdkRingDevice device) {
    setState(() {
      _selectedDevice = device;
    });
    _log.add('device_selected', device.toLogMap());
  }

  Future<void> _connectSelectedDevice() async {
    final device = _requireSelectedDevice();
    if (device == null) {
      return;
    }

    setState(() {
      _connectionStatus = 'connecting';
    });

    try {
      await _sdk.connect(device);
      setState(() {
        _connectionStatus = 'connected';
      });
    } catch (error) {
      _setError(error);
      setState(() {
        _connectionStatus = 'failed';
      });
    }
  }

  Future<void> _disconnect() async {
    await _guard(() async {
      await _sdk.disconnect();
      setState(() {
        _connectionStatus = 'disconnected';
      });
    });
  }

  Future<void> _runConnectedCommand(Future<void> Function() command) async {
    if (_requireSelectedDevice() == null) {
      return;
    }
    if (!_isConnected) {
      _setErrorText('Connect selected device first.');
      return;
    }
    await _guard(command);
  }

  Future<void> _exportLogs() async {
    await _guard(() async {
      final path = await _log.export();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logs exported: $path')),
        );
      }
    });
  }

  Future<void> _guard(Future<void> Function() run) async {
    if (_isBusy) {
      return;
    }
    setState(() {
      _isBusy = true;
      _lastError = 'None';
    });
    try {
      await run();
    } catch (error) {
      _setError(error);
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  SdkRingDevice? _requireSelectedDevice() {
    final device = _selectedDevice;
    if (device != null) {
      return device;
    }
    _setErrorText('Please scan and manually select a device first.');
    return null;
  }

  void _setError(Object error) {
    _setErrorText(error.toString());
  }

  void _setErrorText(String message) {
    setState(() {
      _lastError = message;
    });
    _log.add('error', message);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('YC SDK Smoke Test')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildStatusPanel(),
              const SizedBox(height: 12),
              _buildActions(),
              const SizedBox(height: 12),
              _buildSelectedDevicePanel(),
              const SizedBox(height: 12),
              _buildScanResults(),
              const SizedBox(height: 12),
              _buildLogPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPanel() {
    return _Panel(
      title: 'Status',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _statusRow(
            'Target device context',
            'TK30 9F37, but user manually selects actual scanned device.',
          ),
          _statusRow('SDK/plugin status', _sdkStatus),
          _statusRow('Bluetooth permission status', _bluetoothPermissionStatus),
          _statusRow(
            'Location permission status if required',
            _locationPermissionStatus,
          ),
          _statusRow('Scan status', _scanStatus),
          _statusRow('Number of SDK devices found', '${_devices.length}'),
          _statusRow('Selected device', _selectedDevice?.displayName ?? 'None'),
          _statusRow('Connection status', _connectionStatus),
          _statusRow('Last SDK event', _lastSdkEvent),
          _statusRow('Last error', _lastError),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final connectedAction = _isBusy || !_isConnected ? null : _runConnectedCommand;
    return _Panel(
      title: 'Actions',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          _button('Request Permissions', _isBusy ? null : _requestPermissions),
          _button('Initialize SDK', _isBusy ? null : _initializeSdk),
          _button(
            'Scan Devices',
            _isBusy || _isScanning ? null : _scanDevices,
          ),
          _button('Clear Scan Results', _isBusy ? null : _clearScanResults),
          _button(
            'Connect Selected Device',
            _isBusy || !_hasSelectedDevice ? null : _connectSelectedDevice,
          ),
          _button('Disconnect', _isBusy || !_isInitialized ? null : _disconnect),
          _button(
            'Query Basic Info',
            connectedAction == null
                ? null
                : () => connectedAction(_sdk.queryBasicInfo),
          ),
          _button(
            'Query Battery\nNot confirmed in SDK',
            null,
          ),
          _button(
            'Start HR',
            connectedAction == null
                ? null
                : () => connectedAction(_sdk.startHeartRateTest),
          ),
          _button(
            'Stop HR',
            connectedAction == null
                ? null
                : () => connectedAction(_sdk.stopHeartRateTest),
          ),
          _button(
            'Start SpO2',
            connectedAction == null
                ? null
                : () => connectedAction(_sdk.startBloodOxygenTest),
          ),
          _button(
            'Stop SpO2',
            connectedAction == null
                ? null
                : () => connectedAction(_sdk.stopBloodOxygenTest),
          ),
          _button(
            'Start BP',
            connectedAction == null
                ? null
                : () => connectedAction(_sdk.startBloodPressureTest),
          ),
          _button(
            'Stop BP',
            connectedAction == null
                ? null
                : () => connectedAction(_sdk.stopBloodPressureTest),
          ),
          _button(
            'Start Temperature',
            connectedAction == null
                ? null
                : () => connectedAction(_sdk.startTemperatureTest),
          ),
          _button(
            'Stop Temperature',
            connectedAction == null
                ? null
                : () => connectedAction(_sdk.stopTemperatureTest),
          ),
          _button(
            'Start ECG',
            connectedAction == null
                ? null
                : () => connectedAction(_sdk.startEcgTest),
          ),
          _button(
            'Stop ECG',
            connectedAction == null
                ? null
                : () => connectedAction(_sdk.stopEcgTest),
          ),
          _button('Export Test Logs', _isBusy ? null : _exportLogs),
        ],
      ),
    );
  }

  Widget _buildSelectedDevicePanel() {
    final device = _selectedDevice;
    return _Panel(
      title: 'Selected Device',
      child: device == null
          ? const Text('No device selected. Scan first, then tap Select.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _statusRow('Name', device.displayName),
                _statusRow('ID/UUID', device.displayId),
                _statusRow('Address/MAC', device.displayAddress),
                _statusRow('RSSI', device.displayRssi),
                _statusRow('Raw SDK object', device.rawText),
              ],
            ),
    );
  }

  Widget _buildScanResults() {
    return _Panel(
      title: 'SDK Scan Results',
      child: _devices.isEmpty
          ? const Text('No SDK devices found yet.')
          : Column(
              children: List<Widget>.generate(_devices.length, (index) {
                final device = _devices[index];
                final selected = identical(device, _selectedDevice);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                '#${index + 1} ${device.displayName}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (device.isPossibleRing)
                              const Chip(label: Text('Possible ring')),
                            const SizedBox(width: 8),
                            FilledButton.tonal(
                              onPressed: () => _selectDevice(device),
                              child: Text(selected ? 'Selected' : 'Select'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _statusRow('Device ID/address/MAC/UUID',
                            '${device.displayId} / ${device.displayAddress}'),
                        _statusRow('RSSI', device.displayRssi),
                        _statusRow('Raw SDK device object', device.rawText),
                        _statusRow('Metadata exposed by SDK', 'Raw object only'),
                      ],
                    ),
                  ),
                );
              }),
            ),
    );
  }

  Widget _buildLogPanel() {
    return _Panel(
      title: 'Timestamped Log',
      child: AnimatedBuilder(
        animation: _log,
        builder: (context, _) {
          return Container(
            height: 280,
            padding: const EdgeInsets.all(8),
            color: Colors.black87,
            child: SingleChildScrollView(
              child: SelectableText(
                _log.entries.isEmpty
                    ? 'No logs yet.'
                    : _log.entries.map((entry) => entry.toLine()).join('\n'),
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 190,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  Widget _button(String label, FutureOr<void> Function()? onPressed) {
    return FilledButton(
      onPressed: onPressed == null ? null : () => onPressed(),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
