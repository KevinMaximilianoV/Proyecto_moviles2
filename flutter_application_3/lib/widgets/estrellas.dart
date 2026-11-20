import 'package:flutter/material.dart';

const Color colorEstrella = Color(0xFFC9A227);

/// Muestra una calificación de 0 a 5 con medias estrellas.
/// Si se indica [onSeleccion], las estrellas se pueden tocar.
class Estrellas extends StatelessWidget {
  final double valor;
  final double tamano;
  final ValueChanged<int>? onSeleccion;

  const Estrellas({
    super.key,
    required this.valor,
    this.tamano = 18,
    this.onSeleccion,
  });

  IconData _icono(int posicion) {
    if (valor >= posicion) return Icons.star_rounded;
    if (valor >= posicion - 0.5) return Icons.star_half_rounded;
    return Icons.star_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final posicion = i + 1;
        final icono = Icon(_icono(posicion), color: colorEstrella, size: tamano);
        if (onSeleccion == null) return icono;
        return Semantics(
          label: '$posicion estrellas',
          button: true,
          child: InkResponse(
            onTap: () => onSeleccion!(posicion),
            radius: tamano * 0.8,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: icono,
            ),
          ),
        );
      }),
    );
  }
}
