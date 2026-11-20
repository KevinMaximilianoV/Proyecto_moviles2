import '../models/user_model.dart';
import 'api_client.dart';
import 'sesion.dart';

class AuthService {
  final ApiClient _api = ApiClient.instancia;

  String? validarLogin({
    required String usuario,
    required String password,
  }) {
    if (usuario.trim().isEmpty || password.isEmpty) {
      return 'Ingresa tu correo y contraseña';
    }
    return null;
  }

  String? validarRegistro({
    required String nombre,
    required String correo,
    required String password,
    required String confirmarpassword,
  }) {
    if (nombre.isEmpty ||
        correo.isEmpty ||
        password.isEmpty ||
        confirmarpassword.isEmpty) {
      return 'Completa todos los campos';
    }

    if (nombre.length < 2) {
      return 'El nombre debe tener al menos 2 caracteres';
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(correo)) {
      return 'Ingresa un correo válido';
    }

    if (password.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }

    if (password != confirmarpassword) {
      return 'Las contraseñas no coinciden';
    }

    return null;
  }

  /// Valida las credenciales en la API y guarda el token de sesión.
  Future<UserModel> autenticar({
    required String correo,
    required String password,
  }) async {
    final datos = await _api.post(
      '/login',
      autenticado: false,
      cuerpo: {
        'mail': correo.trim().toLowerCase(),
        'password': password,
      },
    ) as Map<String, dynamic>;

    final usuario = UserModel.fromJson(
      datos['usuario'] as Map<String, dynamic>,
    );
    await Sesion.instancia.iniciar(
      datos['access_token'] as String,
      usuario,
    );
    return usuario;
  }

  /// Registro público: el servidor siempre crea un usuario regular.
  Future<UserModel> registrar({
    required String nombre,
    required String correo,
    required String password,
  }) async {
    final datos = await _api.post(
      '/auth/registro',
      autenticado: false,
      cuerpo: {
        'nom_usr': nombre.trim(),
        'mail': correo.trim().toLowerCase(),
        'password': password,
      },
    );
    return UserModel.fromJson(datos as Map<String, dynamic>);
  }

  Future<void> cerrarSesion() => Sesion.instancia.cerrar();
}
