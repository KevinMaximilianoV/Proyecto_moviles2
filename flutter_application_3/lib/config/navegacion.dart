import 'package:flutter/material.dart';

/// Permiten navegar y mostrar avisos desde servicios que no tienen
/// un BuildContext (por ejemplo, cuando el servidor rechaza el token).
final GlobalKey<NavigatorState> navegadorGlobal = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> mensajeroGlobal =
    GlobalKey<ScaffoldMessengerState>();

void mostrarAvisoGlobal(String mensaje) {
  mensajeroGlobal.currentState?.showSnackBar(
    SnackBar(content: Text(mensaje)),
  );
}
