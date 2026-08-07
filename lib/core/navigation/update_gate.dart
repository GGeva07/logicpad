import 'package:flutter/material.dart';

import '../di/service_locator.dart';
import '../services/app_update_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/dialogs/update_available_dialog.dart';
import '../../shared/widgets/dialogs/whats_new_dialog.dart';

/// Corre el chequeo de actualización (y de "novedades") contra GitHub
/// Releases antes de construir [child] — así, si hay una versión nueva, el
/// aviso aparece incluso antes de la pantalla de login. Cualquier falla de
/// red hace que el chequeo termine en null y [child] se muestre igual, sin
/// bloquear el arranque normal.
class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    final service = sl<AppUpdateService>();

    final notes = await service.checkWhatsNew();
    final ctxAfterWhatsNew = _navigatorKey.currentContext;
    if (notes != null && ctxAfterWhatsNew != null && ctxAfterWhatsNew.mounted) {
      await showWhatsNewDialog(ctxAfterWhatsNew, notes);
    }

    final update = await service.checkForUpdate();
    final ctx = _navigatorKey.currentContext;
    if (update != null && ctx != null && ctx.mounted) {
      await showUpdateAvailableDialog(ctx, update, updateService: service);
    }

    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;

    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
    );
  }
}
