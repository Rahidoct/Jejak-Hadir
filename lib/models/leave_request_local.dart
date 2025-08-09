// lib/models/leave_request_local.dart

class LeaveRequest {
  final String id;
  final String userId;
  final String requestType; 
  final String? leaveCategory;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String status;
  final DateTime submittedDate;
  final String? attachmentPath;

  LeaveRequest({
    required this.id,
    required this.userId,
    required this.requestType,
    this.leaveCategory,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    required this.submittedDate,
    this.attachmentPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'requestType': requestType, // [GANTI]
      'leaveCategory': leaveCategory, // [BARU]
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'reason': reason,
      'status': status,
      'submittedDate': submittedDate.toIso8601String(),
      'attachmentPath': attachmentPath,
    };
  }

  factory LeaveRequest.fromMap(Map<String, dynamic> map) {
    return LeaveRequest(
      id: map['id'] as String,
      userId: map['userId'] as String,
      // [GANTI] Fallback untuk data lama yang mungkin belum punya 'requestType'
      requestType: map['requestType'] as String? ?? 'Izin', 
      leaveCategory: map['leaveCategory'] as String?, // [BARU]
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: DateTime.parse(map['endDate'] as String),
      reason: map['reason'] as String,
      status: map['status'] as String,
      submittedDate: DateTime.parse(map['submittedDate'] as String),
      attachmentPath: map['attachmentPath'] as String?,
    );
  }
}