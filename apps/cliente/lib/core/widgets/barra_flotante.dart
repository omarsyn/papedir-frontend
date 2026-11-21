import 'package:flutter/material.dart';

/// Barra de navegación inferior flotante, redonda y con sombra suave.
class BarraFlotante extends StatelessWidget {
  const BarraFlotante({
    super.key,
    required this.indice,
    required this.onCambio,
    required this.destinos,
  });

  final int indice;
  final ValueChanged<int> onCambio;
  final List<NavigationDestination> destinos;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: oscuro ? const Color(0xFF1C1F26) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: oscuro ? 0.4 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: esquema.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: NavigationBar(
              selectedIndex: indice,
              onDestinationSelected: onCambio,
              destinations: destinos,
            ),
          ),
        ),
      ),
    );
  }
}
