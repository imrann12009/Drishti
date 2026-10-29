import 'dotenv/config';
import crypto from 'node:crypto';
import express from 'express';
import { google } from 'googleapis';

const PORT = Number(process.env.PORT || 8787);
const PACKAGE_NAME = process.env.GOOGLE_PLAY_PACKAGE_NAME;
const VERIFY_SECRET = process.env.DRISHTI_VERIFY_SHARED_SECRET;
const RTDN_SECRET = process.env.RTDN_SHARED_SECRET;
const CHAT_SESSION_SECRET = process.env.DRISHTI_CHAT_SESSION_SECRET;
const PRODUCT_IDS = new Set([
  'drishti_pro_monthly',
  'drishti_pro_6_month',
  'drishti_pro_yearly',
]);
const ACTIVE_STATES = new Set([
  'SUBSCRIPTION_STATE_ACTIVE',
  'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
]);

const app = express();
app.use(express.json({ limit: '32kb' }));

const entitlementStore = new Map();
const requestBuckets = new Map();
let publisher;

function timingSafeEqualText(left, right) {
  if (!left || !right) return false;
  const a = Buffer.from(left);
  const b = Buffer.from(right);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

function requireAppAuth(req, res, next) {
  if (!timingSafeEqualText(req.get('authorization')?.replace(/^Bearer\s+/i, ''), VERIFY_SECRET)) {
    return res.status(401).json({ error: 'unauthorized' });
  }
  return next();
}

function requireRtdnAuth(req, res, next) {
  if (!timingSafeEqualText(req.get('x-rtdn-secret'), RTDN_SECRET)) {
    return res.status(401).json({ error: 'unauthorized' });
  }
  return next();
}

function verifyRateLimit(req, res, next) {
  // This is a conservative process-local guard. Production must use a shared
  // rate limiter at the gateway/store layer so instances cannot be bypassed.
  const key = req.get('x-user-id') || req.ip || 'unknown';
  const now = Date.now();
  const bucket = requestBuckets.get(key) || { startedAt: now, count: 0 };
  if (now - bucket.startedAt >= 60_000) {
    bucket.startedAt = now;
    bucket.count = 0;
  }
  bucket.count += 1;
  requestBuckets.set(key, bucket);
  if (bucket.count > 20) return res.status(429).json({ entitled: false, error: 'rate_limited' });
  return next();
}

function requireChatAuth(req, res, next) {
  // Local development may be enabled deliberately, never by default. Production
  // requires a server-issued session/JWT validated at this boundary.
  if (process.env.NODE_ENV !== 'production' && process.env.DRISHTI_ALLOW_UNAUTHENTICATED_CHAT === 'true') return next();
  if (!timingSafeEqualText(req.get('authorization')?.replace(/^Bearer\s+/i, ''), CHAT_SESSION_SECRET)) {
    return res.status(401).json({ error: 'unauthorized' });
  }
  return next();
}

function drishtiSystemInstruction() {
  return [
    'You are Drishti AI, an accessibility assistant for blind and visually impaired people.',
    'The founder of Drishti is Imran Ahmad.',
    'If asked who founded Drishti, answer exactly: The founder of Drishti is Imran Ahmad.',
    'If asked in Bangla, answer naturally: Drishti-এর প্রতিষ্ঠাতা হলেন Imran Ahmad।',
    'Reply in the language used by the user (Bangla or English). Be concise, clear, and suitable for voice playback.',
    'Answer general questions helpfully and accurately. Never invent facts about Drishti.',
    'Do not claim to have detected objects, analyzed images, accessed a camera, sensor, location, or real-world surroundings unless that capability was actually used in this conversation.',
  ].join(' ');
}

function validatedChatMessages(messages) {
  if (!Array.isArray(messages) || messages.length === 0 || messages.length > 20) return null;
  const validated = [];
  for (const message of messages) {
    if (!message || !['user', 'assistant'].includes(message.role) || typeof message.content !== 'string') return null;
    const content = message.content.trim();
    if (!content || content.length > 4000) return null;
    validated.push({ role: message.role, content });
  }
  if (!validated.some((message) => message.role === 'user')) return null;
  return validated;
}

async function generateChatReply(messages, fetchImpl = fetch) {
  const chatModel = process.env.OPENAI_CHAT_MODEL || 'gpt-4o-mini';
  const chatBaseUrl = process.env.OPENAI_BASE_URL || 'https://api.openai.com/v1';
  if (!process.env.OPENAI_API_KEY || !chatBaseUrl.startsWith('https://')) {
    throw new Error('AI provider is not configured');
  }
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 25_000);
  try {
    const response = await fetchImpl(`${chatBaseUrl.replace(/\/$/, '')}/chat/completions`, {
      method: 'POST',
      signal: controller.signal,
      headers: {
        authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model: chatModel,
        messages: [{ role: 'system', content: drishtiSystemInstruction() }, ...messages],
        temperature: 0.3,
        max_tokens: 350,
      }),
    });
    if (!response.ok) throw new Error('AI provider request failed');
    const body = await response.json();
    const reply = body?.choices?.[0]?.message?.content;
    if (typeof reply !== 'string' || !reply.trim() || reply.length > 8000) throw new Error('AI provider returned an invalid response');
    return reply.trim();
  } finally {
    clearTimeout(timer);
  }
}

