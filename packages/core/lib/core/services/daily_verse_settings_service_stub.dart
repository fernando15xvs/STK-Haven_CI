/// Web does not schedule native background notifications.
///
/// Keeping this implementation dependency-free prevents native plugins from
/// entering the web build.
Future<bool> configureDailyVerseNotifications(bool enable) async => false;
