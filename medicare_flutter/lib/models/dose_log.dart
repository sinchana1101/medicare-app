class DoseLog {
  final String id;
  final String userId;
  final String? scheduleId;
  final String? medicineId;
  final String scheduledFor;
  final String status;
  final String? takenAt;
  final String createdAt;

  DoseLog({
    required this.id,
    required this.userId,
    this.scheduleId,
    this.medicineId,
    required this.scheduledFor,
    required this.status,
    this.takenAt,
    required this.createdAt,
  });

  factory DoseLog.fromJson(Map<String, dynamic> json) {
    return DoseLog(
      id: json['id'],
      userId: json['user_id'],
      scheduleId: json['schedule_id'],
      medicineId: json['medicine_id'],
      scheduledFor: json['scheduled_for'],
      status: json['status'] ?? 'taken',
      takenAt: json['taken_at'],
      createdAt: json['created_at'],
    );
  }
}
