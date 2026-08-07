import 'dart:ui';

enum RecognizedObjectType { rectangle, circle, diamond, line, arrow, umlClass, sqlTable, enumObj, interfaceObj, apiEndpoint }

class RecognizedObject {
  final String id;
  final RecognizedObjectType type;
  final List<String> sourceStrokeIds;
  final Rect boundingBox;
  final Map<String, dynamic> properties;

  const RecognizedObject({
    required this.id,
    required this.type,
    required this.sourceStrokeIds,
    required this.boundingBox,
    required this.properties,
  });

  String? get umlClassName => properties['name'] as String?;
  List<String>? get umlAttributes => (properties['attributes'] as List?)?.cast<String>();

  RecognizedObject copyWith({
    String? id,
    RecognizedObjectType? type,
    List<String>? sourceStrokeIds,
    Rect? boundingBox,
    Map<String, dynamic>? properties,
  }) {
    return RecognizedObject(
      id: id ?? this.id,
      type: type ?? this.type,
      sourceStrokeIds: sourceStrokeIds ?? this.sourceStrokeIds,
      boundingBox: boundingBox ?? this.boundingBox,
      properties: properties ?? this.properties,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'sourceStrokeIds': sourceStrokeIds,
        'boundingBox': {
          'left': boundingBox.left,
          'top': boundingBox.top,
          'width': boundingBox.width,
          'height': boundingBox.height,
        },
        'properties': properties,
      };

  factory RecognizedObject.fromJson(Map<String, dynamic> json) {
    final box = json['boundingBox'] as Map<String, dynamic>;
    return RecognizedObject(
      id: json['id'] as String,
      type: RecognizedObjectType.values.firstWhere((e) => e.name == json['type']),
      sourceStrokeIds: (json['sourceStrokeIds'] as List).cast<String>(),
      boundingBox: Rect.fromLTWH(
        (box['left'] as num).toDouble(),
        (box['top'] as num).toDouble(),
        (box['width'] as num).toDouble(),
        (box['height'] as num).toDouble(),
      ),
      properties: json['properties'] as Map<String, dynamic>,
    );
  }
}
