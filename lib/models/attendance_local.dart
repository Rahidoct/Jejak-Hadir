class LocalAttendance {
  final String id;
  final String userId;
  final String type;
  final DateTime timestamp;
  final double latitude;
  final double longitude;

  LocalAttendance({
    required this.id,
    required this.userId,
    required this.type,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory LocalAttendance.fromMap(Map<String, dynamic> map) {
    return LocalAttendance(
      id: map['id'] as String,
      userId: map['userId'] as String,
      type: map['type'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
    );
  }
}