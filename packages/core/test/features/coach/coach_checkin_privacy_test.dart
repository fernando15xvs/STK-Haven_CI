import 'dart:async';
import 'package:core/domain/models/app_identity_state.dart';
import 'package:core/domain/models/coach_checkin.dart';
import 'package:core/features/coach/application/coach_checkin_provider.dart';
import 'package:core/features/coach/data/coach_checkin_service.dart';
import 'package:core/features/identity/application/app_identity_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
class _Identity extends AppIdentityNotifier {
  @override AppIdentityState build()=>const AppIdentityState(sessionKind:AppSessionKind.permanent,userId:'coach-a');
  void change(String? user)=>state=AppIdentityState(sessionKind:user==null?AppSessionKind.none:AppSessionKind.permanent,userId:user);
}
class _Service implements CoachCheckinService {
  final requests=<Completer<List<CoachCheckin>>>[];
  @override Never get client=>throw UnimplementedError();
  @override Future<String> create({required String relationshipId,required int energy,required int recovery,String note=''}) async=>'id';
  @override Future<List<CoachCheckin>> list(String clientUserId){final r=Completer<List<CoachCheckin>>();requests.add(r);return r.future;}
  @override Future<void> comment(String checkinId,String body)async{}
  @override Future<List<CoachCheckinComment>> comments(String checkinId)async=>[];
}
CoachCheckin item(String relationship)=>CoachCheckin(id:relationship,relationshipId:relationship,coachUserId:'coach-a',clientUserId:'client',energy:3,recovery:3,note:'private',createdAt:DateTime.utc(2026,11,26));
void main(){
  test('relationship scope, refresh denial and stale identity result',()async{
    final service=_Service();
    final container=ProviderContainer(overrides:[appIdentityProvider.overrideWith(_Identity.new),coachCheckinServiceProvider.overrideWithValue(service)]);
    addTearDown(container.dispose);
    container.listen(coachCheckinProvider,(_,_) {});
    final notifier=container.read(coachCheckinProvider.notifier);
    final first=notifier.load('client',relationshipId:'r1');
    service.requests.last.complete([item('r1'),item('r2')]);
    await first;
    expect(container.read(coachCheckinProvider).items.map((i)=>i.id),['r1']);
    final failed=notifier.load('client',relationshipId:'r1');
    expect(container.read(coachCheckinProvider).items,isEmpty);
    service.requests.last.completeError(StateError('denied'));
    await failed;
    expect(container.read(coachCheckinProvider).items,isEmpty);
    final pending=notifier.load('client',relationshipId:'r1');
    (container.read(appIdentityProvider.notifier) as _Identity).change('coach-b');
    container.read(coachCheckinProvider);
    service.requests.last.complete([item('r1')]);
    await pending;
    expect(container.read(coachCheckinProvider).items,isEmpty);
  });
}
