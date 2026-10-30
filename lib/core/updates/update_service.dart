/// Secure OTA boundary. This project intentionally ships no updater until the
/// release pipeline provides signed artifacts, key rotation, rollback, and
/// power-loss recovery.
abstract interface class UpdateService {
  Future<UpdateCheckResult> checkForUpdate();

  Future<UpdateApplyResult> apply(UpdatePackage package);
}

final class UpdatePackage {
  const UpdatePackage({
    required this.version,
    required this.artifactUri,
    required this.sha256,
    required this.signature,
  });

  final String version;
  final Uri artifactUri;
  final String sha256;
  final String signature;
}

final class UpdateCheckResult {
  const UpdateCheckResult({required this.available, this.package});

  final bool available;
  final UpdatePackage? package;
}

enum UpdateApplyStatus { unavailable, rejected, applied, rolledBack }

final class UpdateApplyResult {
  const UpdateApplyResult({required this.status, this.message});

  final UpdateApplyStatus status;
  final String? message;
}

final class UnavailableUpdateService implements UpdateService {
  const UnavailableUpdateService();

  @override
  Future<UpdateCheckResult> checkForUpdate() async => const UpdateCheckResult(
        available: false,
      );

  @override
  Future<UpdateApplyResult> apply(UpdatePackage package) async =>
      const UpdateApplyResult(
        status: UpdateApplyStatus.unavailable,
        message: 'Signed OTA delivery is not configured.',
      );
}
