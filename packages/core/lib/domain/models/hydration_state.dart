class HydrationState {
  final String dateString;
  final int waterMl;

  const HydrationState({
    required this.dateString,
    this.waterMl = 0,
  });

  HydrationState copyWith({
    String? dateString,
    int? waterMl,
  }) {
    return HydrationState(
      dateString: dateString ?? this.dateString,
      waterMl: waterMl ?? this.waterMl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dateString': dateString,
      'waterMl': waterMl,
    };
  }

  factory HydrationState.fromJson(Map<String, dynamic> json) {
    return HydrationState(
      dateString: json['dateString'] as String,
      waterMl: json['waterMl'] as int? ?? 0,
    );
  }
}
