import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:logicpad/features/canvas/domain/entities/recognized_object.dart';
import 'package:logicpad/features/canvas/domain/entities/stroke.dart';
import 'package:logicpad/features/canvas/domain/services/recognition_service.dart';

void main() {
  late RecognitionService service;

  setUp(() {
    service = RecognitionService();
  });

  // Helper para crear un trazo a partir de puntos
  Stroke createStroke(List<Point> points) {
    return Stroke(
      id: 'test_stroke',
      points: points,
      toolType: ToolType.pen,
      strokeWidth: 3.0,
      colorValue: 0xFF000000,
    );
  }

  // Genera puntos para un rectángulo aproximado (aspect ratio > 1 para no confundir con círculo)
  List<Point> generateRectangle() {
    final points = <Point>[];
    int t = 0;
    // Top edge
    for (double x = 10; x <= 150; x += 5) {
      points.add(Point(x: x, y: 10, timestamp: t++));
    }
    // Right edge
    for (double y = 10; y <= 80; y += 5) {
      points.add(Point(x: 150, y: y, timestamp: t++));
    }
    // Bottom edge
    for (double x = 150; x >= 10; x -= 5) {
      points.add(Point(x: x, y: 80, timestamp: t++));
    }
    // Left edge
    for (double y = 80; y >= 10; y -= 5) {
      points.add(Point(x: 10, y: y, timestamp: t++));
    }
    return points;
  }

  // Genera puntos para un círculo aproximado
  List<Point> generateCircle() {
    final points = <Point>[];
    int t = 0;
    const cx = 50.0;
    const cy = 50.0;
    const r = 40.0;
    for (double angle = 0; angle <= 2 * pi; angle += 0.1) {
      // Agregamos un poco de ruido para simular dibujo a mano
      final noiseX = (Random().nextDouble() - 0.5) * 2;
      final noiseY = (Random().nextDouble() - 0.5) * 2;
      points.add(Point(
        x: cx + r * cos(angle) + noiseX,
        y: cy + r * sin(angle) + noiseY,
        timestamp: t++,
      ));
    }
    return points;
  }

  // Genera puntos para una línea recta
  List<Point> generateLine() {
    final points = <Point>[];
    int t = 0;
    for (double x = 10; x <= 150; x += 5) {
      points.add(Point(x: x, y: x * 0.5 + 20, timestamp: t++));
    }
    return points;
  }

  // Genera puntos para un rombo (diamond) con proporciones claras
  List<Point> generateDiamond() {
    final points = <Point>[];
    int t = 0;
    // Top (50, 10) to Right (90, 50) -> width=80, height=80
    for (double d = 0; d <= 1; d += 0.05) {
      points.add(Point(x: 50 + d * 60, y: 10 + d * 30, timestamp: t++)); // Top to Right (110, 40)
    }
    for (double d = 0; d <= 1; d += 0.05) {
      points.add(Point(x: 110 - d * 60, y: 40 + d * 30, timestamp: t++)); // Right to Bottom (50, 70)
    }
    for (double d = 0; d <= 1; d += 0.05) {
      points.add(Point(x: 50 - d * 60, y: 70 - d * 30, timestamp: t++)); // Bottom to Left (-10, 40)
    }
    for (double d = 0; d <= 1; d += 0.05) {
      points.add(Point(x: -10 + d * 60, y: 40 - d * 30, timestamp: t++)); // Left to Top (50, 10)
    }
    return points;
  }

  // Genera puntos para una flecha
  List<Point> generateArrow() {
    final points = <Point>[];
    int t = 0;
    // Cuerpo de la flecha (muchos puntos, >70% del total)
    for (double x = 10; x <= 100; x += 2) {
      points.add(Point(x: x, y: 50, timestamp: t++)); // 45 puntos
    }
    // Punta de la flecha (mitad superior, desvía 25px para cumplir > 5)
    for (double d = 0; d <= 1; d += 0.2) {
      points.add(Point(x: 100 - d * 20, y: 50 - d * 25, timestamp: t++)); // 6 puntos
    }
    // Punta de la flecha (volver al centro y mitad inferior)
    for (double d = 0; d <= 1; d += 0.2) {
      points.add(Point(x: 80 + d * 20, y: 25 + d * 50, timestamp: t++)); // 6 puntos
    }
    return points;
  }

  group('RecognitionService Tests', () {
    test('Should not recognize a stroke with too few points', () {
      final stroke = createStroke([
        const Point(x: 0, y: 0, timestamp: 0),
        const Point(x: 10, y: 10, timestamp: 1),
      ]);
      final result = service.recognizeStroke(stroke);
      expect(result, isNull);
    });

    test('Should recognize a Rectangle', () {
      final stroke = createStroke(generateRectangle());
      final result = service.recognizeStroke(stroke);
      
      expect(result, isNotNull);
      expect(result!.type, equals(RecognizedObjectType.rectangle));
    });

    test('Should recognize a Circle', () {
      final stroke = createStroke(generateCircle());
      final result = service.recognizeStroke(stroke);
      
      expect(result, isNotNull);
      expect(result!.type, equals(RecognizedObjectType.circle));
      expect(result.properties['centerX'], isNotNull);
      expect(result.properties['radiusX'], isNotNull);
    });

    test('Should recognize a Line', () {
      final stroke = createStroke(generateLine());
      final result = service.recognizeStroke(stroke);
      
      expect(result, isNotNull);
      expect(result!.type, equals(RecognizedObjectType.line));
      expect(result.properties['startX'], isNotNull);
      expect(result.properties['endX'], isNotNull);
    });

    test('Should recognize a Diamond', () {
      final stroke = createStroke(generateDiamond());
      final result = service.recognizeStroke(stroke);
      
      expect(result, isNotNull);
      expect(result!.type, equals(RecognizedObjectType.diamond));
    });

    test('Should recognize an Arrow', () {
      final stroke = createStroke(generateArrow());
      final result = service.recognizeStroke(stroke);
      
      expect(result, isNotNull);
      expect(result!.type, equals(RecognizedObjectType.arrow));
      expect(result.properties['headAtEnd'], isNotNull);
    });
  });
}
