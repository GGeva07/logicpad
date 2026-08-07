import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logicpad/core/constants/app_routes.dart';
import 'package:logicpad/core/di/service_locator.dart';
import 'package:logicpad/features/canvas/domain/entities/stroke.dart';
import 'package:logicpad/features/canvas/domain/entities/recognized_object.dart';
import 'package:logicpad/features/canvas/presentation/bloc/canvas_bloc.dart';
import 'package:logicpad/features/canvas/presentation/bloc/canvas_event.dart';
import 'package:logicpad/features/canvas/presentation/bloc/canvas_state.dart';
import 'package:logicpad/shared/theme/app_colors.dart';
import 'package:logicpad/shared/theme/app_text_styles.dart';
import 'package:logicpad/shared/widgets/feedback/app_notification.dart';

enum CanvasTool { pan, pen, eraser }

class CanvasScreen extends StatefulWidget {
  const CanvasScreen({super.key});

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> with TickerProviderStateMixin {
  final TransformationController _tc = TransformationController();
  CanvasTool _selectedTool = CanvasTool.pen;
  late AnimationController _confirmPulse;

  static const double _canvasSize = 8000.0;

  // Punto de inicio del mundo para centrar la vista
  static const double _startX = _canvasSize / 2 - 200;
  static const double _startY = _canvasSize / 2 - 300;

  @override
  void initState() {
    super.initState();
    _tc.value = Matrix4.translationValues(-_startX, -_startY, 0);
    _confirmPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _tc.dispose();
    _confirmPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CanvasBloc>(
      create: (_) => sl<CanvasBloc>()..add(const LoadCanvas()),
      child: Builder(builder: (blocCtx) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Theme.of(blocCtx).brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: Theme.of(blocCtx).scaffoldBackgroundColor,
          body: Stack(
            children: [
              // ── LIENZO ───────────────────────────────────────────────
              _CanvasArea(
                tc: _tc,
                tool: _selectedTool,
                canvasSize: _canvasSize,
              ),

              // ── CABECERA ─────────────────────────────────────────────
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      _HeaderChip(),
                      const Spacer(),
                      _HistoryActions(),
                    ],
                  ),
                ),
              ),

              // ── BANNER DE RECONOCIMIENTO ──────────────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: BlocBuilder<CanvasBloc, CanvasState>(
                    buildWhen: (a, b) => a.pendingObject != b.pendingObject,
                    builder: (context, state) {
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        transitionBuilder: (child, anim) => SlideTransition(
                          position: Tween(
                            begin: const Offset(0, -1.5),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                          child: FadeTransition(opacity: anim, child: child),
                        ),
                        child: state.pendingObject != null
                            ? _RecognitionBanner(
                                key: ValueKey(state.pendingObject!.id),
                                pulse: _confirmPulse,
                              )
                            : const SizedBox.shrink(),
                      );
                    },
                  ),
                ),
              ),

              // ── TOOLBAR INFERIOR ─────────────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _BottomToolbar(
                      selected: _selectedTool,
                      onToolChanged: (t) {
                        setState(() => _selectedTool = t);
                        blocCtx.read<CanvasBloc>().add(ToggleTool(
                          t == CanvasTool.eraser ? ToolType.eraser : ToolType.pen,
                        ));
                      },
                      onClearRequested: () => _confirmClear(blocCtx),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        );
      }),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Limpiar todo?'),
        content: const Text(
            'Se borrarán todos los trazos y diagramas. Esta acción se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              context.read<CanvasBloc>().add(const ClearAll());
              Navigator.pop(ctx);
              AppNotification.info(context, 'Lienzo limpiado');
            },
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Área del lienzo
// ─────────────────────────────────────────────────────────────────────────────

class _CanvasArea extends StatefulWidget {
  final TransformationController tc;
  final CanvasTool tool;
  final double canvasSize;

  const _CanvasArea({
    required this.tc,
    required this.tool,
    required this.canvasSize,
  });

  @override
  State<_CanvasArea> createState() => _CanvasAreaState();
}

