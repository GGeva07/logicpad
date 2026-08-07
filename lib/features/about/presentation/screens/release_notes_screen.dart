import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logicpad/shared/theme/app_colors.dart';
import 'package:logicpad/shared/theme/app_text_styles.dart';

class ReleaseNotesScreen extends StatelessWidget {
  const ReleaseNotesScreen({super.key});

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
            // ── Fondo decorativo ──────────────────────────────────────
            Positioned(
              top: -60,
              right: -80,
              child: _DecorCircle(size: 260, opacity: 0.06),
            ),
            Positioned(
              top: 80,
              left: -100,
              child: _DecorCircle(size: 200, opacity: 0.04),
            ),
            Positioned(
              top: 160,
              right: 40,
              child: _DecorCircle(size: 100, opacity: 0.07),
            ),

            // ── Contenido ─────────────────────────────────────────────
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back + versión
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                'v0.1.0  •  MVP',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Ícono de la app
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Icon(
                            Icons.edit_note_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
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
                          'Primera versión pública — todo lo que podés hacer hoy.',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),

                  // ── Tarjeta de contenido scrolleable ─────────────────
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ChangeGroup(
                                icon: Icons.gesture_rounded,
                                iconColor: const Color(0xFF6366F1),
                                title: 'Lienzo infinito',
                                items: const [
                                  'Dibujá libremente en un lienzo de tamaño ilimitado — sin bordes, sin límites.',
                                  'Zoom de 20% a 500% con pellizco (pinch-to-zoom), centrado en el punto del gesto.',
                                  'Modo "Mover" para desplazarte sin dibujar.',
                                  'Soporte de dedo, stylus, Apple Pencil y S Pen sin configuración extra.',
                                ],
                              ),
                              const SizedBox(height: 20),
                              _ChangeGroup(
                                icon: Icons.crop_square_rounded,
                                iconColor: const Color(0xFF10B981),
                                title: 'Reconocimiento de figuras',
                                items: const [
                                  'Dibujá un rectángulo a mano — LogicPad lo detecta y te ofrece limpiarlo con un toque.',
                                  'Lo mismo para líneas rectas: traza una línea y se vectoriza automáticamente.',
                                  'El reconocimiento usa heurísticas geométricas: sin IA, 100% offline.',
                                  'Una notificación no intrusiva aparece solo cuando hay una figura candidata — nunca convierte nada sin tu confirmación.',
                                ],
                              ),
                              const SizedBox(height: 20),
                              _ChangeGroup(
                                icon: Icons.table_chart_rounded,
                                iconColor: AppColors.secondary,
                                title: 'Clases UML',
                                items: const [
                                  'Después de limpiar un rectángulo, tocá "Clase" para convertirlo en una clase UML con nombre y atributos.',
                                  'Hacé doble-tap en cualquier clase existente para editarla.',
                                  'Los atributos usan los prefijos estándar: + público, - privado, # protegido.',
                                  'La clase se renderiza con un encabezado y una lista de atributos formateada automáticamente.',
                                ],
                              ),
                              const SizedBox(height: 20),
                              _ChangeGroup(
                                icon: Icons.history_rounded,
                                iconColor: const Color(0xFFF43F5E),
                                title: 'Historial y persistencia',
                                items: const [
                                  'Deshacer y rehacer con hasta 30 pasos de historial.',
                                  'El lienzo se guarda automáticamente cada vez que dibujás o modificás algo.',
                                  'Al cerrar y reabrir la app, todo queda exactamente como lo dejaste.',
                                ],
                              ),
                              const SizedBox(height: 20),
                              _ChangeGroup(
                                icon: Icons.system_update_rounded,
                                iconColor: const Color(0xFF3B82F6),
                                title: 'Actualizaciones automáticas',
                                items: const [
                                  'Al abrir la app, se verifica si hay una nueva versión disponible en GitHub.',
                                  'Si hay una actualización, podés descargarla e instalarla sin salir de la app.',
                                  'Si acabás de actualizar, se muestra una pantalla con las novedades de la versión — exactamente esta.',
                                ],
                              ),
                              const SizedBox(height: 28),

                              // Separador
                              Divider(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 16),

                              // Próximamente
                              _ComingSoonCard(),

                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
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
// Grupo de cambios
// ─────────────────────────────────────────────────────────────────────────────

class _ChangeGroup extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<String> items;

  const _ChangeGroup({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: AppTextStyles.titleSmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map((item) => _BulletItem(text: item, color: iconColor)),
        ],
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  final Color color;
  const _BulletItem({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.75),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Próximamente
// ─────────────────────────────────────────────────────────────────────────────

class _ComingSoonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  AppColors.primary.withValues(alpha: 0.25),
                  AppColors.surfaceDark,
                ]
              : [
                  AppColors.primary.withValues(alpha: 0.04),
                  AppColors.backgroundLight,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rocket_launch_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                'En camino (v0.2)',
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _FutureItem('Reconocimiento de más figuras: óvalo, diamante, flechas.'),
          _FutureItem('Texto escrito a mano convertido a campo editable.'),
          _FutureItem('Exportación: PNG, Mermaid, PlantUML.'),
          _FutureItem('Múltiples lienzos organizados por proyecto.'),
        ],
      ),
    );
  }
}

class _FutureItem extends StatelessWidget {
  final String text;
  const _FutureItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Icon(Icons.hourglass_top_rounded,
                size: 10,
                color: AppColors.primary.withValues(alpha: 0.5)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Decoración de fondo
// ─────────────────────────────────────────────────────────────────────────────

class _DecorCircle extends StatelessWidget {
  final double size;
  final double opacity;
  const _DecorCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}
