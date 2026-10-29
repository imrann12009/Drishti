import dotenv from 'dotenv';

import Groq from 'groq-sdk';

import { createApp } from './app.js';
import { GroqResponseGenerator } from './chat.js';

// Always load the server-local ignored environment file, independent of the
// terminal's working directory. Values are intentionally never logged.
dotenv.config({ path: new URL('../.env', import.meta.url) });

const port = Number(process.env.PORT ?? 8788);
// Render (and other managed hosts) must accept connections outside the
// container. Local development remains loopback-only unless HOST is set.
const host = process.env.HOST ?? (process.env.NODE_ENV === 'production' ? '0.0.0.0' : '127.0.0.1');
const model = process.env.GROQ_MODEL ?? 'llama-3.3-70b-versatile';
const allowedOrigins = (process.env.CORS_ORIGINS ?? '').split(',').map((value) => value.trim()).filter(Boolean);
const apiKey = process.env.GROQ_API_KEY;
const generator = apiKey
  ? new GroqResponseGenerator(new Groq({ apiKey, timeout: 25_000, maxRetries: 0 }), model)
  : null;

const app = createApp({ model, allowedOrigins, generator, requestTimeoutMs: 30_000 });
app.listen(port, host, () => console.log(`Drishti AI server listening on ${host}:${port}`));
