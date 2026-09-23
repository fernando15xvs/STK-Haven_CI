import { withSupabase } from 'npm:@supabase/server@1.4.1';

const MAX_MESSAGE_LENGTH = 1000;
const MAX_HISTORY_ITEMS = 8;
const MAX_HISTORY_TEXT_LENGTH = 1500;
const GEMINI_TIMEOUT_MS = 25_000;
const DEFAULT_MODEL = 'gemini-3.7-flash';

const systemInstruction = [
  'Eres "Haven Faith", un asesor de bienestar integral, espiritual y físico.',
  'SOLO debes responder preguntas relacionadas con la fe, la Biblia, estilo de vida saludable, entrenamientos y fitness.',
  'Si te preguntan sobre otros temas como programación, política, matemáticas, recetas u otros asuntos fuera de tu propósito, niégate amablemente y recuerda tu propósito.',
  'Tus respuestas deben ser breves, directas y sin rodeos, con un máximo de 2 o 3 párrafos cortos.',
  'No inventes versículos, referencias bíblicas, estudios ni datos. Si no estás seguro, dilo claramente.',
  'No sustituyas a profesionales sanitarios ni hagas diagnósticos médicos. Ante síntomas graves o una emergencia, recomienda buscar atención profesional inmediata.',
].join(' ');

type GeminiRole = 'user' | 'model';

type GeminiContent = {
  role: GeminiRole;
  parts: Array<{ text: string }>;
};

type QuotaResult = {
  allowed?: boolean;
  reason?: string;
  retry_after_seconds?: number;
};

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return Response.json(body, {
    status,
    headers: {
      'Cache-Control': 'no-store',
    },
  });
}

function normalizeHistory(value: unknown): GeminiContent[] {
  if (!Array.isArray(value)) return [];

  const result: GeminiContent[] = [];
  const entries = value.slice(-MAX_HISTORY_ITEMS);

  for (const entry of entries) {
    if (typeof entry !== 'object' || entry === null) continue;

    const raw = entry as Record<string, unknown>;
    const text = typeof raw.text === 'string'
      ? raw.text.trim().slice(0, MAX_HISTORY_TEXT_LENGTH)
      : '';
    if (!text) continue;

    const role: GeminiRole | null = raw.role === 'user'
      ? 'user'
      : raw.role === 'assistant' || raw.role === 'model'
      ? 'model'
      : null;
    if (role === null) continue;

    // Gemini chat history should start with a user turn. The local welcome
    // message is presentation-only and is intentionally not sent upstream.
    if (result.length === 0 && role === 'model') continue;

    const previous = result[result.length - 1];
    if (previous?.role === role) {
      previous.parts[0].text = `${previous.parts[0].text}\n${text}`.slice(
        0,
        MAX_HISTORY_TEXT_LENGTH,
      );
      continue;
    }

    result.push({ role, parts: [{ text }] });
  }

  return result;
}

export default {
  fetch: withSupabase({ auth: 'user' }, async (req, ctx) => {
    if (req.method !== 'POST') {
      return jsonResponse({ error: 'Método no permitido.' }, 405);
    }

    let payload: Record<string, unknown>;
    try {
      const parsed = await req.json();
      if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
        return jsonResponse({ error: 'Solicitud inválida.' }, 400);
      }
      payload = parsed as Record<string, unknown>;
    } catch {
      return jsonResponse({ error: 'Solicitud inválida.' }, 400);
    }

    const message = typeof payload.message === 'string'
      ? payload.message.trim()
      : '';
    if (!message || message.length > MAX_MESSAGE_LENGTH) {
      return jsonResponse({ error: 'El mensaje no es válido.' }, 400);
    }

    const apiKey = Deno.env.get('GEMINI_API_KEY')?.trim();
    if (!apiKey) {
      console.error('haven-faith-ai: GEMINI_API_KEY is not configured');
      return jsonResponse(
        { error: 'Haven Faith no está disponible en este momento.' },
        503,
      );
    }

    const userId = ctx.userClaims?.id;
    if (!userId) {
      return jsonResponse({ error: 'Sesión inválida.' }, 401);
    }

    const { data: quotaData, error: quotaError } = await ctx.supabaseAdmin.rpc(
      'consume_haven_faith_quota',
      { p_user_id: userId },
    );

    if (quotaError) {
      console.error('haven-faith-ai: quota check failed');
      return jsonResponse(
        { error: 'Haven Faith no está disponible en este momento.' },
        503,
      );
    }

    const quota = (quotaData ?? {}) as QuotaResult;
    if (quota.allowed !== true) {
      const body: Record<string, unknown> = {
        error: quota.reason === 'day_limit'
          ? 'Alcanzaste el límite diario de Haven Faith.'
          : 'Haven Faith está recibiendo muchas solicitudes. Inténtalo en un momento.',
      };
      if (typeof quota.retry_after_seconds === 'number') {
        body.retryAfterSeconds = quota.retry_after_seconds;
      }
      return jsonResponse(body, 429);
    }

    const model = Deno.env.get('GEMINI_MODEL')?.trim() || DEFAULT_MODEL;
    const contents = normalizeHistory(payload.history);
    const last = contents[contents.length - 1];

    if (last?.role === 'user') {
      last.parts[0].text = `${last.parts[0].text}\n${message}`.slice(
        0,
        MAX_HISTORY_TEXT_LENGTH + MAX_MESSAGE_LENGTH,
      );
    } else {
      contents.push({ role: 'user', parts: [{ text: message }] });
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), GEMINI_TIMEOUT_MS);

    try {
      const providerResponse = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: JSON.stringify({
            systemInstruction: {
              parts: [{ text: systemInstruction }],
            },
            contents,
            generationConfig: {
              maxOutputTokens: 300,
              thinkingConfig: {
                thinkingLevel: 'low',
              },
            },
            store: false,
          }),
          signal: controller.signal,
        },
      );

      if (!providerResponse.ok) {
        console.warn(
          `haven-faith-ai: Gemini returned HTTP ${providerResponse.status}`,
        );

        if (providerResponse.status === 429) {
          return jsonResponse(
            { error: 'Haven Faith está recibiendo muchas solicitudes.' },
            429,
          );
        }

        return jsonResponse(
          { error: 'Haven Faith no está disponible en este momento.' },
          502,
        );
      }

      const providerBody = await providerResponse.json() as {
        candidates?: Array<{
          content?: {
            parts?: Array<{ text?: unknown }>;
          };
        }>;
      };

      const text = providerBody.candidates?.[0]?.content?.parts
        ?.map((part) => typeof part.text === 'string' ? part.text : '')
        .join('')
        .trim();

      if (!text) {
        console.warn('haven-faith-ai: Gemini returned an empty response');
        return jsonResponse(
          { error: 'Haven Faith no está disponible en este momento.' },
          502,
        );
      }

      return jsonResponse({ text });
    } catch (error) {
      if (error instanceof DOMException && error.name === 'AbortError') {
        return jsonResponse(
          { error: 'Haven Faith tardó demasiado en responder.' },
          504,
        );
      }

      console.error('haven-faith-ai: provider request failed');
      return jsonResponse(
        { error: 'Haven Faith no está disponible en este momento.' },
        502,
      );
    } finally {
      clearTimeout(timeout);
    }
  }),
};
