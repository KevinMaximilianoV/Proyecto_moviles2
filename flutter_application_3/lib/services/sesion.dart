import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/navegacion.dart';
import '../models/user_model.dart';
import 'api_client.dart';
import 'chat_service.dart';

/// Sesión del usuario: token JWT y datos del usuario autenticado.
///
/// El token se guarda en almacenamiento seguro del sistema
/// (Keystore en Android, Keychain en iOS, libsecret en Linux),
/// nunca en texto plano.
class Sesion extends ChangeNotifier {
  Sesion._();
  static final Sesion instancia = Sesion._();

  static const _claveToken = 'token';
  static const _claveUsuario = 'usuario';
  final FlutterSecureStorage _almacen = const FlutterSecureStorage();

  String? _token;
  UserModel? _usuario;

  String? get token => _token;
  UserModel? get usuario => _usuario;
  bool get activa => _token != null && _usuario != null;
  bool get esAdmin => _usuario?.tipoUsuario == 1;

  /// Pantalla a la que se llega después de iniciar sesión.
  String get rutaInicio => esAdmin ? '/users' : '/blog';

  Future<void> iniciar(String token, UserModel usuario) async {
    _token = token;
    _usuario = usuario;
    await _escribir(_claveToken, token);
    await _guardarUsuario();
    notifyListeners();
    ChatService.instancia.conectar();
  }

  /// Recupera la sesión guardada y la valida con el servidor.
  Future<bool> restaurar() async {
    _token = await _leer(_claveToken);
    final usuarioGuardado = await _leer(_claveUsuario);
    if (_token == null || usuarioGuardado == null) {
      _token = null;
      return false;
    }

    try {
      _usuario = UserModel.fromJson(
        jsonDecode(usuarioGuardado) as Map<String, dynamic>,
      );
    } catch (_) {
      await cerrar();
      return false;
    }

    // Si el token venció o es inválido, se sabe al expirar el JWT localmente
    // o cuando el servidor responda 401 (ApiClient llama a expirar()).
    if (_tokenVencido(_token!)) {
      await cerrar();
      return false;
    }

    // Se valida con el servidor sin bloquear el arranque de la app;
    // sin red se conserva la sesión y las pantallas muestran el error.
    ApiClient.instancia.get('/auth/yo').then((datos) async {
      _usuario = UserModel.fromJson(datos as Map<String, dynamic>);
      await _guardarUsuario();
      notifyListeners();
    }).catchError((_) {});

    ChatService.instancia.conectar();
    return true;
  }

  /// Lee la fecha de expiración del JWT (sin verificar la firma,
  /// eso lo hace el servidor) para no intentar usar un token vencido.
  bool _tokenVencido(String token) {
    try {
      final partes = token.split('.');
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(partes[1]))),
      ) as Map<String, dynamic>;
      final expira = DateTime.fromMillisecondsSinceEpoch(
        (payload['exp'] as num).toInt() * 1000,
      );
      return DateTime.now().isAfter(expira);
    } catch (_) {
      return true;
    }
  }

  Future<void> actualizarUsuario(UserModel usuario) async {
    _usuario = usuario;
    await _guardarUsuario();
    notifyListeners();
  }

  Future<void> cerrar() async {
    ChatService.instancia.desconectar();
    _token = null;
    _usuario = null;
    await _borrar(_claveToken);
    await _borrar(_claveUsuario);
    notifyListeners();
  }

  /// El servidor rechazó el token: se cierra la sesión y se regresa al login.
  Future<void> expirar() async {
    if (_token == null) return;
    await cerrar();
    navegadorGlobal.currentState?.pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
    mostrarAvisoGlobal('Tu sesión expiró. Inicia sesión de nuevo.');
  }

  Future<void> _guardarUsuario() async {
    final u = _usuario;
    if (u == null) return;
    await _escribir(_claveUsuario, jsonEncode(u.toJson()));
  }

  // El almacenamiento seguro puede no estar disponible (p. ej. Linux sin
  // llavero); en ese caso la sesión dura sólo mientras la app está abierta.
  Future<String?> _leer(String clave) async {
    try {
      return await _almacen.read(key: clave);
    } catch (_) {
      return null;
    }
  }

  Future<void> _escribir(String clave, String valor) async {
    try {
      await _almacen.write(key: clave, value: valor);
    } catch (_) {}
  }

  Future<void> _borrar(String clave) async {
    try {
      await _almacen.delete(key: clave);
    } catch (_) {}
  }
}
