class Schedule {
  final String id;
  final String userId;
  final String medicineId;
  final List<String> times;
  final List<int> daysOfWeek;
  final String startDate;
  final String? endDate;
  final bool active;

  Schedule({
    required this.id,
    required this.userId,
    required this.medicineId,
    required this.times,
    required this.daysOfWeek,
    required this.startDate,
    this.endDate,
    required this.active,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      id: json['id'],
      userId: json['user_id'],
      medicineId: json['medicine_id'],
      times: List<String>.from(json['times'] ?? []),
      daysOfWeek: List<int>.from(json['days_of_week'] ?? []),
      startDate: json['start_date'],
      endDate: json['end_date'],
      active: json['active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'medicine_id': medicineId,
      'times': times,
      'days_of_week': daysOfWeek,
      'start_date': startDate,
      'end_date': endDate,
      'active': active,
    };
  }
}
