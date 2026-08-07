import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

class _CanvasScreenState extends State<CanvasScreen> {
  final TransformationController _transformationController = TransformationController();
  CanvasTool _selectedTool = CanvasTool.pen;
  
  // Tamaño grande del canvas para simular canvas infinito
  static const double _canvasSize = 10000.0;

  @override
  void initState() {
    super.initState();
    // Centrar la vista inicial del canvas
    final initialTranslation = -(_canvasSize / 2) + 200;
    _transformationController.value = Matrix4.translationValues(initialTranslation, initialTranslation, 0.0);
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CanvasBloc>(
      create: (_) => sl<CanvasBloc>()..add(const LoadCanvas()),
      child: Builder(
        builder: (context) {
          return Scaffold(
            body: Stack(
              children: [
                // El Lienzo Interactivo
                Positioned.fill(
                  child: BlocBuilder<CanvasBloc, CanvasState>(
                    builder: (context, state) {
                      return InteractiveViewer(
                        transformationController: _transformationController,
                        minScale: 0.25,
                        maxScale: 4.0,
                        constrained: false,
                        boundaryMargin: const EdgeInsets.all(1000),
                        panEnabled: _selectedTool == CanvasTool.pan,
                        scaleEnabled: true,
                        child: GestureDetector(
                          onPanStart: _selectedTool != CanvasTool.pan
                              ? (details) => _onPanStart(context, details)
                              : null,
                          onPanUpdate: _selectedTool != CanvasTool.pan
                              ? (details) => _onPanUpdate(context, details)
                              : null,
                          onPanEnd: _selectedTool != CanvasTool.pan
                              ? (details) => _onPanEnd(context, details)
                              : null,
                          child: Container(
                            width: _canvasSize,
                            height: _canvasSize,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.backgroundDark
                                : AppColors.backgroundLight,
                            child: CustomPaint(
                              painter: CanvasGridPainter(
                                isDark: Theme.of(context).brightness == Brightness.dark,
                              ),
                              foregroundPainter: CanvasDrawingPainter(
                                strokes: state.strokes,
                                activeStroke: state.activeStroke,
                                objects: state.objects,
                                pendingObject: state.pendingObject,
                                isDark: Theme.of(context).brightness == Brightness.dark,
                              ),
                              child: Stack(
                                children: state.objects.map((obj) {
                                  return Positioned(
                                    left: obj.boundingBox.left,
                                    top: obj.boundingBox.top,
                                    width: obj.boundingBox.width,
                                    height: obj.boundingBox.height,
                                    child: GestureDetector(
                                      onDoubleTap: () => _editUmlClass(context, obj),
                                      child: Container(
                                        color: Colors.transparent, // Permite capturar clics
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Cabecera superior con título y estado de herramientas
                Positioned(
                  top: 50,
                  left: 20,
                  right: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color?.withValues(alpha: 0.9) ?? AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'LogicPad',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'MVP',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Historial e Info de ayuda
                      Row(
                        children: [
                          BlocBuilder<CanvasBloc, CanvasState>(
                            builder: (context, state) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardTheme.color?.withValues(alpha: 0.9) ?? AppColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.undo_rounded),
                                      onPressed: state.canUndo
                                          ? () => context.read<CanvasBloc>().add(const Undo())
                                          : null,
                                      tooltip: 'Deshacer',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.redo_rounded),
                                      onPressed: state.canRedo
                                          ? () => context.read<CanvasBloc>().add(const Redo())
                                          : null,
                                      tooltip: 'Rehacer',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_sweep_outlined),
                                      color: AppColors.error,
                                      onPressed: () => _confirmClearCanvas(context),
                                      tooltip: 'Limpiar lienzo',
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Notificación / Confirmación de Reconocimiento
                Positioned(
                  top: 120,
                  left: 20,
                  right: 20,
                  child: BlocBuilder<CanvasBloc, CanvasState>(
                    builder: (context, state) {
                      final pending = state.pendingObject;
                      if (pending == null) return const SizedBox.shrink();

                      final name = pending.type == RecognizedObjectType.rectangle
                          ? 'Rectángulo'
                          : 'Línea Recta';

                      return Align(
                        alignment: Alignment.topCenter,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                pending.type == RecognizedObjectType.rectangle
                                    ? Icons.crop_square_rounded
                                    : Icons.linear_scale_rounded,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '¿Limpiar $name?',
                                style: AppTextStyles.titleSmall.copyWith(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.secondary,
                                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  minimumSize: Size.zero,
                                ),
                                onPressed: () {
                                  context.read<CanvasBloc>().add(const ConfirmPendingObject());
                                  AppNotification.success(context, '$name perfeccionado');
                                },
                                child: const Text('Limpiar'),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                ),
                                onPressed: () {
                                  context.read<CanvasBloc>().add(const RejectPendingObject());
                                },
                                child: const Text('Ignorar'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Tutorial de ayuda para el usuario
                Positioned(
                  bottom: 110,
                  left: 20,
                  right: 20,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        _selectedTool == CanvasTool.pen
                            ? 'Dibuja libremente. Haz doble-tap en un rectángulo para convertirlo en clase UML.'
                            : _selectedTool == CanvasTool.eraser
                                ? 'Arrastra para borrar líneas u objetos.'
                                : 'Desplázate por el lienzo con un dedo.',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),

                // Barra de herramientas flotante inferior
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color?.withValues(alpha: 0.95) ?? AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildToolButton(
                            icon: Icons.pan_tool_rounded,
                            label: 'Mover',
                            tool: CanvasTool.pan,
                          ),
                          const SizedBox(width: 8),
                          _buildToolButton(
                            icon: Icons.gesture_rounded,
                            label: 'Lápiz',
                            tool: CanvasTool.pen,
                          ),
                          const SizedBox(width: 8),
                          _buildToolButton(
                            icon: Icons.cleaning_services_rounded,
                            label: 'Borrador',
                            tool: CanvasTool.eraser,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required CanvasTool tool,
  }) {
    final isSelected = _selectedTool == tool;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTool = tool;
        });
        // Si cambiamos a borrador en la UI, le avisamos al bloc
        final bloc = context.read<CanvasBloc>();
        if (tool == CanvasTool.eraser) {
          bloc.add(const ToggleTool(ToolType.eraser));
        } else {
          bloc.add(const ToggleTool(ToolType.pen));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.titleSmall.copyWith(
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Offset _getCanvasOffset(BuildContext context, Offset globalPos) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPos = renderBox.globalToLocal(globalPos);
    return _transformationController.toScene(localPos);
  }

  void _onPanStart(BuildContext context, DragStartDetails details) {
    final offset = _getCanvasOffset(context, details.globalPosition);
    final point = Point(
      x: offset.dx,
      y: offset.dy,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    context.read<CanvasBloc>().add(StartStroke(point));
  }

  void _onPanUpdate(BuildContext context, DragUpdateDetails details) {
    final offset = _getCanvasOffset(context, details.globalPosition);
    final point = Point(
      x: offset.dx,
      y: offset.dy,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    context.read<CanvasBloc>().add(UpdateStroke(point));
  }

  void _onPanEnd(BuildContext context, DragEndDetails details) {
    context.read<CanvasBloc>().add(const EndStroke());
  }

  void _confirmClearCanvas(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Limpiar lienzo?'),
        content: const Text('Esta acción borrará todos tus trazos y diagramas permanentemente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () {
              context.read<CanvasBloc>().add(const ClearAll());
              Navigator.of(dialogContext).pop();
              AppNotification.info(context, 'Lienzo limpiado');
            },
            child: const Text('Borrar Todo'),
          ),
        ],
      ),
    );
  }

  void _editUmlClass(BuildContext context, RecognizedObject obj) {
    final nameController = TextEditingController(text: obj.umlClassName ?? 'MiClase');
    final attributesController = TextEditingController(
      text: (obj.umlAttributes ?? ['+ id: int', '+ name: String']).join('\n'),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ?? AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.class_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Editar Clase UML',
                  style: AppTextStyles.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la clase',
                hintText: 'Ej. Usuario',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: attributesController,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                labelText: 'Atributos (uno por línea)',
                hintText: 'Ej.\n- id: int\n- nombre: String\n+ guardar()',
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    context.read<CanvasBloc>().add(DeleteObject(obj.id));
                    Navigator.of(sheetContext).pop();
                    AppNotification.info(context, 'Clase eliminada');
                  },
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Eliminar'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final attributes = attributesController.text
                        .split('\n')
                        .map((line) => line.trim())
                        .where((line) => line.isNotEmpty)
                        .toList();

                    context.read<CanvasBloc>().add(UpdateUmlClass(
                          id: obj.id,
                          name: nameController.text.trim(),
                          attributes: attributes,
                        ));

                    Navigator.of(sheetContext).pop();
                    AppNotification.success(context, 'Clase UML actualizada');
                  },
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Pintor del fondo con cuadrícula
class CanvasGridPainter extends CustomPainter {
  final bool isDark;

  CanvasGridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03)
      ..strokeWidth = 1.0;

    const double step = 40.0;

    // Líneas verticales
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Líneas horizontales
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Pintor de trazos y objetos vectoriales
class CanvasDrawingPainter extends CustomPainter {
  final List<Stroke> strokes;
  final Stroke? activeStroke;
  final List<RecognizedObject> objects;
  final RecognizedObject? pendingObject;
  final bool isDark;

  CanvasDrawingPainter({
    required this.strokes,
    required this.activeStroke,
    required this.objects,
    required this.pendingObject,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final penPaint = Paint()
      ..color = isDark ? Colors.white : Colors.black
      ..strokeCap = StrokeCap.round;

    final eraserPaint = Paint()
      ..color = isDark ? Colors.grey.shade800 : Colors.grey.shade300
      ..strokeCap = StrokeCap.round;

    // 1. Pintar trazos confirmados
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, stroke.toolType == ToolType.eraser ? eraserPaint : penPaint);
    }

    // 2. Pintar trazo activo
    final active = activeStroke;
    if (active != null) {
      _drawStroke(canvas, active, active.toolType == ToolType.eraser ? eraserPaint : penPaint);
    }

    // 3. Pintar objetos reconocidos confirmados
    for (final obj in objects) {
      _drawRecognizedObject(canvas, obj, isDark);
    }

    // 4. Pintar objeto pendiente de confirmación en color de acento/feedback
    final pending = pendingObject;
    if (pending != null) {
      final feedbackPaint = Paint()
        ..color = AppColors.secondary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      if (pending.type == RecognizedObjectType.rectangle) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(pending.boundingBox, const Radius.circular(8)),
          feedbackPaint,
        );
      } else if (pending.type == RecognizedObjectType.line) {
        final startX = pending.properties['startX'] as double;
        final startY = pending.properties['startY'] as double;
        final endX = pending.properties['endX'] as double;
        final endY = pending.properties['endY'] as double;
        canvas.drawLine(Offset(startX, startY), Offset(endX, endY), feedbackPaint);
      }
    }
  }

  void _drawStroke(Canvas canvas, Stroke stroke, Paint basePaint) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = stroke.toolType == ToolType.eraser
          ? basePaint.color.withValues(alpha: 0.5)
          : Color(stroke.colorValue)
      ..strokeCap = basePaint.strokeCap
      ..strokeWidth = stroke.toolType == ToolType.eraser ? 20.0 : stroke.strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(stroke.points.first.x, stroke.points.first.y);
    for (int i = 1; i < stroke.points.length; i++) {
      path.lineTo(stroke.points[i].x, stroke.points[i].y);
    }
    canvas.drawPath(path, paint);
  }

  void _drawRecognizedObject(Canvas canvas, RecognizedObject obj, bool isDark) {
    final shapeColor = isDark ? Colors.white : Colors.black;

    final shapePaint = Paint()
      ..color = shapeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final fillPaint = Paint()
      ..color = isDark ? Colors.grey.shade900 : Colors.white
      ..style = PaintingStyle.fill;

    if (obj.type == RecognizedObjectType.rectangle) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(obj.boundingBox, const Radius.circular(8)),
        fillPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(obj.boundingBox, const Radius.circular(8)),
        shapePaint,
      );
    } else if (obj.type == RecognizedObjectType.line) {
      final startX = obj.properties['startX'] as double;
      final startY = obj.properties['startY'] as double;
      final endX = obj.properties['endX'] as double;
      final endY = obj.properties['endY'] as double;
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), shapePaint);
    } else if (obj.type == RecognizedObjectType.umlClass) {
      // Dibujar caja UML
      canvas.drawRRect(
        RRect.fromRectAndRadius(obj.boundingBox, const Radius.circular(8)),
        fillPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(obj.boundingBox, const Radius.circular(8)),
        shapePaint,
      );

      // Dibujar línea divisoria del encabezado
      final headerDividerY = obj.boundingBox.top + 40.0;
      canvas.drawLine(
        Offset(obj.boundingBox.left, headerDividerY),
        Offset(obj.boundingBox.right, headerDividerY),
        shapePaint..strokeWidth = 2.0,
      );

      // Dibujar Texto: Nombre y atributos
      final name = obj.umlClassName ?? 'Clase';
      final attributes = obj.umlAttributes ?? [];

      // Pintar Nombre de Clase
      final nameSpan = TextSpan(
        text: name,
        style: TextStyle(
          color: shapeColor,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      );
      final namePainter = TextPainter(
        text: nameSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      namePainter.layout(maxWidth: obj.boundingBox.width - 16);
      namePainter.paint(
        canvas,
        Offset(
          obj.boundingBox.left + (obj.boundingBox.width - namePainter.width) / 2,
          obj.boundingBox.top + 10.0,
        ),
      );

      // Pintar Atributos
      double currentY = headerDividerY + 10.0;
      for (final attr in attributes) {
        if (currentY + 20 > obj.boundingBox.bottom) break; // Evitar desborde visual

        final attrSpan = TextSpan(
          text: attr,
          style: TextStyle(
            color: shapeColor.withValues(alpha: 0.9),
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        );
        final attrPainter = TextPainter(
          text: attrSpan,
          textDirection: TextDirection.ltr,
        );
        attrPainter.layout(maxWidth: obj.boundingBox.width - 24);
        attrPainter.paint(canvas, Offset(obj.boundingBox.left + 12.0, currentY));
        currentY += 18.0;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CanvasDrawingPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.activeStroke != activeStroke ||
        oldDelegate.objects != objects ||
        oldDelegate.pendingObject != pendingObject ||
        oldDelegate.isDark != isDark;
  }
}
