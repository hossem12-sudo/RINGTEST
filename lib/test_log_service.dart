import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class TestLogEntry {
  const TestLogEntry({
    required this.timestamp,
    required this.event,
    this.details,
  });

  final DateTime timestamp;
  final String event;
  final Object? details;

  String toLine() {
    final value = details == null ? '' : ' | $details';
    return '${timestamp.toIso8601String()} | $event$value';
  }
}

class TestLogService extends ChangeNotifier {
  final List<TestLogEntry> _entries = <TestLogEntry>[];

  List<TestLogEntry> get entries => List.unmodifiable(_entries);

  void add(String event, [Object? details]) {
    final entry = TestLogEntry(
      timestamp: DateTime.now(),
      event: event,
      details: details,
    );
    _entries.add(entry);
    debugPrint(entry.toLine(), wrapWidth: 1024);
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  String asText() {
    return _entries.map((entry) => entry.toLine()).join('\n');
  }

  Future<String> export() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}/yc_sdk_smoke_test_${DateTime.now().millisecondsSinceEpoch}.log',
    );
    await file.writeAsString(asText());
    add('command_success', {'exported_log_path': file.path});
    return file.path;
  }
}
