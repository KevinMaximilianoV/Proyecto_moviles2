import 'package:flutter/material.dart';
import '../utils/formato.dart';

/// Avatar con las iniciales del usuario y, opcionalmente,
/// un punto verde cuando está en línea.
class AvatarUsuario extends StatelessWidget {
  final String nombre;
  final bool enLinea;
  final bool esGrupo;
  final double radio;

  const AvatarUsuario({
    super.key,
    required this.nombre,
    this.enLinea = false,
    this.esGrupo = false,
    this.radio = 22,
  });

  Color _color() {
    const colores = [
      Color(0xFF2196F3), Color(0xFF7E57C2), Color(0xFF26A69A),
      Color(0xFFEF6C00), Color(0xFFD81B60), Color(0xFF5C6BC0),
    ];
    return colores[nombre.hashCode.abs() % colores.length];
  }

  @override
  Widget build(BuildContext context) {
    final punto = radio * 0.55;
    return SizedBox(
      width: radio * 2,
      height: radio * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: radio,
            backgroundColor: esGrupo ? const Color(0xFF08245C) : _color(),
            foregroundColor: Colors.white,
            child: esGrupo
                ? Icon(Icons.groups, size: radio)
                : Text(
                    iniciales(nombre),
                    style: TextStyle(
                      fontSize: radio * 0.75,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          if (enLinea)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: punto,
                height: punto,
                decoration: BoxDecoration(
                  color: const Color(0xFF2ECC71),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
