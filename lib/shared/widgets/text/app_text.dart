import 'package:flutter/material.dart';

/// Headline grande — títulos de pantalla principal.
class AppHeadline extends StatelessWidget {
  const AppHeadline(this.text, {super.key, this.color, this.textAlign});
  final String text;
  final Color? color;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineSmall;
    return Text(text, textAlign: textAlign, style: color != null ? style?.copyWith(color: color) : style);
  }
}

/// Título de sección o card.
class AppTitle extends StatelessWidget {
  const AppTitle(this.text, {super.key, this.color, this.textAlign});
  final String text;
  final Color? color;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    return Text(text, textAlign: textAlign, style: color != null ? style?.copyWith(color: color) : style);
  }
}

/// Subtítulo — debajo de un título, contexto secundario.
class AppSubtitle extends StatelessWidget {
  const AppSubtitle(this.text, {super.key, this.color, this.textAlign});
  final String text;
  final Color? color;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.titleSmall;
    final style = base?.copyWith(fontWeight: FontWeight.w500);
    return Text(text, textAlign: textAlign, style: color != null ? style?.copyWith(color: color) : style);
  }
}

/// Texto de cuerpo / descripción — la unidad de texto más usada en la app.
class AppDescription extends StatelessWidget {
  const AppDescription(
    this.text, {
    super.key,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });
  final String text;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: color != null ? style?.copyWith(color: color) : style,
    );
  }
}

/// Etiqueta chica — badges, metadatos, timestamps.
class AppLabel extends StatelessWidget {
  const AppLabel(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Text(text, style: color != null ? style?.copyWith(color: color) : style);
  }
}
