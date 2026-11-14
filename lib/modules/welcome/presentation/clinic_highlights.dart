import 'package:flutter/material.dart';

import '../../../core/widgets/neu_identity.dart' show neuShadows;
import '../../../vet_ui/vet_theme.dart';

/// Las cinco cosas que resuelve VetDosis en la administracion de una clinica.
///
/// Texto unico para la bienvenida y la lamina de planes: si cambia lo que la
/// app ofrece, cambia aqui y en ningun otro sitio.
const clinicHighlights = <(String, String)>[
  (
    'Cálculos con criterio',
    'Dosis por especie y por kg, fluidoterapia y productos comerciales. '
        'Vademécum con fuentes. Tú validas, la app te ahorra el error.',
  ),
  (
    'Pacientes y hospitalización',
    'Expedientes, agenda, recetas y consentimientos en PDF. Seguimiento de '
        'hospitalizados con recordatorios.',
  ),
  (
    'Inventario y caja',
    'Escáner de códigos y lectura de etiquetas. Ventas, crédito, abonos y '
        'promociones.',
  ),
  (
    'Tu clínica como negocio',
    'Dashboard, planeación financiera en pesos, punto de equilibrio. Equipo '
        'con permisos, asistencia, horarios, mensajes, avisos, tablón de '
        'notas y comisiones.',
  ),
  (
    'IA que asiste, no decide',
    'Borradores, dictado por voz y lectura de etiquetas. Siempre con tu '
        'revisión profesional.',
  ),
];

/// Lista numerada de [clinicHighlights], segun la referencia de Ale: numeral
/// grande en degradado de marca y, cada tres, una tarjeta tenida para que la
/// columna no sea una pila de cajas iguales.
class ClinicHighlights extends StatelessWidget {
  const ClinicHighlights({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < clinicHighlights.length; i++)
        _HighlightCard(
          number: i + 1,
          title: clinicHighlights[i].$1,
          description: clinicHighlights[i].$2,
          tinted: i % 3 == 0,
        ),
    ],
  );
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.number,
    required this.title,
    required this.description,
    required this.tinted,
  });

  final int number;
  final String title;
  final String description;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    // El tinte se mezcla con la superficie del tema en vez de pintarse puro:
    // asi el texto conserva el contraste que ya tenia sobre la tarjeta, en
    // claro y en oscuro.
    final weight = dark ? .22 : .5;
    final radius = BorderRadius.circular(22);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: neuShadows(dark),
          color: tinted ? null : surface,
          gradient: tinted
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(surface, VetColors.brandLilac, weight)!,
                    Color.lerp(surface, VetColors.brandAqua, weight)!,
                  ],
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 18, 16),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: ExcludeSemantics(
                  child: ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (rect) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFA98BEA), Color(0xFF45C8CF)],
                    ).createShader(rect),
                    child: Text(
                      '$number',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: tinted
                            ? theme.colorScheme.onSurface
                            : VetColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
