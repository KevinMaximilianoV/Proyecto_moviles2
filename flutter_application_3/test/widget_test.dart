import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_3/config/api_config.dart';
import 'package:flutter_application_3/models/chat_models.dart';
import 'package:flutter_application_3/models/post_model.dart';
import 'package:flutter_application_3/services/auth_service.dart';
import 'package:flutter_application_3/utils/formato.dart';

void main() {
  group('AuthService.validarRegistro', () {
    final auth = AuthService();

    String? validar(String nombre, String correo, String pass, String conf) =>
        auth.validarRegistro(
          nombre: nombre,
          correo: correo,
          password: pass,
          confirmarpassword: conf,
        );

    test('acepta datos correctos', () {
      expect(validar('Ana', 'ana@ejemplo.com', 'Password1', 'Password1'), isNull);
    });

    test('rechaza correo inválido', () {
      expect(validar('Ana', 'ana@', 'Password1', 'Password1'), isNotNull);
    });

    test('rechaza contraseña corta', () {
      expect(validar('Ana', 'ana@ejemplo.com', 'corta', 'corta'), isNotNull);
    });

    test('rechaza contraseñas distintas', () {
      expect(validar('Ana', 'ana@ejemplo.com', 'Password1', 'Password2'), isNotNull);
    });
  });

  group('ApiConfig', () {
    test('normaliza la URL del servidor', () {
      expect(ApiConfig.normalizar('192.168.1.50:8000/'), 'http://192.168.1.50:8000');
    });

    test('valida la URL del servidor', () {
      expect(ApiConfig.validar('http://192.168.1.50:8000'), isNull);
      expect(ApiConfig.validar('ftp://servidor'), isNotNull);
    });
  });

  group('Modelos', () {
    test('PostModel interpreta fechas UTC y calificaciones', () {
      final post = PostModel.fromJson({
        'id_blog': 1,
        'titulo': 'Hola',
        'descripcion': null,
        'img': null,
        'tags': 'Flutter, Dart',
        'fecha': '2026-11-17T12:00:00Z',
        'usr_id': 2,
        'autor_nombre': 'Adriana',
        'promedio': 4.5,
        'total_calificaciones': 2,
        'mi_calificacion': null,
        'total_comentarios': 3,
      });
      expect(post.fecha.toUtc(), DateTime.utc(2026, 11, 17, 12));
      expect(post.promedio, 4.5);
      expect(post.listaTags, ['Flutter', 'Dart']);
    });

    test('ConversacionModel identifica al otro miembro', () {
      final conv = ConversacionModel.fromJson({
        'id_conv': 1,
        'nombre': 'Carlos',
        'es_grupo': false,
        'creador_id': 2,
        'fecha': '2026-11-17T12:00:00Z',
        'miembros': [
          {'id_usr': 2, 'nom_usr': 'Adriana', 'en_linea': true},
          {'id_usr': 3, 'nom_usr': 'Carlos', 'en_linea': false},
        ],
        'ultimo_mensaje': null,
        'no_leidos': 0,
      });
      expect(conv.otroMiembro(2)?.nombre, 'Carlos');
    });
  });

  group('Formato', () {
    final ahora = DateTime(2026, 11, 17, 15, 0);

    test('fechas relativas', () {
      expect(formatoRelativo(DateTime(2026, 11, 17, 14, 55), ahora: ahora), 'hace 5 min');
      expect(formatoRelativo(DateTime(2026, 11, 16, 10, 0), ahora: ahora), 'ayer');
      expect(formatoRelativo(DateTime(2026, 1, 3), ahora: ahora), '3 ene 2026');
    });

    test('iniciales', () {
      expect(iniciales('Carlos Pérez'), 'CP');
      expect(iniciales('admin'), 'A');
    });
  });
}
