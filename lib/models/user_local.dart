// lib/models/user_local.dart

class LocalUser {
  final String uid;
  final String email;
  final String name;
  final String? nip;
  final String? position;
  final String? grade;
  final DateTime registrationDate;
  final String? faceData;
  final String? profilePicture;

  LocalUser({
    required this.uid,
    required this.email,
    required this.name,
    this.nip,
    this.position,
    this.grade,
    required this.registrationDate,
    this.faceData,
    this.profilePicture,
  });

  LocalUser copyWith({
    String? uid,
    String? email,
    String? name,
    String? nip,
    String? position,
    String? grade,
    DateTime? registrationDate,
    String? faceData,
    String? profilePicture,
  }) {
    return LocalUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      nip: nip ?? this.nip,
      position: position ?? this.position,
      grade: grade ?? this.grade,
      registrationDate: registrationDate ?? this.registrationDate,
      faceData: faceData, // Jangan hapus '?? this.faceData'
      profilePicture: profilePicture ?? this.profilePicture,
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
      'faceData': faceData,
      'profilePicture': profilePicture,
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
      faceData: map['faceData'] as String?,
      profilePicture: map['profilePicture'] as String?,
    );
  }
}