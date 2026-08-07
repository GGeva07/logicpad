// No math needed
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:logicpad/features/canvas/domain/entities/recognized_object.dart';
import 'package:logicpad/features/canvas/domain/entities/stroke.dart';
import 'package:logicpad/features/canvas/domain/services/recognition_service.dart';
import 'package:logicpad/features/canvas/data/datasources/canvas_local_datasource.dart';
import 'package:logicpad/features/canvas/presentation/bloc/canvas_bloc.dart';
import 'package:logicpad/features/canvas/presentation/bloc/canvas_event.dart';
// No canvas_state import

// Fake Datasource
class FakeCanvasLocalDatasource implements CanvasLocalDatasource {
  Map<String, dynamic> data = {'strokes': <Stroke>[], 'objects': <RecognizedObject>[]};

  @override
  Future<Map<String, dynamic>> loadCanvas() async {
    return data;
  }

  @override
  Future<void> saveCanvas({required List<Stroke> strokes, required List<RecognizedObject> objects}) async {
    data['strokes'] = strokes;
    data['objects'] = objects;
  }

  @override
  Future<void> clearCanvas() async {
    data = {'strokes': <Stroke>[], 'objects': <RecognizedObject>[]};
  }
}

// Fake RecognitionService
class FakeRecognitionService extends RecognitionService {
  RecognizedObject? mockResult;

  @override
  RecognizedObject? recognizeStroke(Stroke stroke) {
    return mockResult;
  }
}

