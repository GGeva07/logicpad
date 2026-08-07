import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logicpad/core/di/service_locator.dart';
import 'package:logicpad/core/services/app_update_service.dart';
import 'package:logicpad/shared/theme/app_colors.dart';
import 'package:logicpad/shared/theme/app_text_styles.dart';

class ReleaseNotesScreen extends StatefulWidget {
  const ReleaseNotesScreen({super.key});

  @override
  State<ReleaseNotesScreen> createState() => _ReleaseNotesScreenState();
}

class _ReleaseNotesScreenState extends State<ReleaseNotesScreen> {
  // null = cargando, '' = error/sin conexión, 'x.y.z' = cargado
  ({String version, String notes})? _release;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await sl<AppUpdateService>().fetchLatestRelease();
    if (mounted) setState(() { _release = result; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: Stack(
          children: [
            // Círculos decorativos de fondo
            Positioned(top: -60, right: -80, child: _Circle(260, 0.06)),
            Positioned(top: 80, left: -100, child: _Circle(200, 0.04)),
            Positioned(top: 160, right: 40, child: _Circle(100, 0.07)),

            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white, size: 20),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                            const Spacer(),
                            _VersionBadge(
                              version: _loading
                                  ? '…'
                                  : (_release?.version ?? 'v0.1.0'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: const Icon(Icons.edit_note_rounded,
                              color: Colors.white, size: 32),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Novedades en\nLogicPad',
                          style: AppTextStyles.headlineSmall.copyWith(
                            color: Colors.white,
                            fontSize: 28,
                            height: 1.15,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _loading
                              ? 'Buscando la última release…'
                              : _release != null
                                  ? 'Versión ${_release!.version} — publicada en GitHub Releases.'
                                  : 'Sin conexión — mostrando la descripción de esta versión.',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),

                  // ── Tarjeta de contenido ─────────────────────────────
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.backgroundDark
                            : AppColors.backgroundLight,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(32)),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(32)),
                        child: _loading
                            ? const _LoadingState()
                            : _release != null
                                ? _GitHubNotes(notes: _release!.notes)
                                : const _OfflineNotes(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge de versión
// ─────────────────────────────────────────────────────────────────────────────

class _VersionBadge extends StatelessWidget {
  final String version;
  const _VersionBadge({required this.version});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Text(
        'v$version',
        style: AppTextStyles.labelSmall.copyWith(
          color: Colors.white.withValues(alpha: 0.9),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Estado de carga
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            'Cargando notas de la release…',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notas traídas de GitHub — renderizadas línea a línea con formato básico
// ─────────────────────────────────────────────────────────────────────────────

class _GitHubNotes extends StatelessWidget {
  final String notes;
  const _GitHubNotes({required this.notes});

  @override
  Widget build(BuildContext context) {
    final lines = notes.split('\n');
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      itemCount: lines.length + 1, // +1 para el footer
      itemBuilder: (context, i) {
        if (i == lines.length) return const _Footer();
        final line = lines[i];
        return _MarkdownLine(line: line);
      },
    );
  }
}

/// Renderiza una línea de Markdown con formato básico (H2, H3, bullet, hr, texto).
class _MarkdownLine extends StatelessWidget {
  final String line;
  const _MarkdownLine({required this.line});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    // Línea vacía
    if (line.trim().isEmpty) return const SizedBox(height: 6);

    // Separador ---
    if (RegExp(r'^-{3,}$').hasMatch(line.trim())) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Divider(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      );
    }

    // ## Encabezado H2
    if (line.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                line.substring(3),
                style: AppTextStyles.titleMedium.copyWith(
                  color: onSurface,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ### Encabezado H3 (con emoji generalmente)
    if (line.startsWith('### ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceDark
                : AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.15),
            ),
          ),
          child: Text(
            line.substring(4),
            style: AppTextStyles.titleSmall.copyWith(
              color: onSurface,
              letterSpacing: -0.2,
            ),
          ),
        ),
      );
    }

    // > Quote / nota
    if (line.startsWith('> ')) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: AppColors.secondary, width: 3),
          ),
        ),
        child: _InlineText(
          line.substring(2),
          style: AppTextStyles.bodyMedium.copyWith(
            color: onSurface.withValues(alpha: 0.75),
          ),
        ),
      );
    }

    // - Bullet
    if (line.startsWith('- ')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InlineText(
                line.substring(2),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: onSurface.withValues(alpha: 0.8),
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Texto plano
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: _InlineText(
        line,
        style: AppTextStyles.bodyMedium.copyWith(
          color: onSurface.withValues(alpha: 0.75),
          height: 1.45,
        ),
      ),
    );
  }
}

