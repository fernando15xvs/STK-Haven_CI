import 'package:core/domain/models/user_experience_profile.dart';

enum AppSessionKind {
  none,
  anonymous,
  permanent,
}

enum AppIdentityOperation {
  idle,
  signingIn,
  signingUp,
  signingOut,
  syncingProfile,
  refreshingProfile,
}

class AppIdentityState {
  final AppSessionKind sessionKind;
  final String? userId;
  final String? email;
  final AppIdentityOperation operation;
  final String? message;
  final bool isError;
  final bool remoteProfileAvailable;
  final String? displayName;
  final Set<UserCapability> remoteCapabilities;

  const AppIdentityState({
    this.sessionKind = AppSessionKind.none,
    this.userId,
    this.email,
    this.operation = AppIdentityOperation.idle,
    this.message,
    this.isError = false,
    this.remoteProfileAvailable = false,
    this.displayName,
    this.remoteCapabilities = const <UserCapability>{},
  });

  bool get signedIn => sessionKind == AppSessionKind.permanent;

  bool get hasAnonymousSession => sessionKind == AppSessionKind.anonymous;

  bool get busy => operation != AppIdentityOperation.idle;

  bool get isCoach => remoteCapabilities.contains(UserCapability.coach);

  AppIdentityState copyWith({
    AppSessionKind? sessionKind,
    String? userId,
    bool clearUserId = false,
    String? email,
    bool clearEmail = false,
    AppIdentityOperation? operation,
    String? message,
    bool clearMessage = false,
    bool? isError,
    bool? remoteProfileAvailable,
    String? displayName,
    bool clearDisplayName = false,
    Set<UserCapability>? remoteCapabilities,
  }) {
    return AppIdentityState(
      sessionKind: sessionKind ?? this.sessionKind,
      userId: clearUserId ? null : (userId ?? this.userId),
      email: clearEmail ? null : (email ?? this.email),
      operation: operation ?? this.operation,
      message: clearMessage ? null : (message ?? this.message),
      isError: isError ?? this.isError,
      remoteProfileAvailable:
          remoteProfileAvailable ?? this.remoteProfileAvailable,
      displayName:
          clearDisplayName ? null : (displayName ?? this.displayName),
      remoteCapabilities:
          remoteCapabilities ?? this.remoteCapabilities,
    );
  }
}