void main() {
  late CanvasBloc bloc;
  late FakeCanvasLocalDatasource fakeDatasource;
  late FakeRecognitionService fakeRecognitionService;

  setUp(() {
    fakeDatasource = FakeCanvasLocalDatasource();
    fakeRecognitionService = FakeRecognitionService();
    bloc = CanvasBloc(fakeDatasource, fakeRecognitionService);
  });

  tearDown(() {
    bloc.close();
  });

  group('CanvasBloc', () {
    test('initial state is correct', () {
      expect(bloc.state.strokes, isEmpty);
      expect(bloc.state.objects, isEmpty);
      expect(bloc.state.currentTool, equals(ToolType.pen));
      expect(bloc.state.currentColorValue, equals(0xFF1E1E1E));
    });

    test('LoadCanvas loads data from datasource', () async {
      final stroke = Stroke(id: 's1', points: [const Point(x: 0, y: 0, timestamp: 0)]);
      fakeDatasource.data = {
        'strokes': [stroke],
        'objects': <RecognizedObject>[],
      };

      bloc.add(const LoadCanvas());
      
      // Esperamos que se resuelva el Future interno
      await Future.delayed(const Duration(milliseconds: 50));
      
      expect(bloc.state.strokes.length, 1);
      expect(bloc.state.strokes.first.id, 's1');
      expect(bloc.state.history.length, 1); // snapshot inicial
    });

    test('StartStroke and UpdateStroke create an active stroke', () async {
      bloc.add(const StartStroke(Point(x: 10, y: 10, timestamp: 1)));
      await Future.delayed(Duration.zero); // yield event loop

      expect(bloc.state.activeStroke, isNotNull);
      expect(bloc.state.activeStroke!.points.length, 1);

      bloc.add(const UpdateStroke(Point(x: 20, y: 20, timestamp: 2)));
      await Future.delayed(Duration.zero);

      expect(bloc.state.activeStroke!.points.length, 2);
    });

    test('EndStroke saves stroke and calls recognition', () async {
      bloc.add(const StartStroke(Point(x: 10, y: 10, timestamp: 1)));
      await Future.delayed(Duration.zero);
      bloc.add(const EndStroke());
      await Future.delayed(Duration.zero);

      expect(bloc.state.activeStroke, isNull);
      expect(bloc.state.strokes.length, 1);
      
      // Fake no devuelve nada por defecto
      expect(bloc.state.pendingObject, isNull);
    });

    test('EndStroke sets pending object if recognized', () async {
      fakeRecognitionService.mockResult = RecognizedObject(
        id: 'r1',
        type: RecognizedObjectType.rectangle,
        sourceStrokeIds: ['s1'],
        boundingBox: Rect.fromLTWH(0, 0, 100, 100),
        properties: {},
      );

      bloc.add(const StartStroke(Point(x: 10, y: 10, timestamp: 1)));
      await Future.delayed(Duration.zero);
      bloc.add(const EndStroke());
      await Future.delayed(Duration.zero);

      expect(bloc.state.strokes.length, 1);
      expect(bloc.state.pendingObject, isNotNull);
      expect(bloc.state.pendingObject!.type, RecognizedObjectType.rectangle);
    });

    test('ConfirmPendingObject moves pending to objects and removes stroke', () async {
      fakeRecognitionService.mockResult = RecognizedObject(
        id: 'r1',
        type: RecognizedObjectType.rectangle,
        sourceStrokeIds: ['s1'],
        boundingBox: Rect.fromLTWH(0, 0, 100, 100),
        properties: {},
      );

      bloc.add(const StartStroke(Point(x: 10, y: 10, timestamp: 1)));
      // Forzar que el id del trazo sea s1 para que coincida con el mock (aunque es generado por timestamp, 
      // esto fallará porque Confirm busca el id exacto, vamos a inyectarlo directamente)
      
      // Emitimos EndStroke con el mock configurado.
      await Future.delayed(Duration.zero);
      final generatedId = bloc.state.activeStroke!.id;
      fakeRecognitionService.mockResult = RecognizedObject(
        id: 'r1',
        type: RecognizedObjectType.rectangle,
        sourceStrokeIds: [generatedId],
        boundingBox: Rect.fromLTWH(0, 0, 100, 100),
        properties: {},
      );
      
      bloc.add(const EndStroke());
      await Future.delayed(Duration.zero);

      expect(bloc.state.pendingObject, isNotNull);
      expect(bloc.state.strokes.length, 1);

      bloc.add(const ConfirmPendingObject());
      await Future.delayed(Duration.zero);

      expect(bloc.state.pendingObject, isNull);
      expect(bloc.state.objects.length, 1);
      expect(bloc.state.strokes.length, 0); // El trazo origen se elimina
    });

    test('ChangeColor updates state', () async {
      bloc.add(const ChangeColor(0xFFFF0000));
      await Future.delayed(Duration.zero);
      expect(bloc.state.currentColorValue, 0xFFFF0000);
    });

    test('ToggleTool updates state', () async {
      bloc.add(const ToggleTool(ToolType.eraser));
      await Future.delayed(Duration.zero);
      expect(bloc.state.currentTool, ToolType.eraser);
    });

    test('Undo and Redo flow', () async {
      // 1. Initial empty history entry added on load manually or first action
      // Simulate drawing a stroke
      bloc.add(const StartStroke(Point(x: 10, y: 10, timestamp: 1)));
      await Future.delayed(Duration.zero);
      bloc.add(const EndStroke());
      await Future.delayed(Duration.zero);

      expect(bloc.state.strokes.length, 1);
      expect(bloc.state.history.length, 1); // 1 state inside history
      
      // Simulate drawing another stroke
      bloc.add(const StartStroke(Point(x: 20, y: 20, timestamp: 2)));
      await Future.delayed(Duration.zero);
      bloc.add(const EndStroke());
      await Future.delayed(Duration.zero);

      expect(bloc.state.strokes.length, 2);
      expect(bloc.state.historyIndex, 1);

      // Undo
      bloc.add(const Undo());
      await Future.delayed(Duration.zero);

      expect(bloc.state.strokes.length, 1);
      expect(bloc.state.historyIndex, 0);

      // Redo
      bloc.add(const Redo());
      await Future.delayed(Duration.zero);

      expect(bloc.state.strokes.length, 2);
      expect(bloc.state.historyIndex, 1);
    });
  });
}
