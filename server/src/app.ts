import cors from 'cors';
import express, { type Express, type NextFunction, type Request, type Response } from 'express';

import { generateReply, type ResponseGenerator, validateMessages } from './chat.js';

export type AppConfig = {
  model: string;
  allowedOrigins: string[];
  generator: ResponseGenerator | null;
  requestTimeoutMs: number;
};

const rateLimitWindowMs = 60_000;
const rateLimitMaximum = 20;

export function createApp(config: AppConfig): Express {
  const app = express();
  const requests = new Map<string, { startedAt: number; count: number }>();
  app.disable('x-powered-by');
  if (config.allowedOrigins.length > 0) {
    app.use(cors({ origin: config.allowedOrigins, methods: ['GET', 'POST'], allowedHeaders: ['content-type'] }));
  }
  app.use(express.json({ limit: '64kb' }));

  app.get('/health', (_request, response) => {
    response.status(config.generator ? 200 : 503).json({ ok: config.generator !== null, service: 'drishti-ai-server' });
  });

  app.post('/api/chat', rateLimit(requests), async (request, response) => {
    const messages = validateMessages(request.body?.messages);
    if (!messages) return response.status(400).json({ error: 'Invalid chat messages.' });
    if (!config.generator) return response.status(503).json({ error: 'AI service is not configured.' });
    try {
      const reply = await withTimeout(generateReply(config.generator, config.model, messages), config.requestTimeoutMs);
      return response.status(200).json({ reply });
    } catch (_error) {
      // Do not log messages, headers, provider errors, or credentials.
      return response.status(503).json({ error: 'AI service is temporarily unavailable. Please try again.' });
    }
  });

  app.use((error: unknown, _request: Request, response: Response, _next: NextFunction) => {
    if (error && typeof error === 'object' && 'type' in error && error.type === 'entity.too.large') {
      return response.status(413).json({ error: 'Request is too large.' });
    }
    return response.status(400).json({ error: 'Invalid JSON request.' });
  });
  return app;
}

function rateLimit(store: Map<string, { startedAt: number; count: number }>) {
  return (request: Request, response: Response, next: NextFunction) => {
    const key = request.ip || 'unknown';
    const now = Date.now();
    const item = store.get(key) ?? { startedAt: now, count: 0 };
    if (now - item.startedAt >= rateLimitWindowMs) {
      item.startedAt = now;
      item.count = 0;
    }
    item.count += 1;
    store.set(key, item);
    if (item.count > rateLimitMaximum) return response.status(429).json({ error: 'Too many requests. Please try again later.' });
    return next();
  };
}

function withTimeout<T>(future: Promise<T>, timeoutMs: number): Promise<T> {
  return Promise.race([
    future,
    new Promise<T>((_resolve, reject) => setTimeout(() => reject(new Error('timeout')), timeoutMs)),
  ]);
}
