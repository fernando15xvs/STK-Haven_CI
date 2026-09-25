import { withSupabase } from 'npm:@supabase/server@1.4.1';

const MAX_IMAGE_BYTES = 4 * 1024 * 1024;
const MAX_DISH_HINT = 160;
const GEMINI_TIMEOUT_MS = 30_000;
const DEFAULT_MODEL = 'gemini-3.8-flash';
const SUPPORTED_MIME = new Set(['image/jpeg', 'image/png', 'image/webp']);

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const responseSchema = {
  type: 'object',
  properties: {
    dishName: { type: 'string' },
    items: {
      type: 'array',
      maxItems: 20,
      items: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          portionDescription: { type: 'string' },
          gramsLow: { type: ['integer', 'null'] },
          gramsHigh: { type: ['integer', 'null'] },
          caloriesLow: { type: ['integer', 'null'] },
          caloriesHigh: { type: ['integer', 'null'] },
          proteinGramsLow: { type: ['number', 'null'] },
          proteinGramsHigh: { type: ['number', 'null'] },
          carbsGramsLow: { type: ['number', 'null'] },
          carbsGramsHigh: { type: ['number', 'null'] },
          fatGramsLow: { type: ['number', 'null'] },
          fatGramsHigh: { type: ['number', 'null'] },
          confidence: { type: 'string', enum: ['low', 'medium', 'high'] },
          uncertaintyNote: { type: 'string' },
        },
        required: [
          'name',
          'portionDescription',
          'gramsLow',
          'gramsHigh',
          'caloriesLow',
          'caloriesHigh',
          'proteinGramsLow',
          'proteinGramsHigh',
          'carbsGramsLow',
          'carbsGramsHigh',
          'fatGramsLow',
          'fatGramsHigh',
          'confidence',
          'uncertaintyNote',
        ],
      },
    },
    caloriesLow: { type: ['integer', 'null'] },
    caloriesHigh: { type: ['integer', 'null'] },
    proteinGramsLow: { type: ['number', 'null'] },
    proteinGramsHigh: { type: ['number', 'null'] },
    carbsGramsLow: { type: ['number', 'null'] },
    carbsGramsHigh: { type: ['number', 'null'] },
    fatGramsLow: { type: ['number', 'null'] },
    fatGramsHigh: { type: ['number', 'null'] },
    confidence: { type: 'string', enum: ['low', 'medium', 'high'] },
    numericNutritionAvailable: { type: 'boolean' },
    assumptions: {
      type: 'array',
      maxItems: 8,
      items: { type: 'string' },
    },
    questions: {
      type: 'array',
      maxItems: 5,
      items: { type: 'string' },
    },
    disclaimer: { type: 'string' },
  },
  required: [
    'dishName',
    'items',
    'caloriesLow',
    'caloriesHigh',
    'proteinGramsLow',
    'proteinGramsHigh',
    'carbsGramsLow',
    'carbsGramsHigh',
    'fatGramsLow',
    'fatGramsHigh',
    'confidence',
    'numericNutritionAvailable',
    'assumptions',
    'questions',
    'disclaimer',
  ],
};

const systemInstruction = [
  'Eres Food Vision de STK Haven.',
  'Analiza solamente lo que sea razonablemente visible en la foto y separa los componentes del plato.',
  'Nunca presentes una cifra nutricional como exacta: usa rangos y explicita incertidumbre.',
  'No inventes ingredientes ocultos, aceite, salsas ni cantidades que no puedas inferir; conviértelos en supuestos o preguntas.',
  'No hagas diagnósticos, dietas terapéuticas, consejos de pérdida de peso ni juicios morales sobre la comida.',
  'Si adultNumericNutrition es false, todos los campos de calorías y macronutrientes deben ser null y numericNutritionAvailable debe ser false.',
  'Si adultNumericNutrition es true, devuelve rangos prudentes de calorías/macros y numericNutritionAvailable true.',
  'La respuesta debe seguir estrictamente el esquema JSON solicitado.',
].join(' ');

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return Response.json(body, {
    status,
    headers: {
      ...corsHeaders,
      'Cache-Control': 'no-store',
    },
  });
}

function estimatedDecodedBytes(base64: string): number {
  const clean = base64.replace(/\s/g, '');
  if (!clean) return 0;
  const padding = clean.endsWith('==') ? 2 : clean.endsWith('=') ? 1 : 0;
  return Math.floor((clean.length * 3) / 4) - padding;
}

