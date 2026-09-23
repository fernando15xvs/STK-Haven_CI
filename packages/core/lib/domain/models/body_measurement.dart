class BodyMeasurement {
  final String id;
  final DateTime date;
  
  /// Canonical weight in kg. Nullable.
  final double? weightKg;
  
  /// Body fat percentage (0-100). Nullable.
  final double? bodyFatPercentage;
  
  /// Canonical measurements in cm. Nullable.
  final double? shouldersCm;
  final double? chestCm;
  final double? waistCm;
  final double? hipsCm;
  final double? leftArmCm;
  final double? rightArmCm;
  final double? leftLegCm;
  final double? rightLegCm;
  final double? calvesCm;

  const BodyMeasurement({
    required this.id,
    required this.date,
    this.weightKg,
    this.bodyFatPercentage,
    this.shouldersCm,
    this.chestCm,
    this.waistCm,
    this.hipsCm,
    this.leftArmCm,
    this.rightArmCm,
    this.leftLegCm,
    this.rightLegCm,
    this.calvesCm,
  });

  BodyMeasurement copyWith({
    String? id,
    DateTime? date,
    double? weightKg,
    double? bodyFatPercentage,
    double? shouldersCm,
    double? chestCm,
    double? waistCm,
    double? hipsCm,
    double? leftArmCm,
    double? rightArmCm,
    double? leftLegCm,
    double? rightLegCm,
    double? calvesCm,
  }) {
    return BodyMeasurement(
      id: id ?? this.id,
      date: date ?? this.date,
      weightKg: weightKg ?? this.weightKg,
      bodyFatPercentage: bodyFatPercentage ?? this.bodyFatPercentage,
      shouldersCm: shouldersCm ?? this.shouldersCm,
      chestCm: chestCm ?? this.chestCm,
      waistCm: waistCm ?? this.waistCm,
      hipsCm: hipsCm ?? this.hipsCm,
      leftArmCm: leftArmCm ?? this.leftArmCm,
      rightArmCm: rightArmCm ?? this.rightArmCm,
      leftLegCm: leftLegCm ?? this.leftLegCm,
      rightLegCm: rightLegCm ?? this.rightLegCm,
      calvesCm: calvesCm ?? this.calvesCm,
    );
  }
}

