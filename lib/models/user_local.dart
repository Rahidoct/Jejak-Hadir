class LocalUser {
  final String uid;
  final String email;
  final String name;
  final String? nip;
  final String? position;
  final String? grade;

  LocalUser({
    required this.uid,
    required this.email,
    required this.name,
    this.nip,
    this.position,
    this.grade,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'nip': nip,
      'position': position,
      'grade': grade,
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
    );
  }
}