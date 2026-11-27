/// Platform adapter for the optional end-of-focus notification. Core owns
/// the deadline, while the mobile platform owns permissions and delivery.
abstract interface class FocusTimerNotificationBackend {
  Future<bool> requestPermission();
  Future<void> schedule(DateTime deadline);
  Future<void> cancel();
}
abstract final class FocusTimerNotificationService {
  static FocusTimerNotificationBackend? _backend;
  static void installBackend(FocusTimerNotificationBackend? backend)=>_backend=backend;
  static Future<bool> requestPermission()async{
    try{return await _backend?.requestPermission()??false;}catch(_){return false;}
  }
  static Future<void> schedule(DateTime deadline)async{
    try{await _backend?.schedule(deadline);}catch(_){/* timer remains usable without notifications */}
  }
  static Future<void> cancel()async{
    try{await _backend?.cancel();}catch(_){/* no timer mutation depends on native notifications */}
  }
}
