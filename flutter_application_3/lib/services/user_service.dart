import '../models/chat_models.dart';
import '../models/user_model.dart';
import 'api_client.dart';

class UserService {
  final ApiClient _api = ApiClient.instancia;

  /// Sólo administradores.
  Future<List<UserModel>> obtenerUsuarios() async {
    final List<dynamic> datos = await _api.get('/usuarios');

    return datos
        .map(
          (json) => UserModel.fromJson(
            json as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  /// Lista pública de usuarios con su estado en línea (para el chat).
  Future<List<MiembroModel>> obtenerDirectorio() async {
    final List<dynamic> datos = await _api.get('/usuarios/directorio');
    return datos
        .map((json) => MiembroModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Sólo administradores: permite elegir el tipo de usuario.
  Future<UserModel> agregarUsuario(UserModel usuario) async {
    final datos = await _api.post(
      '/usuarios',
      cuerpo: usuario.toJsonCrear(),
    );
    return UserModel.fromJson(datos as Map<String, dynamic>);
  }

  Future<UserModel> actualizarUsuario(UserModel usuario) async {
    final datos = await _api.put(
      '/usuarios/${usuario.id}',
      cuerpo: {
        'nom_usr': usuario.nombre,
        'mail': usuario.correo,
        'dir_usr': usuario.direccion,
        'tip_usu': usuario.tipoUsuario,
      },
    );
    return UserModel.fromJson(datos as Map<String, dynamic>);
  }

  Future<void> cambiarPassword({
    required int usuarioId,
    required String actual,
    required String nueva,
  }) async {
    await _api.put(
      '/usuarios/$usuarioId/password',
      cuerpo: {
        'password_actual': actual,
        'password_nueva': nueva,
      },
    );
  }

  Future<void> eliminarUsuario(int id) async {
    await _api.delete('/usuarios/$id');
  }
}
