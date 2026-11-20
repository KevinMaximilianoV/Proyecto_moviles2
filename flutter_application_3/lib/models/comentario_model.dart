class ComentarioModel {
  final int id;
  final String comentario;
  final DateTime fecha;
  final int usuarioId;
  final int blogId;
  final String autorNombre;

  ComentarioModel({
    required this.id,
    required this.comentario,
    required this.fecha,
    required this.usuarioId,
    required this.blogId,
    required this.autorNombre,
  });

  factory ComentarioModel.fromJson(Map<String, dynamic> json) {
    return ComentarioModel(
      id: json['id_com'] as int,
      comentario: json['comentario'] as String,
      fecha: DateTime.parse(json['fecha'] as String).toLocal(),
      usuarioId: json['usr_id'] as int,
      blogId: json['blog_id'] as int,
      autorNombre: json['autor_nombre'] as String,
    );
  }
}
