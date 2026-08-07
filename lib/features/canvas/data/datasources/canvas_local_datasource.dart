import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/stroke.dart';
import '../../domain/entities/recognized_object.dart';

class CanvasLocalDatasource {
  static const _strokesKey = 'logicpad_canvas_strokes';
  static const _objectsKey = 'logicpad_canvas_objects';

  Future<void> saveCanvas({
    required List<Stroke> strokes,
    required List<RecognizedObject> objects,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    final strokesJson = strokes.map((s) => s.toJson()).toList();
    final objectsJson = objects.map((o) => o.toJson()).toList();

    await prefs.setString(_strokesKey, jsonEncode(strokesJson));
    await prefs.setString(_objectsKey, jsonEncode(objectsJson));
  }

  Future<Map<String, dynamic>> loadCanvas() async {
    final prefs = await SharedPreferences.getInstance();
    
    final strokesStr = prefs.getString(_strokesKey);
    final objectsStr = prefs.getString(_objectsKey);

    List<Stroke> strokes = [];
    List<RecognizedObject> objects = [];

    if (strokesStr != null) {
      try {
        final decoded = jsonDecode(strokesStr) as List;
        strokes = decoded.map((s) => Stroke.fromJson(s as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    if (objectsStr != null) {
      try {
        final decoded = jsonDecode(objectsStr) as List;
        objects = decoded.map((o) => RecognizedObject.fromJson(o as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    return {
      'strokes': strokes,
      'objects': objects,
    };
  }

  Future<void> clearCanvas() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_strokesKey);
    await prefs.remove(_objectsKey);
  }
}
