import '../../domain/entities/stroke.dart';

sealed class CanvasEvent {
  const CanvasEvent();
}

class LoadCanvas extends CanvasEvent {
  const LoadCanvas();
}

class StartStroke extends CanvasEvent {
  final Point point;
  const StartStroke(this.point);
}

class UpdateStroke extends CanvasEvent {
  final Point point;
  const UpdateStroke(this.point);
}

class EndStroke extends CanvasEvent {
  const EndStroke();
}

class ConfirmPendingObject extends CanvasEvent {
  const ConfirmPendingObject();
}

class RejectPendingObject extends CanvasEvent {
  const RejectPendingObject();
}

class ToggleTool extends CanvasEvent {
  final ToolType toolType;
  const ToggleTool(this.toolType);
}

class Undo extends CanvasEvent {
  const Undo();
}

class Redo extends CanvasEvent {
  const Redo();
}

class UpdateUmlClass extends CanvasEvent {
  final String id;
  final String name;
  final List<String> attributes;
  const UpdateUmlClass({
    required this.id,
    required this.name,
    required this.attributes,
  });
}

class DeleteObject extends CanvasEvent {
  final String id;
  const DeleteObject(this.id);
}

class ClearAll extends CanvasEvent {
  const ClearAll();
}
