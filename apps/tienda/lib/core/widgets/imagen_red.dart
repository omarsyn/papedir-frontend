import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Ícono de cada categoría de tienda (las del catálogo; las nuevas usan uno
/// genérico).
IconData iconoCategoria(String codigo) => switch (codigo) {
  'comida' => Icons.lunch_dining_rounded,
  'abarrotes' => Icons.local_grocery_store_rounded,
  'farmacia' => Icons.local_pharmacy_rounded,
  'materiales' => Icons.construction_rounded,
  'bebidas' => Icons.local_drink_rounded,
  'postres' => Icons.icecream_rounded,
  'mascotas' => Icons.pets_rounded,
  _ => Icons.storefront_rounded,
};

/// Imagen de internet con caché. Si no hay foto o falla, muestra un fondo
/// degradado del color de la app con un ícono.
class ImagenRed extends StatelessWidget {
  const ImagenRed({
    super.key,
    required this.url,
    this.icono = Icons.storefront_rounded,
    this.ancho,
    this.alto,
    this.radio = 0,
  });

  final String? url;
  final IconData icono;
  final double? ancho;
  final double? alto;
  final double radio;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final respaldo = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            esquema.primaryContainer,
            esquema.primary.withValues(alpha: 0.35),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          icono,
          size: 40,
          color: esquema.onPrimaryContainer.withValues(alpha: 0.75),
        ),
      ),
    );
    final u = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radio),
      child: SizedBox(
        width: ancho,
        height: alto,
        child: u == null || u.isEmpty
            ? respaldo
            : CachedNetworkImage(
                imageUrl: u,
                fit: BoxFit.cover,
                placeholder: (_, _) => respaldo,
                errorWidget: (_, _, _) => respaldo,
              ),
      ),
    );
  }
}