const authenticatedHandler = withSupabase(
  { auth: 'user' },
  async (req, ctx) => {
    if (req.method !== 'POST') {
      return jsonResponse({ error: 'Método no permitido.' }, 405);
    }

    let payload: Record<string, unknown>;
    try {
      const raw = await req.json();
      if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) {
        return jsonResponse({ error: 'Solicitud inválida.' }, 400);
      }
      payload = raw as Record<string, unknown>;
    } catch {
      return jsonResponse({ error: 'Solicitud inválida.' }, 400);
    }

    const userId = ctx.userClaims?.id;
    if (!userId) {
      return jsonResponse({ error: 'Sesión inválida.' }, 401);
    }

    const mimeType = typeof payload.mimeType === 'string'
      ? payload.mimeType.trim().toLowerCase()
      : '';
    const imageBase64 = typeof payload.imageBase64 === 'string'
      ? payload.imageBase64.trim()
      : '';
    const jwtClaims = ctx.jwtClaims as Record<string, unknown> | undefined;
    const rawAppMetadata = jwtClaims?.app_metadata;
    const appMetadata =
      typeof rawAppMetadata === 'object' && rawAppMetadata !== null
        ? rawAppMetadata as Record<string, unknown>
        : {};
    const hasVerifiedAdultNutritionAccess =
      appMetadata.adult_nutrition_access === true;
    const adultNumericNutrition =
      payload.adultNumericNutrition === true &&
      hasVerifiedAdultNutritionAccess;
    const dishHint = typeof payload.dishHint === 'string'
      ? payload.dishHint.trim().slice(0, MAX_DISH_HINT)
      : '';

    if (!SUPPORTED_MIME.has(mimeType)) {
      return jsonResponse({ error: 'Formato de imagen no compatible.' }, 400);
    }
    if (!imageBase64 || estimatedDecodedBytes(imageBase64) > MAX_IMAGE_BYTES) {
      return jsonResponse({ error: 'La imagen debe pesar como máximo 4 MB.' }, 400);
    }

    const apiKey = Deno.env.get('GEMINI_API_KEY')?.trim();
    if (!apiKey) {
      console.error('food-vision-ai: GEMINI_API_KEY is not configured');
      return jsonResponse(
        { error: 'Food Vision no está disponible en este momento.' },
        503,
      );
    }

    const model =
      Deno.env.get('GEMINI_FOOD_MODEL')?.trim() ||
      Deno.env.get('GEMINI_MODEL')?.trim() ||
      DEFAULT_MODEL;

    const prompt = [
      'Analiza esta foto de comida para ayudar al usuario a registrar el plato.',
      `adultNumericNutrition=${adultNumericNutrition ? 'true' : 'false'}.`,
      hasVerifiedAdultNutritionAccess
        ? 'La cuenta tiene acceso adulto verificado para este módulo.'
        : 'La cuenta no tiene acceso adulto verificado: no devuelvas calorías ni macros numéricos.',
      dishHint ? `Contexto opcional del usuario: ${dishHint}` : '',
      'Si la imagen no permite distinguir bien porciones o ingredientes, baja la confianza y formula preguntas concretas.',
      'No uses una cifra puntual cuando corresponda un rango.',
    ].filter(Boolean).join(' ');

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
            contents: [{
              role: 'user',
              parts: [
                { text: prompt },
                {
                  inlineData: {
                    mimeType,
                    data: imageBase64,
                  },
                },
              ],
            }],
            generationConfig: {
              maxOutputTokens: 1400,
              thinkingConfig: {
                thinkingLevel: 'low',
              },
              responseFormat: {
                text: {
                  mimeType: 'application/json',
                  schema: responseSchema,
                },
              },
            },
            store: false,
          }),
          signal: controller.signal,
        },
      );

      if (!providerResponse.ok) {
        console.warn(
          `food-vision-ai: Gemini returned HTTP ${providerResponse.status}`,
        );
        return jsonResponse(
          { error: 'Food Vision no pudo analizar la imagen.' },
          providerResponse.status === 429 ? 429 : 502,
        );
      }

      const providerBody = await providerResponse.json() as {
        candidates?: Array<{
          content?: { parts?: Array<{ text?: unknown }> };
        }>;
      };

      const text = providerBody.candidates?.[0]?.content?.parts
        ?.map((part) => typeof part.text === 'string' ? part.text : '')
        .join('')
        .trim();

      if (!text) {
        return jsonResponse(
          { error: 'Food Vision no devolvió un análisis utilizable.' },
          502,
        );
      }

      let estimate: Record<string, unknown>;
      try {
        const parsed = JSON.parse(text);
        if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
          throw new Error('invalid-json-shape');
        }
        estimate = parsed as Record<string, unknown>;
      } catch {
        console.warn('food-vision-ai: structured output was invalid JSON');
        return jsonResponse(
          { error: 'Food Vision devolvió un formato inesperado.' },
          502,
        );
      }

      // Server-side fail-closed guard: non-adult mode never returns numeric
      // calorie or macro totals even if an upstream model violates the prompt.
      if (!adultNumericNutrition) {
        estimate.caloriesLow = null;
        estimate.caloriesHigh = null;
        estimate.proteinGramsLow = null;
        estimate.proteinGramsHigh = null;
        estimate.carbsGramsLow = null;
        estimate.carbsGramsHigh = null;
        estimate.fatGramsLow = null;
        estimate.fatGramsHigh = null;
        estimate.numericNutritionAvailable = false;

        if (Array.isArray(estimate.items)) {
          estimate.items = estimate.items.map((raw) => {
            if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) {
              return raw;
            }
            return {
              ...(raw as Record<string, unknown>),
              caloriesLow: null,
              caloriesHigh: null,
              proteinGramsLow: null,
              proteinGramsHigh: null,
              carbsGramsLow: null,
              carbsGramsHigh: null,
              fatGramsLow: null,
              fatGramsHigh: null,
            };
          });
        }
      }

      return jsonResponse({
        estimate,
        imageStored: false,
      });
    } catch (error) {
      if (error instanceof DOMException && error.name === 'AbortError') {
        return jsonResponse(
          { error: 'Food Vision tardó demasiado en responder.' },
          504,
        );
      }
      console.error('food-vision-ai: provider request failed');
      return jsonResponse(
        { error: 'Food Vision no está disponible en este momento.' },
        502,
      );
    } finally {
      clearTimeout(timeout);
    }
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
