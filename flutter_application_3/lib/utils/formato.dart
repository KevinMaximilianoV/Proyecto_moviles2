const _meses = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

String _dosDigitos(int n) => n.toString().padLeft(2, '0');

/// 14:05
String formatoHora(DateTime fecha) =>
    '${_dosDigitos(fecha.hour)}:${_dosDigitos(fecha.minute)}';

/// 17 nov 2026
String formatoFecha(DateTime fecha) =>
    '${fecha.day} ${_meses[fecha.month - 1]} ${fecha.year}';

/// "hace 5 min", "hace 3 h", "ayer", "17 nov 2026".
String formatoRelativo(DateTime fecha, {DateTime? ahora}) {
  final referencia = ahora ?? DateTime.now();
  final diferencia = referencia.difference(fecha);

  if (diferencia.inMinutes < 1) return 'justo ahora';
  if (diferencia.inMinutes < 60) return 'hace ${diferencia.inMinutes} min';
  if (diferencia.inHours < 24 && referencia.day == fecha.day) {
    return 'hace ${diferencia.inHours} h';
  }
  final ayer = referencia.subtract(const Duration(days: 1));
  if (ayer.year == fecha.year &&
      ayer.month == fecha.month &&
      ayer.day == fecha.day) {
    return 'ayer';
  }
  return formatoFecha(fecha);
}

/// En la lista de chats: hora si es de hoy, si no la fecha corta.
String formatoChat(DateTime fecha, {DateTime? ahora}) {
  final referencia = ahora ?? DateTime.now();
  final mismoDia = referencia.year == fecha.year &&
      referencia.month == fecha.month &&
      referencia.day == fecha.day;
  if (mismoDia) return formatoHora(fecha);
  return '${fecha.day} ${_meses[fecha.month - 1]}';
}

String iniciales(String nombre) {
  final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (partes.isEmpty) return '?';
  return partes.take(2).map((p) => p[0].toUpperCase()).join();
}
