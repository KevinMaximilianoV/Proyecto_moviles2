/// Usuario visible para los demás (directorio y miembros de chats).
class MiembroModel {
  final int id;
  final String nombre;
  final bool enLinea;

  const MiembroModel({
    required this.id,
    required this.nombre,
    this.enLinea = false,
  });

  factory MiembroModel.fromJson(Map<String, dynamic> json) {
    return MiembroModel(
      id: json['id_usr'] as int,
      nombre: json['nom_usr'] as String,
      enLinea: json['en_linea'] as bool? ?? false,
    );
  }
}

class MensajeModel {
  final int id;
  final int conversacionId;
  final int usuarioId;
  final String autorNombre;
  final String contenido;
  final DateTime fecha;

  /// Identificador temporal de un mensaje enviado que aún no confirma el servidor.
  final String? tempId;

  const MensajeModel({
    required this.id,
    required this.conversacionId,
    required this.usuarioId,
    required this.autorNombre,
    required this.contenido,
    required this.fecha,
    this.tempId,
  });

  bool get pendiente => tempId != null;

  factory MensajeModel.fromJson(Map<String, dynamic> json) {
    return MensajeModel(
      id: json['id_msg'] as int,
      conversacionId: json['conv_id'] as int,
      usuarioId: json['usr_id'] as int,
      autorNombre: json['autor_nombre'] as String,
      contenido: json['contenido'] as String,
      fecha: DateTime.parse(json['fecha'] as String).toLocal(),
    );
  }
}

class ConversacionModel {
  final int id;
  final String nombre;
  final bool esGrupo;
  final int? creadorId;
  final DateTime fecha;
  final List<MiembroModel> miembros;
  final MensajeModel? ultimoMensaje;
  final int noLeidos;

  const ConversacionModel({
    required this.id,
    required this.nombre,
    required this.esGrupo,
    required this.creadorId,
    required this.fecha,
    required this.miembros,
    this.ultimoMensaje,
    this.noLeidos = 0,
  });

  factory ConversacionModel.fromJson(Map<String, dynamic> json) {
    final ultimo = json['ultimo_mensaje'];
    return ConversacionModel(
      id: json['id_conv'] as int,
      nombre: json['nombre'] as String,
      esGrupo: json['es_grupo'] as bool,
      creadorId: json['creador_id'] as int?,
      fecha: DateTime.parse(json['fecha'] as String).toLocal(),
      miembros: (json['miembros'] as List)
          .map((m) => MiembroModel.fromJson(m as Map<String, dynamic>))
          .toList(),
      ultimoMensaje: ultimo is Map<String, dynamic>
          ? MensajeModel.fromJson(ultimo)
          : null,
      noLeidos: json['no_leidos'] as int? ?? 0,
    );
  }

  DateTime get ultimaActividad => ultimoMensaje?.fecha ?? fecha;

  /// En un chat directo, el otro participante.
  MiembroModel? otroMiembro(int miId) {
    if (esGrupo) return null;
    for (final m in miembros) {
      if (m.id != miId) return m;
    }
    return null;
  }

  ConversacionModel copyWith({
    String? nombre,
    List<MiembroModel>? miembros,
    MensajeModel? ultimoMensaje,
    int? noLeidos,
  }) {
    return ConversacionModel(
      id: id,
      nombre: nombre ?? this.nombre,
      esGrupo: esGrupo,
      creadorId: creadorId,
      fecha: fecha,
      miembros: miembros ?? this.miembros,
      ultimoMensaje: ultimoMensaje ?? this.ultimoMensaje,
      noLeidos: noLeidos ?? this.noLeidos,
    );
  }

  /// Copia con el estado en línea de los miembros actualizado.
  ConversacionModel conPresencia(Set<int> enLinea) {
    return copyWith(
      miembros: miembros
          .map((m) => MiembroModel(
                id: m.id,
                nombre: m.nombre,
                enLinea: enLinea.contains(m.id),
              ))
          .toList(),
    );
  }
}