class _CanvasAreaState extends State<_CanvasArea> {
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: BlocBuilder<CanvasBloc, CanvasState>(
        builder: (context, state) {
          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: widget.tool != CanvasTool.pan
                ? (e) => _addPoint(context, e.localPosition)
                : null,
            onPointerMove: widget.tool != CanvasTool.pan
                ? (e) => _movePoint(context, e.localPosition)
                : null,
            onPointerUp: widget.tool != CanvasTool.pan
                ? (_) => context.read<CanvasBloc>().add(const EndStroke())
                : null,
            onPointerCancel: widget.tool != CanvasTool.pan
                ? (_) => context.read<CanvasBloc>().add(const EndStroke())
                : null,
            child: InteractiveViewer(
              transformationController: widget.tc,
              minScale: 0.2,
              maxScale: 5.0,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              panEnabled: widget.tool == CanvasTool.pan,
              scaleEnabled: true,
              child: SizedBox(
                width: widget.canvasSize,
                height: widget.canvasSize,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: CanvasBackgroundPainter(
                      isDark: Theme.of(context).brightness == Brightness.dark,
                    ),
                    foregroundPainter: CanvasContentPainter(
                      strokes: state.strokes,
                      activeStroke: state.activeStroke,
                      objects: state.objects,
                      pendingObject: state.pendingObject,
                      isDark: Theme.of(context).brightness == Brightness.dark,
                    ),
                    // Transparent hit-test overlay para doble-tap en objetos
                    child: _ObjectHitLayer(objects: state.objects),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Offset _toScene(Offset local) => widget.tc.toScene(local);

  Point _makePoint(Offset scenePos) => Point(
        x: scenePos.dx,
        y: scenePos.dy,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

  void _addPoint(BuildContext ctx, Offset local) {
    final p = _makePoint(_toScene(local));
    ctx.read<CanvasBloc>().add(StartStroke(p));
  }

  void _movePoint(BuildContext ctx, Offset local) {
    final p = _makePoint(_toScene(local));
    ctx.read<CanvasBloc>().add(UpdateStroke(p));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Capa de áreas tapeables sobre objetos (sin bloquear el pan del IV)
// ─────────────────────────────────────────────────────────────────────────────

class _ObjectHitLayer extends StatelessWidget {
  final List<RecognizedObject> objects;
  const _ObjectHitLayer({required this.objects});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (final obj in objects)
          Positioned(
            left: obj.boundingBox.left,
            top: obj.boundingBox.top,
            width: obj.boundingBox.width,
            height: obj.boundingBox.height,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: () => _openUmlEditor(context, obj),
              child: const SizedBox.expand(),
            ),
          ),
      ],
    );
  }

  void _openUmlEditor(BuildContext context, RecognizedObject obj) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UmlClassEditor(obj: obj),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner de reconocimiento (aparece / desaparece animado)
// ─────────────────────────────────────────────────────────────────────────────

class _RecognitionBanner extends StatelessWidget {
  final AnimationController pulse;
  const _RecognitionBanner({super.key, required this.pulse});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CanvasBloc, CanvasState>(
      buildWhen: (a, b) => a.pendingObject != b.pendingObject,
      builder: (context, state) {
        final pending = state.pendingObject;
        if (pending == null) return const SizedBox.shrink();

        final (label, icon, hint, canBeClass) = _shapeInfo(pending.type);

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 72, 16, 0),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: pulse,
                builder: (_, child) => Transform.scale(
                  scale: 0.9 + pulse.value * 0.1,
                  child: child,
                ),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.titleSmall.copyWith(color: Colors.white),
                    ),
                    Text(
                      hint,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.75),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () =>
                    context.read<CanvasBloc>().add(const RejectPendingObject()),
                child: const Text('Ignorar'),
              ),
              if (canBeClass)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () {
                    context.read<CanvasBloc>().add(const ConfirmPendingObject());
                    Future.delayed(const Duration(milliseconds: 120), () {
                      if (context.mounted) {
                        final s = context.read<CanvasBloc>().state;
                        final lastObj = s.objects.isNotEmpty ? s.objects.last : null;
                        if (lastObj != null) {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => _UmlClassEditor(obj: lastObj),
                          );
                        }
                      }
                    });
                  },
                  child: const Text('Clase'),
                ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                ),
                onPressed: () {
                  context.read<CanvasBloc>().add(const ConfirmPendingObject());
                  AppNotification.success(context, '✓ $label vectorizado');
                },
                child: const Text('Limpiar'),
              ),
            ],
          ),
        );
      },
    );
  }

  static (String label, IconData icon, String hint, bool canBeClass)
      _shapeInfo(RecognizedObjectType type) {
    switch (type) {
      case RecognizedObjectType.rectangle:
        return (
          'Rectángulo detectado',
          Icons.crop_square_rounded,
          'Toca "Limpiar" para vectorizar, o "Clase" para crear una clase UML',
          true,
        );
      case RecognizedObjectType.circle:
        return (
          'Círculo detectado',
          Icons.radio_button_unchecked_rounded,
          'Toca "Limpiar" para convertirlo en un círculo perfecto',
          false,
        );
      case RecognizedObjectType.diamond:
        return (
          'Rombo detectado',
          Icons.diamond_outlined,
          'Toca "Limpiar" para convertirlo en un rombo limpio',
          false,
        );
      case RecognizedObjectType.line:
        return (
          'Línea recta detectada',
          Icons.linear_scale_rounded,
          'Toca "Limpiar" para convertirla en una línea perfecta',
          false,
        );
      case RecognizedObjectType.arrow:
        return (
          'Flecha detectada',
          Icons.arrow_forward_rounded,
          'Toca "Limpiar" para convertirla en una flecha vectorial',
          false,
        );
      case RecognizedObjectType.umlClass:
        return (
          'Clase UML',
          Icons.table_chart_rounded,
          '',
          false,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header chip (logo)
// ─────────────────────────────────────────────────────────────────────────────


class _HeaderChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceDark.withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Text(
            'LogicPad',
            style: AppTextStyles.titleSmall.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.releaseNotes),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'v0.1',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.secondaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(Icons.info_outline_rounded,
                      size: 10, color: AppColors.secondaryDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Acciones de historial
// ─────────────────────────────────────────────────────────────────────────────

class _HistoryActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocBuilder<CanvasBloc, CanvasState>(
      buildWhen: (a, b) => a.canUndo != b.canUndo || a.canRedo != b.canRedo,
      builder: (context, state) => Container(
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.surfaceDark.withValues(alpha: 0.92)
              : Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconBtn(
              icon: Icons.undo_rounded,
              tooltip: 'Deshacer',
              enabled: state.canUndo,
              onTap: () => context.read<CanvasBloc>().add(const Undo()),
            ),
            Container(width: 1, height: 20, color: Theme.of(context).dividerColor),
            _IconBtn(
              icon: Icons.redo_rounded,
              tooltip: 'Rehacer',
              enabled: state.canRedo,
              onTap: () => context.read<CanvasBloc>().add(const Redo()),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Icon(
            icon,
            size: 20,
            color: enabled
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toolbar inferior
// ─────────────────────────────────────────────────────────────────────────────

class _BottomToolbar extends StatelessWidget {
  final CanvasTool selected;
  final void Function(CanvasTool) onToolChanged;
  final VoidCallback onClearRequested;

  const _BottomToolbar({
    required this.selected,
    required this.onToolChanged,
    required this.onClearRequested,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (selected == CanvasTool.pen)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ColorPalette(),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
        // Selector de herramientas
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceDark.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ToolBtn(
                icon: Icons.open_with_rounded,
                label: 'Mover',
                tool: CanvasTool.pan,
                selected: selected,
                onTap: () => onToolChanged(CanvasTool.pan),
              ),
              const SizedBox(width: 4),
              _ToolBtn(
                icon: Icons.brush_rounded,
                label: 'Dibujar',
                tool: CanvasTool.pen,
                selected: selected,
                onTap: () => onToolChanged(CanvasTool.pen),
              ),
              const SizedBox(width: 4),
              _ToolBtn(
                icon: Icons.auto_fix_high_rounded,
                label: 'Borrar',
                tool: CanvasTool.eraser,
                selected: selected,
                onTap: () => onToolChanged(CanvasTool.eraser),
              ),
            ],
          ),
        ),
        // Botón limpiar lienzo
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceDark.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.95),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            color: AppColors.error,
            tooltip: 'Limpiar lienzo',
            onPressed: onClearRequested,
          ),
        ),
      ],
    ),
      ],
    );
  }
}

