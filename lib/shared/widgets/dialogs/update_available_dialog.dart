import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/app_update_info.dart';
import '../../../core/services/app_update_service.dart';
import '../../theme/app_colors.dart';

/// Muestra el diálogo de "hay una actualización disponible". No se puede
/// cerrar tocando afuera: el usuario elige explícitamente entre actualizar
/// o posponer.
Future<void> showUpdateAvailableDialog(
  BuildContext context,
  AppUpdateInfo info, {
  required AppUpdateService updateService,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateAvailableDialog(info: info, updateService: updateService),
  );
}

enum _Stage { info, downloading, error }

class _UpdateAvailableDialog extends StatefulWidget {
  const _UpdateAvailableDialog({required this.info, required this.updateService});

  final AppUpdateInfo info;
  final AppUpdateService updateService;

  @override
  State<_UpdateAvailableDialog> createState() => _UpdateAvailableDialogState();
}

class _UpdateAvailableDialogState extends State<_UpdateAvailableDialog> {
  _Stage _stage = _Stage.info;
  double _progress = 0;

  Future<void> _download() async {
    final url = widget.info.apkDownloadUrl;
    if (url == null) {
      await launchUrl(Uri.parse(widget.info.htmlUrl), mode: LaunchMode.externalApplication);
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() {
      _stage = _Stage.downloading;
      _progress = 0;
    });
    try {
      final file = await widget.updateService.downloadApk(
        url,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      await OpenFilex.open(file.path);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _stage = _Stage.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      icon: const Icon(Icons.system_update_rounded, color: AppColors.primary, size: 32),
      title: const Text('Nueva versión disponible'),
      content: _buildContent(),
      actions: _buildActions(),
    );
  }

  Widget _buildContent() {
    switch (_stage) {
      case _Stage.info:
        return Text('Hay una nueva versión (v${widget.info.version}) lista para instalar.');
      case _Stage.downloading:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: _progress > 0 ? _progress : null, color: AppColors.primary),
            const SizedBox(height: 12),
            Text('Descargando... ${(_progress * 100).toStringAsFixed(0)}%'),
          ],
        );
      case _Stage.error:
        return const Text('No se pudo descargar la actualización. Probá de nuevo más tarde.');
    }
  }

  List<Widget> _buildActions() {
    if (_stage == _Stage.downloading) return const [];
    return [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Ahora no')),
      FilledButton(
        onPressed: _download,
        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
        child: Text(_stage == _Stage.error ? 'Reintentar' : 'Descargar'),
      ),
    ];
  }
}
