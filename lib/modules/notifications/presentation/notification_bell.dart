import 'package:flutter/material.dart';

import '../../../vet_ui/vet_theme.dart';

/// Campana de la cabecera, con el número de avisos sin leer.
///
/// El contador no se inventa: lo recibe ya calculado. Si es cero no se pinta
/// la marca, para que la cabecera no dé la impresión de tener algo pendiente.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, required this.unread, this.onPressed});

  final int unread;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final hay = unread > 0;
    // Más de 99 se abrevia: el objetivo es avisar, no dar la cifra exacta.
    final texto = unread > 99 ? '+99' : '$unread';
    return IconButton(
      onPressed: onPressed,
      tooltip: hay
          ? 'Notificaciones, $unread sin leer'
          : 'Notificaciones, ninguna sin leer',
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(hay ? Icons.notifications : Icons.notifications_none_rounded),
          if (hay)
            Positioned(
              right: -5,
              top: -4,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: texto.length > 1 ? 5 : 0,
                ),
                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                decoration: BoxDecoration(
                  color: VetColors.violet,
                  borderRadius: BorderRadius.circular(9),
                  // El borde separa la marca del icono cuando ambos quedan
                  // sobre un fondo del mismo tono.
                  border: Border.all(
                    color: Theme.of(context).appBarTheme.backgroundColor ??
                        Theme.of(context).colorScheme.surface,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                // El contador ya se anuncia en el tooltip; repetirlo aquí
                // haría que el lector de pantalla lo leyera dos veces.
                child: ExcludeSemantics(
                  child: Text(
                    texto,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
