class BodyMeasurement {
  final String id;
  final DateTime date;
  
  /// Canonical weight in kg. Nullable.
  final double? weightKg;
  
  /// Body fat percentage (0-100). Nullable.
  final double? bodyFatPercentage;

  /// Height in centimeters, optional for existing measurements.
  final double? heightCm;
  
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
  // Optional per-region fields; calvesCm retains legacy general meaning.
  final double? neckCm;
  final double? leftForearmCm;
  final double? rightForearmCm;
  final double? leftCalfCm;
  final double? rightCalfCm;

  const BodyMeasurement({
    required this.id,
    required this.date,
    this.weightKg,
    this.bodyFatPercentage,
    this.heightCm,
    this.shouldersCm,
    this.chestCm,
    this.waistCm,
    this.hipsCm,
    this.leftArmCm,
    this.rightArmCm,
    this.leftLegCm,
    this.rightLegCm,
    this.calvesCm,
    this.neckCm,
    this.leftForearmCm,
    this.rightForearmCm,
    this.leftCalfCm,
    this.rightCalfCm,
  });

  BodyMeasurement copyWith({
    String? id,
    DateTime? date,
    double? weightKg,
    double? bodyFatPercentage,
    double? heightCm,
    double? shouldersCm,
    double? chestCm,
    double? waistCm,
    double? hipsCm,
    double? leftArmCm,
    double? rightArmCm,
    double? leftLegCm,
    double? rightLegCm,
    double? calvesCm,
    double? neckCm,
    double? leftForearmCm,
    double? rightForearmCm,
    double? leftCalfCm,
    double? rightCalfCm,
  }) {
    return BodyMeasurement(
      id: id ?? this.id,
      date: date ?? this.date,
      weightKg: weightKg ?? this.weightKg,
      bodyFatPercentage: bodyFatPercentage ?? this.bodyFatPercentage,
      heightCm: heightCm ?? this.heightCm,
      shouldersCm: shouldersCm ?? this.shouldersCm,
      chestCm: chestCm ?? this.chestCm,
      waistCm: waistCm ?? this.waistCm,
      hipsCm: hipsCm ?? this.hipsCm,
      leftArmCm: leftArmCm ?? this.leftArmCm,
      rightArmCm: rightArmCm ?? this.rightArmCm,
      leftLegCm: leftLegCm ?? this.leftLegCm,
      rightLegCm: rightLegCm ?? this.rightLegCm,
      calvesCm: calvesCm ?? this.calvesCm,
      neckCm: neckCm ?? this.neckCm,
      leftForearmCm: leftForearmCm ?? this.leftForearmCm,
      rightForearmCm: rightForearmCm ?? this.rightForearmCm,
      leftCalfCm: leftCalfCm ?? this.leftCalfCm,
      rightCalfCm: rightCalfCm ?? this.rightCalfCm,
    );
  }
}

