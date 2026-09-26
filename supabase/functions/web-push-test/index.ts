import { withSupabase } from 'npm:@supabase/server@1.4.1';
import webpush from 'npm:web-push@3.6.7';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return Response.json(body, {
    status,
    headers: {
      ...corsHeaders,
      'Cache-Control': 'no-store',
    },
  });
}

type PushSubscriptionRow = {
  id: string;
  endpoint: string;
  p256dh: string;
  auth_key: string;
};

const authenticatedHandler = withSupabase(
  { auth: 'user' },
  async (req, ctx) => {
    if (req.method !== 'POST') {
      return jsonResponse({ error: 'Método no permitido.' }, 405);
    }

    const userId = ctx.userClaims?.id;
    if (!userId) {
      return jsonResponse({ error: 'Sesión inválida.' }, 401);
    }

    const subject = Deno.env.get('WEB_PUSH_VAPID_SUBJECT')?.trim();
    const publicKey = Deno.env.get('WEB_PUSH_VAPID_PUBLIC_KEY')?.trim();
    const privateKey = Deno.env.get('WEB_PUSH_VAPID_PRIVATE_KEY')?.trim();

    if (!subject || !publicKey || !privateKey) {
      console.error('web-push-test: VAPID secrets are not configured');
      return jsonResponse(
        { error: 'Web Push aún no está configurado en el servidor.' },
        503,
      );
    }

    webpush.setVapidDetails(subject, publicKey, privateKey);

    const admin = ctx.supabaseAdmin as any;
    const { data, error } = await admin
      .from('stk_web_push_subscriptions')
      .select('id,endpoint,p256dh,auth_key')
      .eq('user_id', userId)
      .is('disabled_at', null);

    if (error) {
      console.error('web-push-test: subscription query failed');
      return jsonResponse(
        { error: 'No se pudieron consultar las suscripciones.' },
        503,
      );
    }

    const subscriptions = (data ?? []) as PushSubscriptionRow[];
    if (subscriptions.length === 0) {
      return jsonResponse(
        { error: 'Este usuario no tiene una suscripción Web Push activa.' },
        409,
      );
    }

    const payload = JSON.stringify({
      title: 'STK Haven',
      body: 'Las notificaciones Web Push están funcionando.',
      url: './',
      tag: 'stk-haven-test',
    });

    let sent = 0;
    let disabled = 0;

    for (const row of subscriptions) {
      try {
        await webpush.sendNotification(
          {
            endpoint: row.endpoint,
            keys: {
              p256dh: row.p256dh,
              auth: row.auth_key,
            },
          },
          payload,
          {
            TTL: 120,
            urgency: 'normal',
          },
        );
        sent++;
      } catch (error) {
        const statusCode =
          typeof error === 'object' && error !== null &&
              'statusCode' in error
            ? Number((error as { statusCode?: unknown }).statusCode)
            : 0;

        if (statusCode === 404 || statusCode === 410) {
          await admin
            .from('stk_web_push_subscriptions')
            .update({
              disabled_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
            })
            .eq('id', row.id);
          disabled++;
          continue;
        }

        console.warn(
          `web-push-test: delivery failed with status ${statusCode || 'unknown'}`,
        );
      }
    }

    return jsonResponse({
      sent,
      disabled,
      total: subscriptions.length,
    });
  },
);

export default {
  fetch(req: Request) {
    if (req.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders });
    }
    return authenticatedHandler(req);
  },
};
