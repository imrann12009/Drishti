# DRISHTI secure OTA gate

OTA is disabled in the application (`UnavailableUpdateService`). No update
server, signing key, artifact, or successful OTA test exists in this workspace.

Before enabling OTA, the device-side updater—not the Flutter UI—must enforce:

1. HTTPS delivery from an approved update service and a manifest authenticated
   with an offline-root/online-release signing design.
2. Verification of the signed manifest, exact SHA-256 artifact hash, signature,
   target hardware identity, and minimum compatible bootloader version before
   writing an artifact.
3. Anti-rollback protection using a monotonic version/counter in protected
   storage. A lower version must be rejected unless an explicitly authorized,
   audited recovery policy permits it.
4. A power-loss-safe A/B or equivalent update scheme, post-boot health check,
   watchdog timeout, and automatic rollback to the last known-good image after
   a failed update.
5. Key identifiers in every manifest, release-key rotation with overlap,
   emergency key revocation, and a documented recovery path if a key is
   compromised.
6. Signed test artifacts exercised on the target Raspberry Pi hardware for
   hash mismatch, invalid signature, wrong target, interrupted download/write,
   failed boot, rollback, revoked key, and expired key cases.

The app must display update state as unavailable until the above implementation,
keys, update server, and recorded signed-hardware test evidence exist. It must
not report OTA success based on a downloaded file, a UI response, or a server
status alone.
