import 'dart:ui';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/stroke.dart';
import '../../domain/entities/recognized_object.dart';
import '../../domain/services/recognition_service.dart';
import '../../data/datasources/canvas_local_datasource.dart';
import 'canvas_event.dart';
import 'canvas_state.dart';

class CanvasBloc extends Bloc<CanvasEvent, CanvasState> {
  final CanvasLocalDatasource _datasource;
  final RecognitionService _recognitionService;

  CanvasBloc(this._datasource, this._recognitionService) : super(const CanvasState()) {
    on<LoadCanvas>(_onLoadCanvas);
    on<StartStroke>(_onStartStroke);
    on<UpdateStroke>(_onUpdateStroke);
    on<EndStroke>(_onEndStroke);
    on<ConfirmPendingObject>(_onConfirmPendingObject);
    on<RejectPendingObject>(_onRejectPendingObject);
    on<ToggleTool>(_onToggleTool);
    on<Undo>(_onUndo);
    on<Redo>(_onRedo);
    on<UpdateUmlClass>(_onUpdateUmlClass);
    on<DeleteObject>(_onDeleteObject);
    on<ClearAll>(_onClearAll);
  }

  Future<void> _onLoadCanvas(LoadCanvas event, Emitter<CanvasState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final data = await _datasource.loadCanvas();
      final strokes = data['strokes'] as List<Stroke>;
      final objects = data['objects'] as List<RecognizedObject>;

      final initialSnapshot = CanvasSnapshot(strokes: strokes, objects: objects);
      emit(state.copyWith(
        strokes: strokes,
        objects: objects,
        history: [initialSnapshot],
        historyIndex: 0,
        isLoading: false,
      ));
    } catch (_) {
      emit(state.copyWith(isLoading: false));
    }
  }

  void _onStartStroke(StartStroke event, Emitter<CanvasState> emit) {
    if (state.pendingObject != null) {
      // Si hay un objeto pendiente de confirmar, auto-rechazarlo o confirmarlo?
      // Por simplicidad, rechazar/cancelar para no bloquear el flujo de dibujo
      emit(state.copyWith(pendingObject: () => null));
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final newStroke = Stroke(
      id: id,
      points: [event.point],
      toolType: state.currentTool,
    );
    emit(state.copyWith(activeStroke: () => newStroke));
  }

  void _onUpdateStroke(UpdateStroke event, Emitter<CanvasState> emit) {
    final active = state.activeStroke;
    if (active == null) return;

    final updatedPoints = List<Point>.from(active.points)..add(event.point);
    emit(state.copyWith(
      activeStroke: () => Stroke(
        id: active.id,
        points: updatedPoints,
        toolType: active.toolType,
        strokeWidth: active.strokeWidth,
        colorValue: active.colorValue,
      ),
    ));
  }

  Future<void> _onEndStroke(EndStroke event, Emitter<CanvasState> emit) async {
    final active = state.activeStroke;
    if (active == null) return;

    if (active.toolType == ToolType.eraser) {
      // Lógica de borrado: borrar trazos u objetos que intersecten con el trazo del borrador
      final erasedStrokes = List<Stroke>.from(state.strokes);
      final erasedObjects = List<RecognizedObject>.from(state.objects);
      
      // Bounding box del trazo del borrador
      double minX = active.points.first.x;
      double maxX = active.points.first.x;
      double minY = active.points.first.y;
      double maxY = active.points.first.y;
      for (final p in active.points) {
        if (p.x < minX) minX = p.x;
        if (p.x > maxX) maxX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.y > maxY) maxY = p.y;
      }
      final eraserRect = Rect.fromLTRB(minX, minY, maxX, maxY);

      // Borrar trazos intersectados
      erasedStrokes.removeWhere((s) {
        for (final p in s.points) {
          if (eraserRect.contains(p.toOffset())) return true;
        }
        return false;
      });

      // Borrar objetos de diagramas intersectados
      erasedObjects.removeWhere((o) {
        return eraserRect.overlaps(o.boundingBox);
      });

      emit(state.copyWith(
        strokes: erasedStrokes,
        objects: erasedObjects,
        activeStroke: () => null,
      ));

      _pushToHistory(emit, erasedStrokes, erasedObjects);
      await _datasource.saveCanvas(strokes: erasedStrokes, objects: erasedObjects);
      return;
    }

    // Dibujando con lápiz normal
    final updatedStrokes = List<Stroke>.from(state.strokes)..add(active);
    emit(state.copyWith(
      strokes: updatedStrokes,
      activeStroke: () => null,
    ));

    // Ejecutar heurística geométrica
    final recognized = _recognitionService.recognizeStroke(active);
    if (recognized != null) {
      emit(state.copyWith(pendingObject: () => recognized));
    } else {
      // Guardar en historial y persistir
      _pushToHistory(emit, updatedStrokes, state.objects);
      await _datasource.saveCanvas(strokes: updatedStrokes, objects: state.objects);
    }
  }

  Future<void> _onConfirmPendingObject(ConfirmPendingObject event, Emitter<CanvasState> emit) async {
    final pending = state.pendingObject;
    if (pending == null) return;

    // Eliminar el trazo original que originó la figura para "limpiarla"
    final updatedStrokes = List<Stroke>.from(state.strokes);
    for (final id in pending.sourceStrokeIds) {
      updatedStrokes.removeWhere((s) => s.id == id);
    }

    final updatedObjects = List<RecognizedObject>.from(state.objects)..add(pending);

    emit(state.copyWith(
      strokes: updatedStrokes,
      objects: updatedObjects,
      pendingObject: () => null,
    ));

    _pushToHistory(emit, updatedStrokes, updatedObjects);
    await _datasource.saveCanvas(strokes: updatedStrokes, objects: updatedObjects);
  }

  void _onRejectPendingObject(RejectPendingObject event, Emitter<CanvasState> emit) {
    emit(state.copyWith(pendingObject: () => null));
    // Como el trazo original ya está en state.strokes, simplemente guardamos en historial y storage
    _pushToHistory(emit, state.strokes, state.objects);
    _datasource.saveCanvas(strokes: state.strokes, objects: state.objects);
  }

  void _onToggleTool(ToggleTool event, Emitter<CanvasState> emit) {
    emit(state.copyWith(currentTool: event.toolType));
  }

  Future<void> _onUndo(Undo event, Emitter<CanvasState> emit) async {
    if (!state.canUndo) return;

    final newIndex = state.historyIndex - 1;
    final snapshot = state.history[newIndex];

    emit(state.copyWith(
      strokes: snapshot.strokes,
      objects: snapshot.objects,
      historyIndex: newIndex,
      pendingObject: () => null,
    ));

    await _datasource.saveCanvas(strokes: snapshot.strokes, objects: snapshot.objects);
  }

  Future<void> _onRedo(Redo event, Emitter<CanvasState> emit) async {
    if (!state.canRedo) return;

    final newIndex = state.historyIndex + 1;
    final snapshot = state.history[newIndex];

    emit(state.copyWith(
      strokes: snapshot.strokes,
      objects: snapshot.objects,
      historyIndex: newIndex,
      pendingObject: () => null,
    ));

    await _datasource.saveCanvas(strokes: snapshot.strokes, objects: snapshot.objects);
  }

  Future<void> _onUpdateUmlClass(UpdateUmlClass event, Emitter<CanvasState> emit) async {
    final updatedObjects = state.objects.map((o) {
      if (o.id == event.id) {
        return o.copyWith(
          type: RecognizedObjectType.umlClass,
          properties: {
            'name': event.name,
            'attributes': event.attributes,
          },
        );
      }
      return o;
    }).toList();

    emit(state.copyWith(objects: updatedObjects));
    _pushToHistory(emit, state.strokes, updatedObjects);
    await _datasource.saveCanvas(strokes: state.strokes, objects: updatedObjects);
  }

  Future<void> _onDeleteObject(DeleteObject event, Emitter<CanvasState> emit) async {
    final updatedObjects = List<RecognizedObject>.from(state.objects)
      ..removeWhere((o) => o.id == event.id);

    emit(state.copyWith(objects: updatedObjects));
    _pushToHistory(emit, state.strokes, updatedObjects);
    await _datasource.saveCanvas(strokes: state.strokes, objects: updatedObjects);
  }

  Future<void> _onClearAll(ClearAll event, Emitter<CanvasState> emit) async {
    emit(state.copyWith(
      strokes: [],
      objects: [],
      activeStroke: () => null,
      pendingObject: () => null,
    ));
    _pushToHistory(emit, [], []);
    await _datasource.clearCanvas();
  }

  void _pushToHistory(Emitter<CanvasState> emit, List<Stroke> strokes, List<RecognizedObject> objects) {
    final newSnapshot = CanvasSnapshot(
      strokes: List.from(strokes),
      objects: List.from(objects),
    );

    final updatedHistory = List<CanvasSnapshot>.from(
      state.history.sublist(0, state.historyIndex + 1),
    )..add(newSnapshot);

    // Limitar historial a 30 entradas para no desbordar memoria
    if (updatedHistory.length > 30) {
      updatedHistory.removeAt(0);
    }

    emit(state.copyWith(
      history: updatedHistory,
      historyIndex: updatedHistory.length - 1,
    ));
  }
}
