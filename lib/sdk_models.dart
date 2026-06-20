class SdkRingDevice {
  const SdkRingDevice({
    required this.raw,
    this.name,
    this.id,
    this.address,
    this.rssi,
  });

  final String? name;
  final String? id;
  final String? address;
  final int? rssi;
  final Object raw;

  factory SdkRingDevice.fromSdkDevice(Object raw) {
    final dynamic device = raw;
    return SdkRingDevice(
      raw: raw,
      name: _readString(() => device.name),
      id: null,
      address: _readString(() => device.macAddress),
      rssi: _readInt(() => device.rssiValue),
    );
  }

  bool get isPossibleRing {
    final haystack = [
      name,
      id,
      address,
      raw.toString(),
    ].whereType<String>().join(' ').toLowerCase();

    return [
      'tk30',
      '9f37',
      'ring',
      'iring',
      'qring',
      'yc',
      'yucheng',
      'smart',
    ].any(haystack.contains);
  }

  String get displayName => _display(name);
  String get displayId => _display(id);
  String get displayAddress => _display(address);
  String get displayRssi => rssi?.toString() ?? 'Not exposed by SDK';
  String get rawText => raw.toString();

  Map<String, Object?> toLogMap() {
    return {
      'name': name,
      'id': id,
      'address': address,
      'rssi': rssi,
      'raw': raw.toString(),
    };
  }

  static String _display(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Not exposed by SDK';
    }
    return value;
  }
}

class SdkTestEvent {
  const SdkTestEvent({
    required this.name,
    required this.raw,
    this.value,
  });

  final String name;
  final String raw;
  final Object? value;
}

String? _readString(String? Function() read) {
  try {
    final value = read();
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value;
  } catch (_) {
    return null;
  }
}

int? _readInt(Object? Function() read) {
  try {
    final value = read();
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  } catch (_) {
    return null;
  }
}
