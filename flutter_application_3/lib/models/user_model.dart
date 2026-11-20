class UserModel {
  final int id;
  final String nombre;
  final String correo;
  final String? password;
  final String? direccion;
  final int tipoUsuario;

  UserModel({
    required this.id,
    required this.nombre,
    required this.correo,
    this.password,
    this.direccion,
    this.tipoUsuario = 2,
  });

  bool get esAdmin => tipoUsuario == 1;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id_usr'] as int,
      nombre: json['nom_usr'] as String,
      correo: json['mail'] as String,
      direccion: json['dir_usr'] as String?,
      tipoUsuario: json['tip_usu'] as int? ?? 2,
    );
  }

  /// Datos públicos (sin contraseña) para guardar la sesión.
  Map<String, dynamic> toJson() {
    return {
      'id_usr': id,
      'nom_usr': nombre,
      'mail': correo,
      'dir_usr': direccion,
      'tip_usu': tipoUsuario,
    };
  }

  Map<String, dynamic> toJsonCrear() {
    return {
      'nom_usr': nombre,
      'mail': correo,
      'password': password,
      'dir_usr': direccion,
      'tip_usu': tipoUsuario,
    };
  }
}
