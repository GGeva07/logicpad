import 'dart:math';
import 'dart:ui';
import '../entities/stroke.dart';
import '../entities/recognized_object.dart';

class RecognitionService {
  /// Intenta reconocer un objeto a partir de un trazo (Stroke).
  /// Devuelve un RecognizedObject candidato, o null si no se detecta nada.
  RecognizedObject? recognizeStroke(Stroke stroke) {
    if (stroke.points.length < 5) return null;

    final points = stroke.points;
    final start = points.first.toOffset();
    final end = points.last.toOffset();

    // 1. Calcular caja de colisión (bounding box)
    double minX = points.first.x;
    double maxX = points.first.x;
    double minY = points.first.y;
    double maxY = points.first.y;

    for (final p in points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    final boundingBox = Rect.fromLTRB(minX, minY, maxX, maxY);

    if (boundingBox.width < 30 || boundingBox.height < 30) {
      return null;
    }

    // 2. Evaluar candidato a RECTÁNGULO
    // Condición A: El trazo es relativamente cerrado.
    final startToEndDist = (start - end).distance;
    final boxDiagonal = sqrt(boundingBox.width * boundingBox.width + boundingBox.height * boundingBox.height);
    final isClosed = startToEndDist < (boxDiagonal * 0.3) || startToEndDist < 60.0;

    if (isClosed) {
      // Condición B: Los puntos están cerca de los bordes del bounding box.
      double totalDistanceToEdges = 0;
      for (final p in points) {
        final distLeft = (p.x - minX).abs();
        final distRight = (p.x - maxX).abs();
        final distTop = (p.y - minY).abs();
        final distBottom = (p.y - maxY).abs();

        final minDist = [distLeft, distRight, distTop, distBottom].reduce(min);
        totalDistanceToEdges += minDist;
      }
      final avgDistToEdges = totalDistanceToEdges / points.length;

      // Umbral configurable: si la distancia promedio a los bordes es < 18% del ancho/alto promedio
      final avgDimension = (boundingBox.width + boundingBox.height) / 2;
      if (avgDistToEdges < avgDimension * 0.20 || avgDistToEdges < 25.0) {
        return RecognizedObject(
          id: 'rect_${stroke.id}',
          type: RecognizedObjectType.rectangle,
          sourceStrokeIds: [stroke.id],
          boundingBox: boundingBox,
          properties: const {},
        );
      }
    }

    // 3. Evaluar candidato a LÍNEA RECTA
    // Calcular distancia de cada punto a la recta que une start y end.
    final lineVector = end - start;
    final lineLength = lineVector.distance;
    if (lineLength > 30) {
      double maxDistToLine = 0;
      for (final p in points) {
        final pt = p.toOffset();
        final dist = _distanceToLineSegment(pt, start, end);
        if (dist > maxDistToLine) {
          maxDistToLine = dist;
        }
      }

      // Si la desviación es muy baja (ej: < 15.0px), es una línea recta.
      if (maxDistToLine < 16.0) {
        return RecognizedObject(
          id: 'line_${stroke.id}',
          type: RecognizedObjectType.line,
          sourceStrokeIds: [stroke.id],
          boundingBox: boundingBox,
          properties: {
            'startX': start.dx,
            'startY': start.dy,
            'endX': end.dx,
            'endY': end.dy,
          },
        );
      }
    }

    return null;
  }

  double _distanceToLineSegment(Offset p, Offset a, Offset b) {
    final l2 = (b - a).distanceSquared;
    if (l2 == 0) return (p - a).distance;
    
    // Proyección
    var t = ((p.dx - a.dx) * (b.dx - a.dx) + (p.dy - a.dy) * (b.dy - a.dy)) / l2;
    t = max(0, min(1, t)); // Limitar al segmento
    
    final projection = Offset(
      a.dx + t * (b.dx - a.dx),
      a.dy + t * (b.dy - a.dy),
    );
    return (p - projection).distance;
  }
}
