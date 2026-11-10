class ConnectedDevice {
  const ConnectedDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.isConnected,
    required this.lastConnectedAt,
  });

  final String id;
  final String name;
  final String type;
  final bool isConnected;
  final DateTime? lastConnectedAt;

  ConnectedDevice copyWith({
    String? name,
    bool? isConnected,
    DateTime? lastConnectedAt,
  }) => ConnectedDevice(
    id: id,
    name: name ?? this.name,
    type: type,
    isConnected: isConnected ?? this.isConnected,
    lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'isConnected': isConnected,
    'lastConnectedAt': lastConnectedAt?.toIso8601String(),
  };

  factory ConnectedDevice.fromJson(Map<String, dynamic> json) =>
      ConnectedDevice(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        isConnected: json['isConnected'] as bool? ?? false,
        lastConnectedAt: json['lastConnectedAt'] != null
            ? DateTime.parse(json['lastConnectedAt'] as String)
            : null,
      );
}

class DeviceSettings {
  const DeviceSettings({required this.devices});

  final List<ConnectedDevice> devices;

  DeviceSettings copyWith({List<ConnectedDevice>? devices}) =>
      DeviceSettings(devices: devices ?? this.devices);

  factory DeviceSettings.defaults() => const DeviceSettings(devices: []);
}
