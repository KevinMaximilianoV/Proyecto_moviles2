import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'sesion.dart';

class ApiException implements Exception {
  final String mensaje;
  final int? statusCode;

  const ApiException(this.mensaje, {this.statusCode});

  @override
  String toString() => mensaje;
}

/// Cliente HTTP único de la app: agrega el token de sesión, aplica
/// tiempo límite, decodifica UTF-8 y convierte los errores de la API
/// en mensajes legibles.
class ApiClient {
  ApiClient._();
  static final ApiClient instancia = ApiClient._();

  static const Duration _tiempoLimite = Duration(seconds: 10);
  final http.Client _http = http.Client();

  Future<dynamic> get(String ruta, {Map<String, String>? query}) =>
      _enviar('GET', ruta, query: query);

  Future<dynamic> post(String ruta, {Object? cuerpo, bool autenticado = true}) =>
      _enviar('POST', ruta, cuerpo: cuerpo, autenticado: autenticado);

  Future<dynamic> put(String ruta, {Object? cuerpo}) =>
      _enviar('PUT', ruta, cuerpo: cuerpo);

  Future<dynamic> delete(String ruta) => _enviar('DELETE', ruta);

  Future<dynamic> _enviar(
    String metodo,
    String ruta, {
    Object? cuerpo,
    Map<String, String>? query,
    bool autenticado = true,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$ruta').replace(
      queryParameters: query,
    );
    final token = Sesion.instancia.token;

    final peticion = http.Request(metodo, uri)
      ..headers.addAll({
        'Accept': 'application/json',
        if (cuerpo != null) 'Content-Type': 'application/json; charset=utf-8',
        if (autenticado && token != null) 'Authorization': 'Bearer $token',
      });
    if (cuerpo != null) peticion.body = jsonEncode(cuerpo);

    final http.Response respuesta;
    try {
      respuesta = await http.Response.fromStream(
        await _http.send(peticion).timeout(_tiempoLimite),
      );
    } on TimeoutException {
      throw const ApiException('El servidor no respondió a tiempo');
    } catch (_) {
      throw ApiException(
        'No se pudo conectar con el servidor (${ApiConfig.baseUrl})',
      );
    }

    final datos = _decodificar(respuesta);

    if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) {
      return datos;
    }

    // Token vencido o inválido: se cierra la sesión local.
    if (respuesta.statusCode == 401 && autenticado && token != null) {
      await Sesion.instancia.expirar();
    }

    throw ApiException(
      _mensajeError(datos, respuesta.statusCode),
      statusCode: respuesta.statusCode,
    );
  }

  dynamic _decodificar(http.Response respuesta) {
    if (respuesta.bodyBytes.isEmpty) return null;
    try {
      // FastAPI no indica charset; se decodifica como UTF-8 para
      // conservar acentos y emojis.
      return jsonDecode(utf8.decode(respuesta.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  String _mensajeError(dynamic datos, int codigo) {
    if (datos is Map) {
      final detalle = datos['detail'];
      if (detalle is String) return detalle;
      // Errores de validación de Pydantic: lista de {loc, msg}.
      if (detalle is List && detalle.isNotEmpty && detalle.first is Map) {
        final primero = detalle.first as Map;
        final campo = (primero['loc'] as List?)?.last;
        return 'Dato inválido${campo != null ? ' ($campo)' : ''}: ${primero['msg']}';
      }
    }
    return switch (codigo) {
      403 => 'No tienes permiso para realizar esta acción',
      404 => 'Recurso no encontrado',
      >= 500 => 'Error interno del servidor (HTTP $codigo)',
      _ => 'Error HTTP $codigo',
    };
  }
}
