# Drishti AI Chat setup

The Flutter client sends the active chat context to `POST /api/chat`. The
dedicated server uses Groq's official SDK and reads `GROQ_API_KEY` only from its
server environment. No API key is compiled into Flutter or Android.

Follow the exact secure local/hosting setup, Android emulator mapping, physical
phone LAN configuration, production HTTPS requirements, and real request test
in [server/README.md](../server/README.md).

The same endpoint accepts typed or speech-recognized text and returns text for
the existing TTS adapter. New Chat clears the in-memory conversation context.
