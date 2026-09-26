class FaithFeaturePolicy {
  const FaithFeaturePolicy._();

  static bool shouldLoadBible({required bool faithEnabled}) => faithEnabled;

  static bool shouldShowDailyVerse({
    required bool faithEnabled,
    required bool showDailyVerse,
  }) =>
      faithEnabled && showDailyVerse;

  static bool shouldScheduleDailyVerseNotification({
    required bool faithEnabled,
    required bool notificationEnabled,
  }) =>
      faithEnabled && notificationEnabled;
}
