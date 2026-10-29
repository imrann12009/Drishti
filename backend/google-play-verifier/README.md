# DRISHTI Google Play verifier backend

This service is a secure backend scaffold for the Flutter app's Google Play
subscription flow. It verifies purchase tokens through the Google Play
Developer API before returning `entitled: true`.

## Local setup

1. Install a complete Node.js runtime.
2. Copy `.env.example` to `.env`.
3. Set `GOOGLE_PLAY_PACKAGE_NAME` to the final Android `applicationId`.
4. Create a Google Cloud service account and enable Android Publisher API.
5. Link the Cloud project in Play Console API access and grant only the needed
   subscription/purchase permissions.
6. Keep the service-account JSON outside the repository and set
   `GOOGLE_APPLICATION_CREDENTIALS` to its absolute path.
7. Configure a real user/session authentication gateway. `DRISHTI_VERIFY_SHARED_SECRET`
   is a scaffold-only server-to-server guard; do not compile it into the Flutter app.
8. Install and test:

```bash
npm install
npm test
npm start
```

## Endpoint

`POST /v1/google-play/verify`

Request:

```json
{
  "platform": "google_play",
  "productId": "drishti_pro_monthly",
  "purchaseToken": "token-from-google-play"
}
```

The caller must authenticate with a server-issued user/session token. The
backend calls `purchases.subscriptionsv2.get`, confirms that the requested
product is present, checks subscription state and expiry, stores a hashed token
reference, and returns only `{ "entitled": true }` or false/error.

## Production requirements still open

- final Android package name and signed build;
- Play Console subscriptions with exact IDs/base plans;
- Cloud service account linked to Play Console;
- a real user authentication/session system instead of a shared mobile secret;
- durable database instead of the scaffold's in-memory map;
- Pub/Sub RTDN verification and worker processing;
- HTTPS-only deployment, a shared rate limiter/WAF (the in-process 20 requests
  per minute guard is not sufficient for multiple instances), audit logs that
  never contain raw purchase tokens, secret manager, monitoring, and
  refund/cancel/grace/hold/expiry tests.

Never commit `.env`, service-account JSON, purchase tokens, or private keys.