class _ColorPalette extends StatelessWidget {
  static const colors = [
    0xFF1E1E1E, // Negro (Default)
    0xFFEF4444, // Rojo
    0xFFF59E0B, // Naranja
    0xFF10B981, // Verde
    0xFF3B82F6, // Azul
    0xFF8B5CF6, // Morado
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceDark.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: BlocBuilder<CanvasBloc, CanvasState>(
        buildWhen: (a, b) => a.currentColorValue != b.currentColorValue,
        builder: (context, state) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: colors.map((c) {
              final isSelected = state.currentColorValue == c;
              // Ajustar negro en modo oscuro para que se vea
              final displayColor = (c == 0xFF1E1E1E && isDark) ? 0xFFE0E0E0 : c;
              return GestureDetector(
                onTap: () => context.read<CanvasBloc>().add(ChangeColor(c)),
                child: Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Color(displayColor),
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: AppColors.secondary, width: 3)
                        : null,
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final CanvasTool tool;
  final CanvasTool selected;
  final VoidCallback onTap;

  const _ToolBtn({
    required this.icon,
    required this.label,
    required this.tool,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = tool == selected;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: isSelected
                  ? Row(
                      children: [
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Editor de clase UML (modal)
// ─────────────────────────────────────────────────────────────────────────────

class _UmlClassEditor extends StatefulWidget {
  final RecognizedObject obj;
  const _UmlClassEditor({required this.obj});

  @override
  State<_UmlClassEditor> createState() => _UmlClassEditorState();
}

class _UmlClassEditorState extends State<_UmlClassEditor> {
  late final TextEditingController _name;
  late final TextEditingController _attrs;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.obj.umlClassName ?? '');
    _attrs = TextEditingController(
      text: (widget.obj.umlAttributes ?? []).join('\n'),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _attrs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 30,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Título
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.table_chart_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Clase UML', style: AppTextStyles.titleMedium),
                    Text(
                      'Doble-tap en cualquier momento para editar',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Nombre
          TextField(
            controller: _name,
            autofocus: true,
            style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              labelText: 'Nombre de la clase',
              hintText: 'Usuario, Producto, Pedido…',
              prefixIcon: const Icon(Icons.class_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
            ),
          ),
          const SizedBox(height: 12),
          // Atributos
          TextField(
            controller: _attrs,
            maxLines: 6,
            style: AppTextStyles.bodyMedium.copyWith(fontFamily: 'monospace'),
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              labelText: 'Atributos / Métodos',
              hintText: '+ id: int\n+ nombre: String\n- _clave: String\n+ guardar(): void',
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Uno por línea. Prefijos: + público · - privado · # protegido',
            style: AppTextStyles.labelSmall.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 20),
          // Acciones
          Row(
            children: [
              // Borrar objeto
              TextButton.icon(
                onPressed: () {
                  context.read<CanvasBloc>().add(DeleteObject(widget.obj.id));
                  Navigator.pop(context);
                  AppNotification.info(context, 'Clase eliminada');
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Eliminar'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Guardar'),
                onPressed: _save,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _save() {
    final attrs = _attrs.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    context.read<CanvasBloc>().add(UpdateUmlClass(
          id: widget.obj.id,
          name: _name.text.trim(),
          attributes: attrs,
        ));
    Navigator.pop(context);
    AppNotification.success(context, '✓ Clase "${_name.text.trim()}" guardada');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painters
// ─────────────────────────────────────────────────────────────────────────────

class CanvasBackgroundPainter extends CustomPainter {
  final bool isDark;
  CanvasBackgroundPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // Fondo sólido
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..color = isDark ? const Color(0xFF0F1117) : const Color(0xFFF5F7FA),
    );

    // Cuadrícula de puntos (más sutil que líneas completas)
    final dotPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.08)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.5;

    const step = 40.0;
    for (double x = step; x < size.width; x += step) {
      for (double y = step; y < size.height; y += step) {
        canvas.drawPoints(ui.PointMode.points, [Offset(x, y)], dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CanvasBackgroundPainter old) => old.isDark != isDark;
}

class CanvasContentPainter extends CustomPainter {
  final List<Stroke> strokes;
  final Stroke? activeStroke;
  final List<RecognizedObject> objects;
  final RecognizedObject? pendingObject;
  final bool isDark;

  CanvasContentPainter({
    required this.strokes,
    required this.activeStroke,
    required this.objects,
    required this.pendingObject,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Trazos confirmados
    for (final s in strokes) {
      _paintStroke(canvas, s);
    }
    // 2. Trazo activo (más vivo)
    if (activeStroke != null) _paintStroke(canvas, activeStroke!);

    // 3. Objetos reconocidos
    for (final obj in objects) {
      _paintObject(canvas, obj);
    }

    // 4. Preview del objeto pendiente (en ámbar, animado externamente)
    if (pendingObject != null) _paintPending(canvas, pendingObject!);
  }

  void _paintStroke(Canvas canvas, Stroke stroke) {
    if (stroke.points.length < 2) {
      if (stroke.points.length == 1) {
        // Punto solitario — dibujar un círculo pequeño
        canvas.drawCircle(
          stroke.points.first.toOffset(),
          stroke.strokeWidth / 2,
          Paint()
            ..color = stroke.toolType == ToolType.eraser
                ? (isDark ? const Color(0xFF0F1117) : const Color(0xFFF5F7FA))
                : (stroke.colorValue == 0xFF1E1E1E && isDark
                    ? Colors.white
                    : Color(stroke.colorValue))
            ..style = PaintingStyle.fill,
        );
      }
      return;
    }

    final paint = Paint()
      ..color = stroke.toolType == ToolType.eraser
          ? (isDark ? const Color(0xFF0F1117) : const Color(0xFFF5F7FA))
          : (stroke.colorValue == 0xFF1E1E1E && isDark
              ? Colors.white
              : Color(stroke.colorValue))
      ..strokeWidth = stroke.toolType == ToolType.eraser ? 24.0 : stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final pts = stroke.points;

    if (pts.length == 2) {
      canvas.drawLine(pts[0].toOffset(), pts[1].toOffset(), paint);
      return;
    }

    // Bézier cúbico suavizado (Catmull-Rom → Bézier)
    final path = Path();
    path.moveTo(pts[0].x, pts[0].y);

    for (int i = 0; i < pts.length - 1; i++) {
      final p0 = (i > 0) ? pts[i - 1].toOffset() : pts[0].toOffset();
      final p1 = pts[i].toOffset();
      final p2 = pts[i + 1].toOffset();
      final p3 = (i + 2 < pts.length) ? pts[i + 2].toOffset() : p2;

      final cp1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
      final cp2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);

      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }

    canvas.drawPath(path, paint);
  }

  void _paintObject(Canvas canvas, RecognizedObject obj) {
    final rawColorValue = obj.properties['colorValue'] as int? ?? AppColors.primary.value;
    final strokeColor = (rawColorValue == 0xFF1E1E1E && isDark)
        ? Colors.white
        : Color(rawColorValue);
    final fillColor = isDark
        ? AppColors.surfaceDark.withValues(alpha: 0.95)
        : Colors.white.withValues(alpha: 0.97);

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final bb = obj.boundingBox;
    const radius = Radius.circular(10);

    switch (obj.type) {
      case RecognizedObjectType.rectangle:
        canvas.drawRRect(RRect.fromRectAndRadius(bb, radius), fillPaint);
        canvas.drawRRect(RRect.fromRectAndRadius(bb, radius), strokePaint);

      case RecognizedObjectType.circle:
        final cx = obj.properties['centerX'] as double;
        final cy = obj.properties['centerY'] as double;
        final rx = obj.properties['radiusX'] as double;
        final ry = obj.properties['radiusY'] as double;
        final rect = Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2);
        canvas.drawOval(rect, fillPaint);
        canvas.drawOval(rect, strokePaint);

      case RecognizedObjectType.diamond:
        final path = Path()
          ..moveTo(bb.center.dx, bb.top)
          ..lineTo(bb.right, bb.center.dy)
          ..lineTo(bb.center.dx, bb.bottom)
          ..lineTo(bb.left, bb.center.dy)
          ..close();
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint..strokeJoin = StrokeJoin.miter);

      case RecognizedObjectType.line:
        final sx = obj.properties['startX'] as double;
        final sy = obj.properties['startY'] as double;
        final ex = obj.properties['endX'] as double;
        final ey = obj.properties['endY'] as double;
        canvas.drawLine(Offset(sx, sy), Offset(ex, ey), strokePaint..strokeWidth = 2.5);

      case RecognizedObjectType.arrow:
        final sx = obj.properties['startX'] as double;
        final sy = obj.properties['startY'] as double;
        final ex = obj.properties['endX'] as double;
        final ey = obj.properties['endY'] as double;
        final headAtEnd = obj.properties['headAtEnd'] as bool? ?? true;
        
        final start = Offset(sx, sy);
        final end = Offset(ex, ey);
        
        canvas.drawLine(start, end, strokePaint..strokeWidth = 2.5);
        
        const headLen = 18.0;
        const headAngle = 35 * 3.1415926535897932 / 180;
        
        final tip = headAtEnd ? end : start;
        final base = headAtEnd ? start : end;
        
        final dir = tip - base;
        final angle = math.atan2(dir.dy, dir.dx);
        
        final p1 = tip - Offset(math.cos(angle - headAngle) * headLen, math.sin(angle - headAngle) * headLen);
        final p2 = tip - Offset(math.cos(angle + headAngle) * headLen, math.sin(angle + headAngle) * headLen);
        
        final headPath = Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..close();
          
        canvas.drawPath(headPath, Paint()..color = strokeColor..style = PaintingStyle.fill);

      case RecognizedObjectType.umlClass:
        _paintUmlClass(canvas, obj, fillPaint, strokePaint, strokeColor);
    }
  }

  void _paintUmlClass(
    Canvas canvas,
    RecognizedObject obj,
    Paint fillPaint,
    Paint strokePaint,
    Color textColor,
  ) {
    final bb = obj.boundingBox;
    const radius = Radius.circular(10);
    const headerH = 44.0;

    // Fondo
    canvas.drawRRect(RRect.fromRectAndRadius(bb, radius), fillPaint);

    // Franja del header en color primario
    final headerClip = Path()
      ..addRRect(RRect.fromRectAndRadius(bb, radius));
    canvas.save();
    canvas.clipPath(headerClip);
    canvas.drawRect(
      Rect.fromLTWH(bb.left, bb.top, bb.width, headerH),
      Paint()..color = AppColors.primary,
    );
    canvas.restore();

    // Borde exterior
    canvas.drawRRect(RRect.fromRectAndRadius(bb, radius), strokePaint);

    // Línea divisoria
    canvas.drawLine(
      Offset(bb.left, bb.top + headerH),
      Offset(bb.right, bb.top + headerH),
      strokePaint,
    );

    // Nombre de la clase (en blanco sobre fondo primary)
    final name = obj.umlClassName ?? 'Clase';
    _drawText(
      canvas,
      name,
      Offset(bb.left + bb.width / 2, bb.top + headerH / 2 - 8),
      maxWidth: bb.width - 20,
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      centered: true,
    );

    // Atributos
    final attrs = obj.umlAttributes ?? [];
    double y = bb.top + headerH + 10;
    for (final attr in attrs) {
      if (y + 18 > bb.bottom - 4) break;
      _drawText(
        canvas,
        attr,
        Offset(bb.left + 10, y),
        maxWidth: bb.width - 20,
        color: textColor.withValues(alpha: 0.85),
        fontSize: 12,
        fontWeight: FontWeight.w400,
      );
      y += 18;
    }
  }

  void _paintPending(Canvas canvas, RecognizedObject obj) {
    final paint = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    // Línea punteada para el preview
    if (obj.type == RecognizedObjectType.rectangle) {
      final path = Path()
        ..addRRect(
            RRect.fromRectAndRadius(obj.boundingBox, const Radius.circular(10)));
      _drawDashedPath(canvas, path, paint);
    } else if (obj.type == RecognizedObjectType.line) {
      final sx = obj.properties['startX'] as double;
      final sy = obj.properties['startY'] as double;
      final ex = obj.properties['endX'] as double;
      final ey = obj.properties['endY'] as double;
      final path = Path()
        ..moveTo(sx, sy)
        ..lineTo(ex, ey);
      _drawDashedPath(canvas, path, paint);
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashLen = 10.0;
    const gapLen = 6.0;
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double dist = 0;
      bool drawing = true;
      while (dist < metric.length) {
        final len = drawing ? dashLen : gapLen;
        if (drawing) {
          canvas.drawPath(
            metric.extractPath(dist, dist + len),
            paint,
          );
        }
        dist += len;
        drawing = !drawing;
      }
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset pos, {
    required double maxWidth,
    required Color color,
    required double fontSize,
    required FontWeight fontWeight,
    bool centered = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: -0.2,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: centered ? TextAlign.center : TextAlign.left,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);

    final dx = centered ? pos.dx - painter.width / 2 : pos.dx;
    painter.paint(canvas, Offset(dx, pos.dy));
  }

  @override
  bool shouldRepaint(covariant CanvasContentPainter old) {
    return old.strokes != strokes ||
        old.activeStroke != activeStroke ||
        old.objects != objects ||
        old.pendingObject != pendingObject ||
        old.isDark != isDark;
  }
}
