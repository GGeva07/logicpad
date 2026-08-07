import 'dart:ui';

class Point {
  final double x;
  final double y;
  final int timestamp; // t en milisegundos

  const Point({
    required this.x,
    required this.y,
    required this.timestamp,
  });

  Offset toOffset() => Offset(x, y);

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        't': timestamp,
      };

  factory Point.fromJson(Map<String, dynamic> json) => Point(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        timestamp: json['t'] as int,
      );
}

enum ToolType { pen, eraser }

class Stroke {
  final String id;
  final List<Point> points;
  final ToolType toolType;
  final double strokeWidth;
  final int colorValue;

  const Stroke({
    required this.id,
    required this.points,
    this.toolType = ToolType.pen,
    this.strokeWidth = 3.0,
    this.colorValue = 0xFF1E1E1E,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'points': points.map((p) => p.toJson()).toList(),
        'toolType': toolType.name,
        'strokeWidth': strokeWidth,
        'colorValue': colorValue,
      };

  factory Stroke.fromJson(Map<String, dynamic> json) => Stroke(
        id: json['id'] as String,
        points: (json['points'] as List).map((p) => Point.fromJson(p)).toList(),
        toolType: ToolType.values.firstWhere(
          (e) => e.name == json['toolType'],
          orElse: () => ToolType.pen,
        ),
        strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 3.0,
        colorValue: json['colorValue'] as int? ?? 0xFF1E1E1E,
      );
}
