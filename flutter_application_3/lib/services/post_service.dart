import '../models/post_model.dart';
import 'api_client.dart';

class PostService {
  final ApiClient _api = ApiClient.instancia;

  /// Todas las publicaciones o, con [autorId], sólo las de ese usuario.
  Future<List<PostModel>> obtenerPosts({int? autorId}) async {
    final List<dynamic> datos = await _api.get(
      '/blog',
      query: autorId != null ? {'autor_id': '$autorId'} : null,
    );

    return datos
        .map(
          (json) => PostModel.fromJson(
            json as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<PostModel> obtenerPost(int id) async {
    final datos = await _api.get('/blog/$id');
    return PostModel.fromJson(datos as Map<String, dynamic>);
  }

  Future<PostModel> agregarPost({
    required String titulo,
    required String descripcion,
    String? imagen,
    String? tags,
  }) async {
    final datos = await _api.post(
      '/blog',
      cuerpo: _cuerpo(titulo, descripcion, imagen, tags),
    );
    return PostModel.fromJson(datos as Map<String, dynamic>);
  }

  Future<PostModel> actualizarPost({
    required int id,
    required String titulo,
    required String descripcion,
    String? imagen,
    String? tags,
  }) async {
    final datos = await _api.put(
      '/blog/$id',
      cuerpo: _cuerpo(titulo, descripcion, imagen, tags),
    );
    return PostModel.fromJson(datos as Map<String, dynamic>);
  }

  Future<void> eliminarPost(int id) async {
    await _api.delete('/blog/$id');
  }

  Future<ResumenCalificacion> calificar(int id, int estrellas) async {
    final datos = await _api.put(
      '/blog/$id/calificacion',
      cuerpo: {'estrellas': estrellas},
    );
    return ResumenCalificacion.fromJson(datos as Map<String, dynamic>);
  }

  Future<ResumenCalificacion> quitarCalificacion(int id) async {
    final datos = await _api.delete('/blog/$id/calificacion');
    return ResumenCalificacion.fromJson(datos as Map<String, dynamic>);
  }

  Map<String, dynamic> _cuerpo(
    String titulo,
    String descripcion,
    String? imagen,
    String? tags,
  ) {
    return {
      'titulo': titulo.trim(),
      'descripcion': descripcion.trim(),
      'img': (imagen ?? '').trim().isEmpty ? null : imagen!.trim(),
      'tags': (tags ?? '').trim().isEmpty ? null : tags!.trim(),
    };
  }
}
