// lib/models/user_local.dart

class LocalUser {
  final String uid;
  final String email;
  final String name;
  final String? nip;
  final String? position;
  final String? grade;
  final DateTime registrationDate;
  final String? faceData; // CHANGED: From bool to String? for image data

  LocalUser({
    required this.uid,
    required this.email,
    required this.name,
    this.nip,
    this.position,
    this.grade,
    required this.registrationDate,
    this.faceData, // CHANGED
  });

  // NEW: copyWith method for easier updates
  LocalUser copyWith({
    String? uid,
    String? email,
    String? name,
    String? nip,
    String? position,
    String? grade,
    DateTime? registrationDate,
    // Use Object to handle null explicitly
    Object? faceData = const Object(), 
  }) {
    return LocalUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      nip: nip ?? this.nip,
      position: position ?? this.position,
      grade: grade ?? this.grade,
      registrationDate: registrationDate ?? this.registrationDate,
      // If faceData is the default Object, keep the old value.
      // Otherwise, use the new value (which can be a String or null).
      faceData: faceData == const Object() ? this.faceData : faceData as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'nip': nip,
      'position': position,
      'grade': grade,
      'registrationDate': registrationDate.toIso8601String(),
      'faceData': faceData, // CHANGED
    };
  }

  factory LocalUser.fromMap(Map<String, dynamic> map) {
    return LocalUser(
      uid: map['uid'] as String,
      email: map['email'] as String,
      name: map['name'] as String,
      nip: map['nip'] as String?,
      position: map['position'] as String?,
      grade: map['grade'] as String?,
      registrationDate: map['registrationDate'] != null
          ? DateTime.parse(map['registrationDate'] as String)
          : DateTime.now(),
      faceData: map['faceData'] as String?, // CHANGED
    );
  }
}