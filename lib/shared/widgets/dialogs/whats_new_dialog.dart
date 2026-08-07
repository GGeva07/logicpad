import 'package:flutter/material.dart';

/// Muestra las notas del release como diálogo de "novedades" — se llama una
/// sola vez, la primera vez que se abre la app después de actualizar (ver
/// [AppUpdateService.checkWhatsNew]). Las notas del release en GitHub son
/// exactamente lo que se muestra acá, así que hay que escribirlas para el
/// usuario final (sin jerga técnica), no como changelog de desarrollo.
Future<void> showWhatsNewDialog(BuildContext context, String notes) {
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('Novedades de esta versión'),
      content: SingleChildScrollView(child: Text(notes)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}
