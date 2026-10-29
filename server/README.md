# Drishti AI server

This TypeScript server uses Groq's official JavaScript SDK and the Groq Chat
Completions API. It accepts typed or speech-recognized text from the existing
Flutter chat, keeps the supplied conversation context, and returns text that
the app can display or pass to its existing TTS adapter.

The default `llama-3.3-70b-versatile` is listed by Groq as a current production
model. Change `GROQ_MODEL` only to a model supported by your Groq account.

## Create the local secret file

Do not paste a key into chat, source code, Flutter, Android resources, or an
APK. Instead, create the ignored file yourself:

```bash
cd /Users/imran/AccioWork/Drishti/server
cp .env.example .env
```

Open `server/.env` locally and replace only this placeholder:

```dotenv
GROQ_API_KEY=replace_with_your_server_side_key
```

Create and manage the key in the Groq Console. For deployment, create
`GROQ_API_KEY` and `GROQ_MODEL` in your hosting provider's secret/environment
settings instead of uploading `.env`.

## Run and test

```bash
cd /Users/imran/AccioWork/Drishti/server
npm install
npm run check
npm test
npm run dev
curl http://127.0.0.1:8788/health
```

With a valid key, health returns HTTP 200 and `{"ok":true}`. Then make a real
provider test:

```bash
curl -X POST http://127.0.0.1:8788/api/chat \
  -H 'content-type: application/json' \
  --data '{"messages":[{"role":"user","content":"Who is the founder of Dristhty Apps?"}]}'
```

Expected answer: `The founder of Dristhty Apps is Imran Ahmad.` The app also
instructs Bangla answers naturally when the user writes Bangla.

## Flutter configuration

Use a non-secret build define containing only the backend base URL:

```bash
# Android emulator: 10.0.2.2 maps to the development computer.
flutter run --dart-define=DRISHTI_CHAT_BASE_URL=http://10.0.2.2:8788 --dart-define=DRISHTI_ALLOW_HTTP_CHAT=true

# Physical phone on the same trusted LAN. Replace with your computer's LAN IP.
flutter run --dart-define=DRISHTI_CHAT_BASE_URL=http://192.168.x.x:8788 --dart-define=DRISHTI_ALLOW_HTTP_CHAT=true

# Production: HTTPS only; do not set DRISHTI_ALLOW_HTTP_CHAT.
flutter run --dart-define=DRISHTI_CHAT_BASE_URL=https://api.example.com
```

For a physical phone set `HOST=0.0.0.0` in the local `.env`, keep the firewall
restricted to the trusted LAN, and never expose that development HTTP server
publicly. The Android debug manifest alone permits cleartext HTTP. Release
builds require HTTPS.

The server limits JSON to 64 KiB, conversation history to 20 messages, each
message to 4000 characters, calls to 20 per IP per minute, and AI work to 30
seconds. It returns no prompts, provider errors, API keys, or stack traces.
For production, add HTTPS, real user authentication, a shared rate limiter/WAF,
monitoring, and a secret manager; its in-memory rate limiter is development
defense only.

## Render deployment

The repository's `render.yaml` defines the `drishti-ai-server` web service:
it runs from `server/`, runs `npm ci && npm run check`, starts with `npm start`,
uses `/health`, and binds to `0.0.0.0`. Connect the GitHub repository in Render,
then create a Blueprint from that file. In Render's environment-variable UI,
set `GROQ_API_KEY` as a secret. After a Flutter web site is deployed, set
`CORS_ORIGINS` to its exact HTTPS origin, for example `https://app.example.com`.
Neither value belongs in GitHub or the mobile app.

References: [Groq API reference](https://console.groq.com/docs/api-reference),
[Groq supported models](https://console.groq.com/docs/models).
