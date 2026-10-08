import 'package:core/domain/models/coach_pro_portfolio_overview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('global overview parses independently of page size', () {
    final value = CoachProPortfolioOverview.fromJson({
      'total_clients': 91,
      'active_clients': 80,
      'paused_clients': 11,
      'clients_with_shared_progress': 40,
      'clients_requiring_review': 12,
      'visible_active_tasks': 127,
      'clients_with_task_backlog': 31,
      'clients_with_recent_checkins': 25,
    });
    expect(value.totalClients, 91);
    expect(value.visibleActiveTasks, 127);
    expect(value.clientsRequiringReview, 12);
  });

  test('missing, invalid or inconsistent aggregate fails closed', () {
    const valid = {
      'total_clients': 2,
      'active_clients': 1,
      'paused_clients': 1,
      'clients_with_shared_progress': 1,
      'clients_requiring_review': 0,
      'visible_active_tasks': 0,
      'clients_with_task_backlog': 0,
      'clients_with_recent_checkins': 0,
    };
    expect(() => CoachProPortfolioOverview.fromJson({...valid}..remove('paused_clients')),
        throwsFormatException);
    expect(() => CoachProPortfolioOverview.fromJson({...valid, 'visible_active_tasks': -1}),
        throwsFormatException);
    expect(() => CoachProPortfolioOverview.fromJson({...valid, 'active_clients': 2}),
        throwsFormatException);
    expect(() => CoachProPortfolioOverview.fromJson({
      ...valid, 'clients_with_recent_checkins': 2,
    }), throwsFormatException);
  });
}
