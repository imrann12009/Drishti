# DRISHTI Google Play subscriptions

## Planned plans

| App label | App-side product ID | Buyer price supplied | Play Console status |
|---|---|---:|---|
| Monthly | `drishti_pro_monthly` | ৳299 / month | Not created yet |
| 6 month | `drishti_pro_6_month` | ৳1,699 / 6 months | Not created yet |
| Yearly | `drishti_pro_yearly` | ৳2,899 / year | Not created yet |

The product IDs above are proposed IDs. They become real only after the same
IDs are created and configured in Google Play Console. Prices shown in the app
are only planning values; the Play Store must be treated as the source of the
localized purchase price.

## App-side implementation

`GooglePlayPaymentService` now:

- uses Flutter's `in_app_purchase` Google Play surface;
- listens to the purchase stream;
- queries the configured product IDs;
- launches the store purchase flow;
- supports restore-purchases flow;
- sends the product ID and purchase token to a configured verification endpoint;
- fails closed when no endpoint exists or the backend does not return
  `{"entitled": true}`;
- completes a pending store purchase only after backend verification.

No backend URL is configured in this repository.

## Required Play Console setup

1. Create and verify a Google Play Console developer account.
2. Create the Android app with the final package name and signing setup.
3. Create one subscription product and configure three base plans/offers, or
   use the final product structure approved for the business. Do not assume
   that three app labels alone define the Play catalog.
4. Use exact, unique product IDs and configure the intended billing periods and
   prices in Play Console.
5. Add license testers/internal testers and upload a signed test build.
6. Verify purchase, cancellation, renewal, grace period, account hold,
   restore, refund, and expired states before production rollout.
7. Configure Real-time Developer Notifications (RTDN) and a backend service
   account with only the required Google Play Developer API permissions.

## Required backend contract

The app sends a request like:

```json
{
  "platform": "google_play",
  "productId": "drishti_pro_monthly",
  "purchaseToken": "store-provided-token"
}
```

The backend must authenticate the app request, call the Google Play Developer
API using server credentials, verify package name/product ID/token/state, store
entitlement state, process RTDN changes, and return only a safe entitlement
result. Minimum success response:

```json
{"entitled": true}
```

Any other response, network failure, invalid token, canceled/expired state, or
backend error must leave Pro disabled. Never place Google service-account keys
in the Flutter app.

## Current status

The app-side adapter and subscription screen are present. Live billing is not
active because Play Console products, a signed test build, testers, RTDN, and a
trusted verification backend have not yet been created.
