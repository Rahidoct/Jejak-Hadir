class LocalUser {
  final String uid;
  final String email;
  final String name;
  final String? nip;
  final String? position;
  final String? grade;
  final DateTime registrationDate; // [BARU] Tambahkan tanggal pendaftaran

  LocalUser({
    required this.uid,
    required this.email,
    required this.name,
    this.nip,
    this.position,
    this.grade,
    required this.registrationDate, // [BARU] Jadikan required
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'nip': nip,
      'position': position,
      'grade': grade,
      'registrationDate': registrationDate.toIso8601String(), // [BARU] Simpan sebagai string
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
      // [BARU] Ambil dari map, jika tidak ada, gunakan waktu sekarang sebagai fallback untuk data lama
      registrationDate: map['registrationDate'] != null
          ? DateTime.parse(map['registrationDate'] as String)
          : DateTime.now(),
    );
  }

  static LocalUser fromJson(Map<String, dynamic> json) {
    return LocalUser.fromMap(json);
  }
}