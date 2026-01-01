class SetLog {
  final bool isBodyweight;
  final double? weight; // null when bodyweight
  final int fullReps;
  final int partialReps;

  const SetLog({
    required this.isBodyweight,
    required this.weight,
    required this.fullReps,
    required this.partialReps,
  });

  Map<String, dynamic> toJson() => {
        'isBodyweight': isBodyweight,
        'weight': weight,
        'fullReps': fullReps,
        'partialReps': partialReps,
      };

  factory SetLog.fromJson(Map<String, dynamic> json) {
    return SetLog(
      isBodyweight: (json['isBodyweight'] as bool?) ?? false,
      weight: (json['weight'] as num?)?.toDouble(),
      fullReps: (json['fullReps'] as num?)?.toInt() ?? 0,
      partialReps: (json['partialReps'] as num?)?.toInt() ?? 0,
    );
  }
}