/// Renderiza inline: **bold** y `code` dentro del texto.
class _InlineText extends StatelessWidget {
  final String text;
  final TextStyle style;
  const _InlineText(this.text, {required this.style});

  @override
  Widget build(BuildContext context) {
    return Text.rich(_parseInline(text, style));
  }

  TextSpan _parseInline(String raw, TextStyle base) {
    final spans = <InlineSpan>[];
    // Procesa **bold** y `code` en orden de aparición
    final pattern = RegExp(r'\*\*(.+?)\*\*|`(.+?)`');
    int cursor = 0;
    for (final match in pattern.allMatches(raw)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: raw.substring(cursor, match.start), style: base));
      }
      if (match.group(1) != null) {
        spans.add(TextSpan(
          text: match.group(1),
          style: base.copyWith(fontWeight: FontWeight.w700),
        ));
      } else if (match.group(2) != null) {
        spans.add(TextSpan(
          text: match.group(2),
          style: base.copyWith(
            fontFamily: 'monospace',
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          ),
        ));
      }
      cursor = match.end;
    }
    if (cursor < raw.length) {
      spans.add(TextSpan(text: raw.substring(cursor), style: base));
    }
    return TextSpan(children: spans);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notas offline (fallback cuando no hay conexión ni releases)
// ─────────────────────────────────────────────────────────────────────────────

class _OfflineNotes extends StatelessWidget {
  const _OfflineNotes();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoBanner(),
          const SizedBox(height: 20),
          _FeatureCard(
            icon: Icons.gesture_rounded,
            iconColor: const Color(0xFF6366F1),
            title: 'Lienzo infinito',
            items: const [
              'Dibujá libremente sin bordes ni límites',
              'Zoom de 20 % a 500 % con pellizco',
              'Soporte nativo de dedo, stylus y S Pen',
            ],
          ),
          const SizedBox(height: 16),
          _FeatureCard(
            icon: Icons.crop_square_rounded,
            iconColor: const Color(0xFF10B981),
            title: 'Reconocimiento de figuras',
            items: const [
              'Detecta rectángulos y líneas rectas dibujados a mano',
              'Sin IA — heurísticas geométricas puras, 100 % offline',
              'Nunca convierte nada sin tu confirmación',
            ],
          ),
          const SizedBox(height: 16),
          _FeatureCard(
            icon: Icons.table_chart_rounded,
            iconColor: AppColors.secondary,
            title: 'Clases UML',
            items: const [
              'Convertí cualquier rectángulo en una clase UML',
              'Editá nombre, atributos y métodos con doble-tap',
              'Prefijos: + público · - privado · # protegido',
            ],
          ),
          const SizedBox(height: 16),
          _FeatureCard(
            icon: Icons.history_rounded,
            iconColor: const Color(0xFFF43F5E),
            title: 'Historial y persistencia',
            items: const [
              'Deshacer y rehacer con hasta 30 pasos',
              'Guardado automático — todo queda tal como lo dejaste',
            ],
          ),
          const SizedBox(height: 8),
          const _Footer(),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sin conexión — conectate a internet para ver las notas actualizadas de la última release.',
              style: AppTextStyles.labelSmall.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<String> items;

  const _FeatureCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title, style: AppTextStyles.titleSmall),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                          color: iconColor, shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      item,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.75),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Footer
// ─────────────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Center(
        child: Text(
          'LogicPad · github.com/GGeva07/logicpad',
          style: AppTextStyles.labelSmall.copyWith(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Círculo decorativo de fondo
// ─────────────────────────────────────────────────────────────────────────────

class _Circle extends StatelessWidget {
  final double size;
  final double opacity;
  const _Circle(this.size, this.opacity);

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      );
}
