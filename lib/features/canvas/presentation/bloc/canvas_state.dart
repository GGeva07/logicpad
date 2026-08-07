import 'package:flutter/foundation.dart';
import '../../domain/entities/stroke.dart';
import '../../domain/entities/recognized_object.dart';

@immutable
class CanvasSnapshot {
  final List<Stroke> strokes;
  final List<RecognizedObject> objects;

  const CanvasSnapshot({
    required this.strokes,
    required this.objects,
  });

  CanvasSnapshot copy() => CanvasSnapshot(
        strokes: List.from(strokes),
        objects: List.from(objects),
      );
}

@immutable
class CanvasState {
  final List<Stroke> strokes;
  final List<RecognizedObject> objects;
  final ToolType currentTool;
  final int currentColorValue;
  final Stroke? activeStroke;
  final RecognizedObject? pendingObject;
  final bool isLoading;

  // Historial para deshacer/rehacer
  final List<CanvasSnapshot> history;
  final int historyIndex;

  const CanvasState({
    this.strokes = const [],
    this.objects = const [],
    this.currentTool = ToolType.pen,
    this.currentColorValue = 0xFF1E1E1E,
    this.activeStroke,
    this.pendingObject,
    this.isLoading = false,
    this.history = const [],
    this.historyIndex = -1,
  });

  bool get canUndo => historyIndex > 0;
  bool get canRedo => historyIndex < history.length - 1;

  CanvasState copyWith({
    List<Stroke>? strokes,
    List<RecognizedObject>? objects,
    ToolType? currentTool,
    int? currentColorValue,
    Stroke? Function()? activeStroke,
    RecognizedObject? Function()? pendingObject,
    bool? isLoading,
    List<CanvasSnapshot>? history,
    int? historyIndex,
  }) {
    return CanvasState(
      strokes: strokes ?? this.strokes,
      objects: objects ?? this.objects,
      currentTool: currentTool ?? this.currentTool,
      currentColorValue: currentColorValue ?? this.currentColorValue,
      activeStroke: activeStroke != null ? activeStroke() : this.activeStroke,
      pendingObject: pendingObject != null ? pendingObject() : this.pendingObject,
      isLoading: isLoading ?? this.isLoading,
      history: history ?? this.history,
      historyIndex: historyIndex ?? this.historyIndex,
    );
  }
}
