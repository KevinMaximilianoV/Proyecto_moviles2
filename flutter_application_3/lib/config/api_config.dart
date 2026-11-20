import 'package:shared_preferences/shared_preferences.dart';

/// Dirección del servidor (laptop o Raspberry Pi).
///
/// Se puede fijar al compilar:
///   flutter run --dart-define=API_URL=http://192.168.1.50:8000
/// o cambiar desde la pantalla de inicio de sesión; en ese caso
/// queda guardada en el dispositivo.
class ApiConfig {
  static const String porDefecto = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const String _clave = 'api_url';
  static String _baseUrl = porDefecto;

  static String get baseUrl => _baseUrl;

  /// Ruta del WebSocket del chat: http -> ws, https -> wss.
  static String get wsUrl {
    final uri = Uri.parse(_baseUrl);
    return uri
        .replace(
          scheme: uri.scheme == 'https' ? 'wss' : 'ws',
          path: '${uri.path}/ws',
        )
        .toString();
  }

  static Future<void> cargar() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      _baseUrl = preferencias.getString(_clave) ?? porDefecto;
    } catch (_) {
      _baseUrl = porDefecto;
    }
  }

  static Future<void> guardar(String url) async {
    _baseUrl = normalizar(url);
    try {
      final preferencias = await SharedPreferences.getInstance();
      await preferencias.setString(_clave, _baseUrl);
    } catch (_) {
      // Sin almacenamiento disponible: se usa sólo durante esta ejecución.
    }
  }

  static String normalizar(String url) {
    var limpia = url.trim();
    if (!limpia.contains('://')) limpia = 'http://$limpia';
    while (limpia.endsWith('/')) {
      limpia = limpia.substring(0, limpia.length - 1);
    }
    return limpia;
  }

  static String? validar(String url) {
    final uri = Uri.tryParse(normalizar(url));
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'Ingresa una dirección válida, p. ej. http://192.168.1.50:8000';
    }
    return null;
  }
}
