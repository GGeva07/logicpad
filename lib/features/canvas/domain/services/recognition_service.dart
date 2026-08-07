import 'dart:math';
import 'dart:ui';
import '../entities/stroke.dart';
import '../entities/recognized_object.dart';

/// Resultado de intentar reconocer un trazo, con puntuación de confianza.
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

    final bb = _boundingBox(stroke);
    if (bb.width < 30 || bb.height < 30) return null;

    // Orden de prioridad: formas cerradas primero, luego abiertas.
    // Círculo antes que rectángulo para evitar que un círculo mal dibujado
    // se clasifique como rectángulo.
    final circle = _tryCircle(stroke, bb);
    if (circle != null && circle.confidence >= minConfidence) {
      return circle.candidate;
    }

    final diamond = _tryDiamond(stroke, bb);
    if (diamond != null && diamond.confidence >= minConfidence) {
      return diamond.candidate;
    }

    final rect = _tryRectangle(stroke, bb);
    if (rect != null && rect.confidence >= minConfidence) {
      return rect.candidate;
    }

    final arrow = _tryArrow(stroke, bb);
    if (arrow != null && arrow.confidence >= minConfidence) {
      return arrow.candidate;
    }

    final line = _tryLine(stroke, bb);
    if (line != null && line.confidence >= minConfidence) {
      return line.candidate;
    }

    return null;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Rectángulo
  // ───────────────────────────────────────────────────────────────────────────

  RecognitionResult? _tryRectangle(Stroke stroke, Rect bb) {
    final points = stroke.points;
    final n = points.length;

    final start = points.first.toOffset();
    final end = points.last.toOffset();
    final diagonal = bb.size.longestSide;
    final closureDist = (start - end).distance;
    final closureScore =
        1.0 - (closureDist / (diagonal * 0.6)).clamp(0.0, 1.0);

    double totalEdgeDist = 0;
    for (final p in points) {
      final dists = [
        (p.x - bb.left).abs(),
        (p.x - bb.right).abs(),
        (p.y - bb.top).abs(),
        (p.y - bb.bottom).abs(),
      ];
      totalEdgeDist += dists.reduce(min);
    }
    final avgEdgeDist = totalEdgeDist / n;
    final avgDim = (bb.width + bb.height) / 2;
    final edgeScore =
        1.0 - (avgEdgeDist / (avgDim * 0.25)).clamp(0.0, 1.0);

    final ar = bb.width / bb.height;
    final aspectScore = (ar >= 0.15 && ar <= 8.0) ? 1.0 : 0.3;

    final cornerScore = _cornerCountScore(stroke, expectedCorners: 4);

    // Penalizar si es muy circular (evitar confusión con círculo)
    final circularityPenalty = _circularityScore(stroke, bb);

    final confidence = (closureScore * 0.30) +
        (edgeScore * 0.35) +
        (cornerScore * 0.25) +
        (aspectScore * 0.10) -
        (circularityPenalty * 0.25);

    if (confidence < minConfidence) return null;

    return RecognitionResult(
      candidate: RecognizedObject(
        id: 'rect_${stroke.id}',
        type: RecognizedObjectType.rectangle,
        sourceStrokeIds: [stroke.id],
        boundingBox: bb.inflate(4),
        properties: {'colorValue': stroke.colorValue},
      ),
      confidence: confidence.clamp(0.0, 1.0),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Círculo
  // ───────────────────────────────────────────────────────────────────────────

  RecognitionResult? _tryCircle(Stroke stroke, Rect bb) {
    final points = stroke.points;
    final n = points.length;

    // Centroide
    double cx = 0, cy = 0;
    for (final p in points) {
      cx += p.x;
      cy += p.y;
    }
    cx /= n;
    cy /= n;

    // Radio estimado = distancia promedio al centroide
    double avgR = 0;
    for (final p in points) {
      avgR += sqrt((p.x - cx) * (p.x - cx) + (p.y - cy) * (p.y - cy));
    }
    avgR /= n;
    if (avgR < 20) return null;

    // Desviación radial: qué tanto varían las distancias respecto al radio promedio
    double radialDev = 0;
    for (final p in points) {
      final d = sqrt((p.x - cx) * (p.x - cx) + (p.y - cy) * (p.y - cy));
      radialDev += (d - avgR).abs();
    }
    radialDev /= n;

    // Señal 1: consistencia radial
    final radialScore =
        1.0 - (radialDev / (avgR * 0.3)).clamp(0.0, 1.0);

    // Señal 2: trazo cerrado
    final start = points.first.toOffset();
    final end = points.last.toOffset();
    final closureDist = (start - end).distance;
    final closureScore =
        1.0 - (closureDist / (avgR * 1.2)).clamp(0.0, 1.0);

    // Señal 3: bounding box aproximadamente cuadrado (círculo ≈ 1:1)
    final ar = bb.width / bb.height;
    final aspectScore = (ar >= 0.6 && ar <= 1.7) ? 1.0 : 0.2;

    // Señal 4: pocas esquinas (círculo no tiene esquinas abruptas)
    final cornerPenalty = _cornerCountScore(stroke, expectedCorners: 0);

    final confidence = (radialScore * 0.40) +
        (closureScore * 0.30) +
        (aspectScore * 0.20) +
        ((1.0 - cornerPenalty) * 0.10);

    if (confidence < minConfidence) return null;

    // Centro y radio para el painter
    final center = Offset(cx, cy);
    final cleanBB = Rect.fromCenter(
      center: center,
      width: bb.width + 8,
      height: bb.height + 8,
    );

    return RecognitionResult(
      candidate: RecognizedObject(
        id: 'circle_${stroke.id}',
        type: RecognizedObjectType.circle,
        sourceStrokeIds: [stroke.id],
        boundingBox: cleanBB,
        properties: {
          'colorValue': stroke.colorValue,
          'centerX': cx,
          'centerY': cy,
          'radiusX': bb.width / 2,
          'radiusY': bb.height / 2,
        },
      ),
      confidence: confidence.clamp(0.0, 1.0),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Rombo (Diamond)
  // ───────────────────────────────────────────────────────────────────────────

  RecognitionResult? _tryDiamond(Stroke stroke, Rect bb) {
    final points = stroke.points;

    // Señal 1: trazo cerrado
    final start = points.first.toOffset();
    final end = points.last.toOffset();
    final diagonal = bb.size.longestSide;
    final closureDist = (start - end).distance;
    final closureScore =
        1.0 - (closureDist / (diagonal * 0.6)).clamp(0.0, 1.0);

    // Un rombo tiene sus puntos cerca de los 4 lados diagonales.
    // Los 4 vértices del rombo ideal son: top, right, bottom, left del BB.
    final top = Offset(bb.center.dx, bb.top);
    final right = Offset(bb.right, bb.center.dy);
    final bottom = Offset(bb.center.dx, bb.bottom);
    final left = Offset(bb.left, bb.center.dy);

    final sides = [
      (top, right),
      (right, bottom),
      (bottom, left),
      (left, top),
    ];

    double totalSideDist = 0;
    for (final p in points) {
      double minDist = double.infinity;
      for (final side in sides) {
        final d = _distanceToSegment(p.toOffset(), side.$1, side.$2);
        if (d < minDist) minDist = d;
      }
      totalSideDist += minDist;
    }
    final avgSideDist = totalSideDist / points.length;
    final avgDim = (bb.width + bb.height) / 2;
    final sideScore =
        1.0 - (avgSideDist / (avgDim * 0.20)).clamp(0.0, 1.0);

    // Señal 3: exactamente 4 esquinas rotadas
    final cornerScore = _cornerCountScore(stroke, expectedCorners: 4);

    // Señal 4: aspect ratio razonable para un rombo (no demasiado alargado)
    final ar = bb.width / bb.height;
    final aspectScore = (ar >= 0.3 && ar <= 3.0) ? 1.0 : 0.2;

    final confidence = (closureScore * 0.25) +
        (sideScore * 0.45) +
        (cornerScore * 0.20) +
        (aspectScore * 0.10);

    if (confidence < minConfidence) return null;

    return RecognitionResult(
      candidate: RecognizedObject(
        id: 'diamond_${stroke.id}',
        type: RecognizedObjectType.diamond,
        sourceStrokeIds: [stroke.id],
        boundingBox: bb.inflate(4),
        properties: {'colorValue': stroke.colorValue},
      ),
      confidence: confidence.clamp(0.0, 1.0),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Línea recta
  // ───────────────────────────────────────────────────────────────────────────

  RecognitionResult? _tryLine(Stroke stroke, Rect bb) {
    final points = stroke.points;
    final start = points.first.toOffset();
    final end = points.last.toOffset();
    final lineLength = (end - start).distance;

    if (lineLength < 40) return null;

    double maxDev = 0;
    double sumDev = 0;
    for (final p in points) {
      final d = _distanceToSegment(p.toOffset(), start, end);
      if (d > maxDev) maxDev = d;
      sumDev += d;
    }
    final avgDev = sumDev / points.length;
    final tol = min(lineLength * 0.03, 14.0);
    if (maxDev > tol * 2.5 || avgDev > tol) return null;

    final straightness =
        1.0 - (maxDev / (lineLength * 0.15)).clamp(0.0, 1.0);

    return RecognitionResult(
      candidate: RecognizedObject(
        id: 'line_${stroke.id}',
        type: RecognizedObjectType.line,
        sourceStrokeIds: [stroke.id],
        boundingBox: bb,
        properties: {
          'colorValue': stroke.colorValue,
          'startX': start.dx,
          'startY': start.dy,
          'endX': end.dx,
          'endY': end.dy,
        },
      ),
      confidence: straightness.clamp(0.0, 1.0),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Flecha (línea + cabeza triangular)
  // ───────────────────────────────────────────────────────────────────────────

  RecognitionResult? _tryArrow(Stroke stroke, Rect bb) {
    final points = stroke.points;
    final n = points.length;
    if (n < 12) return null;

    final start = points.first.toOffset();
    final end = points.last.toOffset();
    final lineLength = (end - start).distance;
    if (lineLength < 50) return null;

    // Dividir el trazo en cuerpo (70%) y candidato a cabeza (último 30%)
    final bodyEnd = (n * 0.70).toInt();
    final bodyPoints = points.sublist(0, bodyEnd);
    final headPoints = points.sublist(bodyEnd);

    // El cuerpo debe ser relativamente recto
    final bodyStart = bodyPoints.first.toOffset();
    final bodyEndPt = bodyPoints.last.toOffset();

    double bodyMaxDev = 0;
    for (final p in bodyPoints) {
      final d = _distanceToSegment(p.toOffset(), bodyStart, bodyEndPt);
      if (d > bodyMaxDev) bodyMaxDev = d;
    }
    final bodyLen = (bodyEndPt - bodyStart).distance;
    final bodyStraightness =
        1.0 - (bodyMaxDev / max(bodyLen * 0.15, 20.0)).clamp(0.0, 1.0);
    if (bodyStraightness < 0.45) return null;

    // La cabeza debe desviarse significativamente de la línea del cuerpo
    double headDev = 0;
    for (final p in headPoints) {
      headDev += _distanceToSegment(p.toOffset(), bodyStart, end);
    }
    headDev /= headPoints.length;
    final headScore = (headDev / 15.0).clamp(0.0, 1.0);

    // La cabeza debe ser corta (no más del 35% de la longitud total)
    final headLen =
        (headPoints.last.toOffset() - headPoints.first.toOffset()).distance;
    final headRatio = headLen / lineLength;
    final headLengthScore = (headRatio < 0.35) ? 1.0 : 0.0;

    final confidence = (bodyStraightness * 0.45) +
        (headScore * 0.35) +
        (headLengthScore * 0.20);

    if (confidence < minConfidence) return null;

    // ¿La punta está en el extremo final o en el inicio?
    // Comparamos la desviación promedio de los primeros puntos vs los últimos
    final tailPoints = points.sublist(0, (n * 0.15).toInt());
    double tailDev = 0;
    for (final p in tailPoints) {
      tailDev += _distanceToSegment(p.toOffset(), start, end);
    }
    tailDev /= tailPoints.length;
    // headAtEnd = true si la punta (mayor desviación) está en el extremo final
    final headAtEnd = headDev >= tailDev;

    return RecognitionResult(
      candidate: RecognizedObject(
        id: 'arrow_${stroke.id}',
        type: RecognizedObjectType.arrow,
        sourceStrokeIds: [stroke.id],
        boundingBox: bb,
        properties: {
          'colorValue': stroke.colorValue,
          'startX': start.dx,
          'startY': start.dy,
          'endX': end.dx,
          'endY': end.dy,
          'headAtEnd': headAtEnd, // si false, la punta está en start
        },
      ),
      confidence: confidence.clamp(0.0, 1.0),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Helpers
  // ───────────────────────────────────────────────────────────────────────────

  /// Mide qué tan "circular" es la distribución de puntos respecto al BB.
  /// Retorna un score alto si es muy circular (penaliza rectángulo).
  double _circularityScore(Stroke stroke, Rect bb) {
    final points = stroke.points;
    double cx = 0, cy = 0;
    for (final p in points) {
      cx += p.x;
      cy += p.y;
    }
    cx /= points.length;
    cy /= points.length;
    double avgR = 0;
    for (final p in points) {
      avgR += sqrt((p.x - cx) * (p.x - cx) + (p.y - cy) * (p.y - cy));
    }
    avgR /= points.length;
    if (avgR < 1) return 0;
    double dev = 0;
    for (final p in points) {
      final d = sqrt((p.x - cx) * (p.x - cx) + (p.y - cy) * (p.y - cy));
      dev += (d - avgR).abs();
    }
    dev /= points.length;
    // Si dev/avgR es pequeño → muy circular
    return 1.0 - (dev / (avgR * 0.3)).clamp(0.0, 1.0);
  }

  /// Evalúa cuántos cambios de dirección principal tiene el trazo.
  double _cornerCountScore(Stroke stroke, {required int expectedCorners}) {
    final offsets = stroke.points.map((p) => p.toOffset()).toList();
    if (offsets.length < 6) return 0;

    // Suavizado con ventana de 5
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
        final dot = (prevDir.dx * dir.dx + prevDir.dy * dir.dy) /
            (prevDir.distance * dir.distance + 1e-9);
        final angle = acos(dot.clamp(-1.0, 1.0)) * 180 / pi;
        if (angle > 40) {
          corners++;
          prevDir = dir;
        }
      } else {
        prevDir = dir;
      }
    }

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
    final t =
        ((p - a).dx * (b - a).dx + (p - a).dy * (b - a).dy) / l2;
    final tc = t.clamp(0.0, 1.0);
    final proj = a + (b - a) * tc;
    return (p - proj).distance;
  }
}
