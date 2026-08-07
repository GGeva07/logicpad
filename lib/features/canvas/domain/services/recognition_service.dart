import 'dart:math';
import 'dart:ui';
import '../entities/stroke.dart';
import '../entities/recognized_object.dart';

/// Resultado de intentar reconocer un trazo.
class RecognitionResult {
  final RecognizedObject candidate;
  /// Confianza entre 0.0 y 1.0. Mayor = más seguro.
  final double confidence;
  const RecognitionResult({required this.candidate, required this.confidence});
}

class RecognitionService {
  /// Umbral mínimo de confianza para proponer la conversión al usuario.
  static const double minConfidence = 0.55;

  /// Intenta reconocer un objeto a partir de un trazo (Stroke).
  /// Devuelve el candidato si supera el umbral, o null si no.
  RecognizedObject? recognizeStroke(Stroke stroke) {
    if (stroke.points.length < 8) return null;

    // Calcular bounding box
    final bb = _boundingBox(stroke);
    if (bb.width < 40 || bb.height < 40) return null;

    // Intentar rectángulo primero (tiene prioridad)
    final rectResult = _tryRectangle(stroke, bb);
    if (rectResult != null && rectResult.confidence >= minConfidence) {
      return rectResult.candidate;
    }

    // Intentar línea recta
    final lineResult = _tryLine(stroke, bb);
    if (lineResult != null && lineResult.confidence >= minConfidence) {
      return lineResult.candidate;
    }

    return null;
  }

  RecognitionResult? _tryRectangle(Stroke stroke, Rect bb) {
    final points = stroke.points;
    final n = points.length;

    // ── Señal 1: trazo cerrado ────────────────────────────────────
    final start = points.first.toOffset();
    final end = points.last.toOffset();
    final diagonal = bb.size.longestSide;
    final closureDist = (start - end).distance;
    final closureScore = 1.0 - (closureDist / (diagonal * 0.6)).clamp(0.0, 1.0);

    // ── Señal 2: los puntos se distribuyen cerca de los 4 lados ──
    // Para cada punto calculamos la distancia al borde más cercano del BB.
    // Una figura rectangular real tendrá casi todos los puntos pegados a un borde.
    double totalEdgeDist = 0;
    for (final p in points) {
      final distLeft = (p.x - bb.left).abs();
      final distRight = (p.x - bb.right).abs();
      final distTop = (p.y - bb.top).abs();
      final distBottom = (p.y - bb.bottom).abs();
      totalEdgeDist += [distLeft, distRight, distTop, distBottom].reduce(min);
    }
    final avgEdgeDist = totalEdgeDist / n;
    final avgDim = (bb.width + bb.height) / 2;
    final edgeScore = 1.0 - (avgEdgeDist / (avgDim * 0.25)).clamp(0.0, 1.0);

    // ── Señal 3: relación de aspecto razonable (no muy achatado) ──
    final aspectRatio = bb.width / bb.height;
    final aspectScore = (aspectRatio >= 0.15 && aspectRatio <= 8.0) ? 1.0 : 0.3;

    // ── Señal 4: número de cambios de dirección principal (≈4 esquinas) ──
    final cornerScore = _cornerCountScore(stroke, expectedCorners: 4);

    final confidence = (closureScore * 0.35) +
        (edgeScore * 0.35) +
        (cornerScore * 0.20) +
        (aspectScore * 0.10);

    if (confidence < minConfidence) return null;

    // Inflar ligeramente el BB para que se vea "limpio"
    final cleanBB = bb.inflate(4);

    return RecognitionResult(
      candidate: RecognizedObject(
        id: 'rect_${stroke.id}',
        type: RecognizedObjectType.rectangle,
        sourceStrokeIds: [stroke.id],
        boundingBox: cleanBB,
        properties: const {},
      ),
      confidence: confidence,
    );
  }

  RecognitionResult? _tryLine(Stroke stroke, Rect bb) {
    final points = stroke.points;
    final start = points.first.toOffset();
    final end = points.last.toOffset();
    final lineLength = (end - start).distance;

    if (lineLength < 40) return null;

    // Distancia máxima de los puntos a la línea ideal (start→end)
    double maxDev = 0;
    double sumDev = 0;
    for (final p in points) {
      final d = _distanceToSegment(p.toOffset(), start, end);
      if (d > maxDev) maxDev = d;
      sumDev += d;
    }
    final avgDev = sumDev / points.length;

    // Tolerancia: 3% de la longitud de la línea (máx 14px)
    final tol = min(lineLength * 0.03, 14.0);
    if (maxDev > tol * 2.5 || avgDev > tol) return null;

    final straightness = 1.0 - (maxDev / (lineLength * 0.15)).clamp(0.0, 1.0);
    final confidence = straightness;

    return RecognitionResult(
      candidate: RecognizedObject(
        id: 'line_${stroke.id}',
        type: RecognizedObjectType.line,
        sourceStrokeIds: [stroke.id],
        boundingBox: bb,
        properties: {
          'startX': start.dx,
          'startY': start.dy,
          'endX': end.dx,
          'endY': end.dy,
        },
      ),
      confidence: confidence,
    );
  }

  /// Evalúa cuántos cambios de dirección principal tiene el trazo.
  /// Un rectángulo tiene 4 esquinas; el score es máx cuando hay exactamente
  /// [expectedCorners] (o cerca).
  double _cornerCountScore(Stroke stroke, {required int expectedCorners}) {
    final offsets = stroke.points.map((p) => p.toOffset()).toList();
    if (offsets.length < 6) return 0;

    // Suavizar los offsets con ventana deslizante de 5 puntos
    final smooth = <Offset>[];
    for (int i = 0; i < offsets.length; i++) {
      double sx = 0, sy = 0;
      int count = 0;
      for (int j = max(0, i - 2); j <= min(offsets.length - 1, i + 2); j++) {
        sx += offsets[j].dx;
        sy += offsets[j].dy;
        count++;
      }
      smooth.add(Offset(sx / count, sy / count));
    }

    int corners = 0;
    Offset? prevDir;
    for (int i = 1; i < smooth.length; i++) {
      final dir = smooth[i] - smooth[i - 1];
      if (dir.distance < 2) continue;
      if (prevDir != null) {
        // Ángulo entre la dirección anterior y la actual
        final dot = (prevDir.dx * dir.dx + prevDir.dy * dir.dy) /
            (prevDir.distance * dir.distance + 1e-9);
        final angle = acos(dot.clamp(-1.0, 1.0)) * 180 / pi;
        if (angle > 40) {
          corners++;
          prevDir = dir; // reiniciar dirección desde la esquina
        }
        // Si el cambio no es suficiente, promediar para no reaccionar a ruido
      } else {
        prevDir = dir;
      }
    }

    // Score: 1.0 si corners == expectedCorners, cae suavemente
    final diff = (corners - expectedCorners).abs();
    return max(0.0, 1.0 - diff * 0.3);
  }

  Rect _boundingBox(Stroke stroke) {
    double minX = stroke.points.first.x, maxX = stroke.points.first.x;
    double minY = stroke.points.first.y, maxY = stroke.points.first.y;
    for (final p in stroke.points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final l2 = (b - a).distanceSquared;
    if (l2 == 0) return (p - a).distance;
    final t = ((p - a).dx * (b - a).dx + (p - a).dy * (b - a).dy) / l2;
    final tc = t.clamp(0.0, 1.0);
    final proj = a + (b - a) * tc;
    return (p - proj).distance;
  }
}
