import 'dart:convert';
import 'dart:js_interop';

import 'package:supabase_flutter/supabase_flutter.dart';

@JS('stkWebPushSupport')
external JSPromise<JSString> _stkWebPushSupport();

@JS('stkWebPushSubscribe')
external JSPromise<JSString> _stkWebPushSubscribe(JSString vapidPublicKey);

@JS('stkWebPushUnsubscribe')
external JSPromise<JSString> _stkWebPushUnsubscribe();

@JS('stkEnableWebAudio')
external JSPromise<JSBoolean> _stkEnableWebAudio();

@JS('stkPlayAlarmTone')
external JSPromise<JSBoolean> _stkPlayAlarmTone();

@JS('stkShowForegroundNotification')
external JSPromise<JSBoolean> _stkShowForegroundNotification(
  JSString title,
  JSString body,
);

class WebPushSupport {
  final bool serviceWorker;
  final bool pushManager;
  final bool notifications;
  final bool subscribed;
  final bool standalone;
  final String permission;

  const WebPushSupport({
    required this.serviceWorker,
    required this.pushManager,
    required this.notifications,
    required this.subscribed,
    required this.standalone,
    required this.permission,
  });

  bool get supported => serviceWorker && pushManager && notifications;

  factory WebPushSupport.fromJson(Map<String, dynamic> json) {
    return WebPushSupport(
      serviceWorker: json['serviceWorker'] == true,
      pushManager: json['pushManager'] == true,
      notifications: json['notifications'] == true,
      subscribed: json['subscribed'] == true,
      standalone: json['standalone'] == true,
      permission: json['permission']?.toString() ?? 'unsupported',
    );
  }
}

class WebPlatformNotificationService {
  static const String vapidPublicKey =
      String.fromEnvironment('WEB_PUSH_VAPID_PUBLIC_KEY');

  final SupabaseClient client;

  const WebPlatformNotificationService(this.client);

  bool get isServerConfigurationPresent => vapidPublicKey.trim().isNotEmpty;

  Future<WebPushSupport> support() async {
    final raw = await _stkWebPushSupport().toDart;
    final decoded = jsonDecode(raw.toDart);
    return WebPushSupport.fromJson(
      decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : const <String, dynamic>{},
    );
  }

  Future<void> subscribe() async {
    final user = client.auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError(
        'Inicia sesión con una cuenta permanente antes de activar Web Push.',
      );
    }
    if (!isServerConfigurationPresent) {
      throw StateError(
        'WEB_PUSH_VAPID_PUBLIC_KEY no está configurada en este build.',
      );
    }

    final raw = await _stkWebPushSubscribe(vapidPublicKey.toJS).toDart;
    final decoded = jsonDecode(raw.toDart);
    if (decoded is! Map) {
      throw const FormatException('Suscripción Web Push no válida.');
    }

    final subscription = Map<String, dynamic>.from(decoded);
    final endpoint = subscription['endpoint']?.toString() ?? '';
    final rawKeys = subscription['keys'];
    final keys = rawKeys is Map
        ? Map<String, dynamic>.from(rawKeys)
        : const <String, dynamic>{};
    final p256dh = keys['p256dh']?.toString() ?? '';
    final auth = keys['auth']?.toString() ?? '';

    if (endpoint.isEmpty || p256dh.isEmpty || auth.isEmpty) {
      throw const FormatException('La suscripción no contiene claves válidas.');
    }

    await client.rpc(
      'stk_upsert_web_push_subscription',
      params: <String, dynamic>{
        'p_endpoint': endpoint,
        'p_p256dh': p256dh,
        'p_auth': auth,
        'p_user_agent': 'STK Haven Web/PWA',
      },
    );
  }

  Future<void> unsubscribe() async {
    final endpointJs = await _stkWebPushUnsubscribe().toDart;
    final endpoint = endpointJs.toDart.trim();
    final user = client.auth.currentUser;
    if (endpoint.isEmpty || user == null || user.isAnonymous) return;

    await client.rpc(
      'stk_disable_web_push_subscription',
      params: <String, dynamic>{'p_endpoint': endpoint},
    );
  }

  Future<bool> backendSubscriptionActive() async {
    final user = client.auth.currentUser;
    if (user == null || user.isAnonymous) return false;
    try {
      return await client.rpc('stk_has_web_push_subscription') == true;
    } catch (_) {
      return false;
    }
  }

  Future<int> sendTestPush() async {
    final response = await client.functions.invoke('web-push-test');
    final data = response.data;
    if (data is Map) {
      return (data['sent'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  static Future<bool> enableAudio() async {
    return (await _stkEnableWebAudio().toDart).toDart;
  }

  static Future<bool> playAlarmTone() async {
    return (await _stkPlayAlarmTone().toDart).toDart;
  }

  static Future<bool> showForegroundNotification({
    required String title,
    required String body,
  }) async {
    return (await _stkShowForegroundNotification(
      title.toJS,
      body.toJS,
    ).toDart)
        .toDart;
  }
}
