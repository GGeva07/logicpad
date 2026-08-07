import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_update_info.dart';

/// Consulta el último release publicado en GitHub y lo compara contra la
/// versión instalada. Nunca lanza: sin conexión, repo privado, o cualquier
/// error de red simplemente no hay actualización que ofrecer.
///
/// Si el código fuente vive en un repo privado, las releases (APK) tienen
/// que publicarse en un repo público aparte — la API de releases de GitHub
/// no responde en repos privados sin autenticación.
class AppUpdateService {
  AppUpdateService({
    this.owner = 'GGeva07',
    this.repo = 'logicpad',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String owner;
  final String repo;
  final http.Client _client;

  static const _lastSeenVersionKey = 'last_seen_app_version';

  /// Devuelve los datos del release si hay una versión más nueva que la
  /// instalada, o null si está al día o el chequeo falló.
  Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final response = await _client
          .get(
            Uri.parse('https://api.github.com/repos/$owner/$repo/releases/latest'),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String?)?.trim();
      if (tag == null || tag.isEmpty) return null;
      final latestVersion = tag.startsWith('v') ? tag.substring(1) : tag;

      final info = await PackageInfo.fromPlatform();
      if (!_isNewer(latestVersion, info.version)) return null;

      final assets = (json['assets'] as List?) ?? const [];
      String? apkUrl;
      for (final asset in assets) {
        final name = asset['name'] as String?;
        if (name != null && name.toLowerCase().endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      return AppUpdateInfo(
        version: latestVersion,
        htmlUrl: json['html_url'] as String? ??
            'https://github.com/$owner/$repo/releases/latest',
        apkDownloadUrl: apkUrl,
      );
    } catch (_) {
      return null;
    }
  }

  /// Si la versión instalada cambió desde la última vez que se abrió la
  /// app (típicamente, recién actualizaste), devuelve las notas de ese
  /// release para mostrar un "Novedades". Null en la primera instalación
  /// (nada con qué comparar), si ya se mostraron, o si falla la red. Marca
  /// la versión actual como vista, así solo se ofrece una vez.
  Future<String?> checkWhatsNew() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final prefs = await SharedPreferences.getInstance();
      final lastSeen = prefs.getString(_lastSeenVersionKey);
      await prefs.setString(_lastSeenVersionKey, info.version);
      if (lastSeen == null || lastSeen == info.version) return null;
      return await _fetchReleaseNotes(info.version);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _fetchReleaseNotes(String version) async {
    try {
      final response = await _client
          .get(
            Uri.parse('https://api.github.com/repos/$owner/$repo/releases/tags/v$version'),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final body = (json['body'] as String?)?.trim();
      return (body == null || body.isEmpty) ? null : body;
    } catch (_) {
      return null;
    }
  }

  /// Descarga el APK a un archivo temporal, reportando progreso 0..1 por
  /// [onProgress]. Lanza si la descarga falla; el caller decide cómo
  /// mostrarlo.
  Future<File> downloadApk(String url, {void Function(double progress)? onProgress}) async {
    final response =
        await _client.send(http.Request('GET', Uri.parse(url))).timeout(
              const Duration(minutes: 3),
            );
    if (response.statusCode != 200) {
      throw StateError('Descarga falló (HTTP ${response.statusCode})');
    }
    final total = response.contentLength ?? 0;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/app_update.apk');
    if (await file.exists()) await file.delete();
    final sink = file.openWrite();
    var received = 0;
    await for (final chunk in response.stream.timeout(const Duration(minutes: 3))) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) onProgress?.call(received / total);
    }
    await sink.close();
    return file;
  }

  /// Compara dos versiones "x.y.z" numéricamente (no lexicográficamente:
  /// "0.10.0" es más nueva que "0.9.0").
  bool _isNewer(String candidate, String current) {
    final a = _parts(candidate);
    final b = _parts(current);
    for (var i = 0; i < a.length || i < b.length; i++) {
      final ai = i < a.length ? a[i] : 0;
      final bi = i < b.length ? b[i] : 0;
      if (ai != bi) return ai > bi;
    }
    return false;
  }

  List<int> _parts(String version) =>
      version.split('+').first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
}
