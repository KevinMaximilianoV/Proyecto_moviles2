class PostModel {
  final int id;
  final String titulo;
  final String descripcion;
  final String imagen;
  final String tags;
  final DateTime fecha;
  final int usuarioId;
  final String autorNombre;
  final double? promedio;
  final int totalCalificaciones;
  final int? miCalificacion;
  final int totalComentarios;

  const PostModel({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.imagen,
    required this.tags,
    required this.fecha,
    required this.usuarioId,
    required this.autorNombre,
    this.promedio,
    this.totalCalificaciones = 0,
    this.miCalificacion,
    this.totalComentarios = 0,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: (json['id_blog'] as num).toInt(),
      titulo: json['titulo']?.toString() ?? '',
      descripcion: json['descripcion']?.toString() ?? '',
      imagen: json['img']?.toString() ?? '',
      tags: json['tags']?.toString() ?? '',
      fecha: DateTime.parse(json['fecha'] as String).toLocal(),
      usuarioId: (json['usr_id'] as num).toInt(),
      autorNombre: json['autor_nombre']?.toString() ?? '',
      promedio: (json['promedio'] as num?)?.toDouble(),
      totalCalificaciones: (json['total_calificaciones'] as num?)?.toInt() ?? 0,
      miCalificacion: (json['mi_calificacion'] as num?)?.toInt(),
      totalComentarios: (json['total_comentarios'] as num?)?.toInt() ?? 0,
    );
  }

  List<String> get listaTags => tags
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  PostModel conCalificacion(ResumenCalificacion resumen) {
    return PostModel(
      id: id,
      titulo: titulo,
      descripcion: descripcion,
      imagen: imagen,
      tags: tags,
      fecha: fecha,
      usuarioId: usuarioId,
      autorNombre: autorNombre,
      promedio: resumen.promedio,
      totalCalificaciones: resumen.total,
      miCalificacion: resumen.miCalificacion,
      totalComentarios: totalComentarios,
    );
  }
}

class ResumenCalificacion {
  final double? promedio;
  final int total;
  final int? miCalificacion;

  const ResumenCalificacion({
    required this.promedio,
    required this.total,
    required this.miCalificacion,
  });

  factory ResumenCalificacion.fromJson(Map<String, dynamic> json) {
    return ResumenCalificacion(
      promedio: (json['promedio'] as num?)?.toDouble(),
      total: (json['total'] as num).toInt(),
      miCalificacion: (json['mi_calificacion'] as num?)?.toInt(),
    );
  }
}
