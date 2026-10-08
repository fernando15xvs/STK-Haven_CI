enum CoachProCheckinCadenceStatus {
  proposed,
  accepted,
  declined,
}

class CoachProCheckinCadence {
  final String relationshipId;
  final Set<int> weekdays;
  final CoachProCheckinCadenceStatus status;
  final int revision;
  final DateTime proposedAt;
  final DateTime? respondedAt;

  const CoachProCheckinCadence({
    required this.relationshipId,
    required this.weekdays,
    required this.status,
    required this.revision,
    required this.proposedAt,
    required this.respondedAt,
  });

  factory CoachProCheckinCadence.fromJson(
    Map<String, dynamic> json, {
    required String expectedRelationshipId,
  }) {
    final relation = json['relationship_id'];
    final rawDays = json['weekdays'];
    final rawRevision = json['revision'];
    final rawStatus = json['status'];
    final rawProposed = json['proposed_at'];
    final rawResponded = json['responded_at'];
    final status = CoachProCheckinCadenceStatus.values.where(
      (s) => s.name == rawStatus,
    );
    if (relation is! String || relation != expectedRelationshipId ||
        rawDays is! List || rawDays.length < 1 || rawDays.length > 3 ||
        rawDays.any((d) => d is! int || d < 1 || d > 7) ||
        rawDays.toSet().length != rawDays.length ||
        rawRevision is! int || rawRevision < 1 || rawRevision > 10000 ||
        status.length != 1 ||
        rawProposed is! String || DateTime.tryParse(rawProposed) == null ||
        (rawResponded != null &&
            (rawResponded is! String || DateTime.tryParse(rawResponded) == null))) {
      throw const FormatException('Invalid check-in cadence');
    }
    return CoachProCheckinCadence(
      relationshipId: relation,
      weekdays: Set.unmodifiable(rawDays.cast<int>()),
      status: status.single,
      revision: rawRevision,
      proposedAt: DateTime.parse(rawProposed),
      respondedAt: rawResponded == null ? null : DateTime.parse(rawResponded),
    );
  }
}
