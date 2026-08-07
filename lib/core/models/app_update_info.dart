/// Datos de una actualización disponible, resuelta desde GitHub Releases.
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    required this.htmlUrl,
    this.apkDownloadUrl,
  });

  /// Versión del release (sin el prefijo "v"), ej. "1.2.0".
  final String version;

  /// Página del release en GitHub, para cuando no hay APK adjunto.
  final String htmlUrl;

  /// URL directa al .apk adjunto al release, si lo tiene.
  final String? apkDownloadUrl;
}
