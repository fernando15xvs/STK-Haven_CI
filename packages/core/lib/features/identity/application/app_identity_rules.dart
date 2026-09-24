import 'package:core/domain/models/app_identity_state.dart';
import 'package:core/domain/models/user_experience_profile.dart';

class AppIdentityRules {
  const AppIdentityRules._();

  static AppSessionKind classifySession({
    required bool hasUser,
    required String? email,
  }) {
    if (!hasUser) return AppSessionKind.none;
    if (email?.trim().isNotEmpty == true) {
      return AppSessionKind.permanent;
    }
    return AppSessionKind.anonymous;
  }

  static Set<UserCapability> sanitizeCapabilities(
    Iterable<UserCapability> capabilities,
  ) {
    final values = capabilities.toSet();
    if (values.isEmpty) {
      values.add(UserCapability.athlete);
    }
    return values;
  }

  static List<String> capabilityNames(
    Iterable<UserCapability> capabilities,
  ) {
    final safe = sanitizeCapabilities(capabilities);
    final names = safe.map((value) => value.name).toList()..sort();
    return names;
  }

  static Set<UserCapability> parseCapabilityRows(
    Iterable<dynamic> rows,
  ) {
    final parsed = <UserCapability>{};
    for (final raw in rows) {
      if (raw is! Map) continue;
      final name = raw['capability']?.toString();
      for (final capability in UserCapability.values) {
        if (capability.name == name) {
          parsed.add(capability);
          break;
        }
      }
    }
    return sanitizeCapabilities(parsed);
  }
}