function getPublisher() {
  if (publisher) return publisher;
  if (!PACKAGE_NAME || !process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    throw new Error('Google Play credentials/package are not configured');
  }
  const auth = new google.auth.GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  publisher = google.androidpublisher({ version: 'v3', auth });
  return publisher;
}

function parseExpiry(subscription) {
  const expiry = subscription.lineItems?.[0]?.expiryTime;
  const time = expiry ? Date.parse(expiry) : NaN;
  return Number.isFinite(time) ? time : null;
}

function entitlementFromSubscription(productId, purchaseToken, subscription) {
  const state = subscription.subscriptionState;
  const expiryMs = parseExpiry(subscription);
  const entitled = ACTIVE_STATES.has(state) && expiryMs !== null && expiryMs > Date.now();
  return {
    entitled,
    productId,
    state: state || 'UNKNOWN',
    expiryTime: expiryMs === null ? null : new Date(expiryMs).toISOString(),
    tokenHash: crypto.createHash('sha256').update(purchaseToken).digest('hex'),
  };
}

async function verifyPurchase(productId, purchaseToken) {
  const api = getPublisher();
  const response = await api.purchases.subscriptionsv2.get({
    packageName: PACKAGE_NAME,
    token: purchaseToken,
  });
  const subscription = response.data;
  const hasProduct = subscription.lineItems?.some((item) => item.productId === productId);
  if (!hasProduct) {
    return { entitled: false, state: 'PRODUCT_MISMATCH', expiryTime: null };
  }
  const result = entitlementFromSubscription(productId, purchaseToken, subscription);
  entitlementStore.set(result.tokenHash, result);
  return result;
}

app.get('/health', (_req, res) => {
  res.json({ ok: true, service: 'drishti-google-play-verifier' });
});

app.post('/v1/google-play/verify', requireAppAuth, verifyRateLimit, async (req, res) => {
  const { platform, productId, purchaseToken } = req.body || {};
  if (platform !== 'google_play' || !PRODUCT_IDS.has(productId) || typeof purchaseToken !== 'string' || purchaseToken.length < 20 || purchaseToken.length > 16_384) {
    return res.status(400).json({ entitled: false, error: 'invalid_request' });
  }
  try {
    const result = await verifyPurchase(productId, purchaseToken);
    return res.status(200).json({ entitled: result.entitled });
  } catch (error) {
    // Do not log raw purchase tokens or upstream error objects, which may
    // include sensitive request details.
    console.error('purchase verification failed');
    return res.status(502).json({ entitled: false, error: 'verification_unavailable' });
  }
});

app.post('/v1/chat', requireChatAuth, verifyRateLimit, async (req, res) => {
  const messages = validatedChatMessages(req.body?.messages);
  if (!messages) return res.status(400).json({ error: 'invalid_request' });
  try {
    const reply = await generateChatReply(messages);
    return res.status(200).json({ reply });
  } catch (_error) {
    // Avoid logging prompts, bearer tokens, provider responses, or API keys.
    console.error('AI chat request failed');
    return res.status(503).json({ error: 'AI service is temporarily unavailable.' });
  }
});

app.post('/v1/rtdn', requireRtdnAuth, async (req, res) => {
  // RTDN payloads should be decoded and verified through Google Pub/Sub in the
  // deployed environment. This endpoint acknowledges only authenticated input;
  // a production worker must fetch the latest subscription state by token.
  const message = req.body?.message;
  if (!message) return res.status(400).json({ error: 'invalid_rtdn' });
  return res.status(204).send();
});

app.use((error, _req, res, _next) => {
  if (error?.type === 'entity.too.large') return res.status(413).json({ error: 'payload_too_large' });
  return res.status(400).json({ error: 'invalid_json' });
});

if (process.env.NODE_ENV !== 'test') {
  app.listen(PORT, () => console.log(`DRISHTI verifier listening on ${PORT}`));
}

export { app, drishtiSystemInstruction, entitlementFromSubscription, generateChatReply, validatedChatMessages, verifyPurchase };
