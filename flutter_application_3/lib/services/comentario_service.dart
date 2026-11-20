import '../models/comentario_model.dart';
import 'api_client.dart';

class ComentarioService {
  final ApiClient _api = ApiClient.instancia;

  Future<List<ComentarioModel>> obtenerComentarios(int blogId) async {
    final List<dynamic> datos = await _api.get('/blog/$blogId/comentarios');

    return datos
        .map(
          (json) => ComentarioModel.fromJson(
            json as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  /// El autor lo determina el servidor a partir del token de sesión.
  Future<ComentarioModel> agregarComentario(int blogId, String texto) async {
    final datos = await _api.post(
      '/blog/$blogId/comentarios',
      cuerpo: {'comentario': texto.trim()},
    );
    return ComentarioModel.fromJson(datos as Map<String, dynamic>);
  }

  Future<void> eliminarComentario(int comentarioId) async {
    await _api.delete('/comentarios/$comentarioId');
  }
}
