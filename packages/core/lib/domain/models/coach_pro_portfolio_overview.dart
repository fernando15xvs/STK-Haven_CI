/// Global counters from the authorized server RPC, never a sum of roster pages.
class CoachProPortfolioOverview {
  final int totalClients;
  final int activeClients;
  final int pausedClients;
  final int clientsWithSharedProgress;
  final int clientsRequiringReview;
  final int visibleActiveTasks;
  final int clientsWithTaskBacklog;
  final int clientsWithRecentCheckins;

  const CoachProPortfolioOverview({
    required this.totalClients,
    required this.activeClients,
    required this.pausedClients,
    required this.clientsWithSharedProgress,
    required this.clientsRequiringReview,
    required this.visibleActiveTasks,
    required this.clientsWithTaskBacklog,
    required this.clientsWithRecentCheckins,
  });

  factory CoachProPortfolioOverview.fromJson(Map<String, dynamic> json) {
    int read(String key) {
      final value = json[key];
      if (value is! num || !value.isFinite || value < 0 || value != value.roundToDouble()) {
        throw const FormatException('Invalid Coach Pro portfolio response');
      }
      return value.toInt();
    }

    final result = CoachProPortfolioOverview(
      totalClients: read('total_clients'),
      activeClients: read('active_clients'),
      pausedClients: read('paused_clients'),
      clientsWithSharedProgress: read('clients_with_shared_progress'),
      clientsRequiringReview: read('clients_requiring_review'),
      visibleActiveTasks: read('visible_active_tasks'),
      clientsWithTaskBacklog: read('clients_with_task_backlog'),
      clientsWithRecentCheckins: read('clients_with_recent_checkins'),
    );
    if (result.activeClients + result.pausedClients != result.totalClients ||
        result.clientsWithSharedProgress > result.activeClients ||
        result.clientsRequiringReview > result.activeClients ||
        result.clientsWithTaskBacklog > result.activeClients ||
        result.clientsWithRecentCheckins > result.activeClients) {
      throw const FormatException('Inconsistent Coach Pro portfolio response');
    }
    return result;
  }
}
