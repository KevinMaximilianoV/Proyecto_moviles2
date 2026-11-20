// Prueba de extremo a extremo: maneja la app real contra la API.
//
// Requisitos: backend levantado con los datos de prueba recién creados
//   docker compose down -v && docker compose up -d --wait
// Ejecutar:
//   flutter test integration_test -d linux
//   (o con --dart-define=API_URL=http://IP:8000 para otro servidor)
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:flutter_application_3/config/api_config.dart';
import 'package:flutter_application_3/main.dart' as app;
import 'package:flutter_application_3/services/sesion.dart';

/// Espera (con tiempo real) a que aparezca un widget.
Future<void> esperar(
  WidgetTester tester,
  Finder finder, {
  Duration limite = const Duration(seconds: 15),
}) async {
  final fin = DateTime.now().add(limite);
  while (DateTime.now().isBefore(fin)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  final visibles = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .whereType<String>()
      .join(' | ');
  throw TestFailure('No apareció: $finder\nEn pantalla: $visibles');
}

Future<void> tocar(WidgetTester tester, Finder finder) async {
  await esperar(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.pump();
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<bool> almacenamientoSeguroDisponible() async {
  try {
    const almacen = FlutterSecureStorage();
    await almacen.write(key: 'prueba', value: '1');
    await almacen.delete(key: 'prueba');
    return true;
  } catch (_) {
    return false;
  }
}

/// Simula a otro usuario conectado desde otro dispositivo.
class OtroUsuario {
  late final String token;
  late final WebSocketChannel ws;
  final List<Map<String, dynamic>> recibidos = [];

  Future<void> conectar(String correo, String password) async {
    final r = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'mail': correo, 'password': password}),
    );
    token = (jsonDecode(r.body) as Map)['access_token'] as String;
    ws = WebSocketChannel.connect(Uri.parse(ApiConfig.wsUrl));
    await ws.ready;
    ws.stream.listen((d) => recibidos.add(jsonDecode(d as String)));
    ws.sink.add(jsonEncode({'tipo': 'auth', 'token': token}));
  }

  void enviar(Map<String, dynamic> datos) => ws.sink.add(jsonEncode(datos));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('flujo completo: login, blog, calificación, comentarios y chat',
      (tester) async {
    await app.main();
    // Por si quedó una sesión de una ejecución anterior.
    await Sesion.instancia.cerrar();
    await tester.pumpWidget(const app.LoginApp());

    // LOGIN
    await esperar(tester, find.text('INICIAR SESIÓN'));
    await tester.enterText(
        find.widgetWithText(TextField, 'Correo electrónico'), 'adriana@ejemplo.com');
    await tester.enterText(
        find.widgetWithText(TextField, 'Contraseña'), 'Usuario123!');
    await tocar(tester, find.text('INGRESAR'));

    // BLOG: publicaciones de otros usuarios...
    await esperar(tester, find.text('Introducción a la inteligencia artificial'));
    expect(find.text('Carlos Pérez'), findsWidgets);

    // ...y las propias en su pestaña.
    await tocar(tester, find.text('Mis publicaciones'));
    await esperar(tester, find.text('Construyendo aplicaciones con Flutter'));
    expect(find.text('Adriana Contreras (tú)'), findsOneWidget);
    expect(find.text('Introducción a la inteligencia artificial'), findsNothing);
    await tocar(tester, find.text('Todas'));

    // DETALLE de una publicación ajena: calificar y comentar
    await tocar(tester, find.text('Introducción a la inteligencia artificial'));
    await esperar(tester, find.text('Comentarios (1)'));
    expect(find.text('Tu calificación:'), findsOneWidget);
    await tocar(tester, find.bySemanticsLabel('5 estrellas'));
    await esperar(tester, find.text('5.0'));
    expect(find.text('1 calificación'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, 'Escribe un comentario...'),
        'Comentario desde la prueba de integración');
    await tocar(tester, find.byTooltip('Enviar comentario'));
    await esperar(tester, find.text('Comentarios (2)'));
    expect(find.text('Comentario desde la prueba de integración'), findsOneWidget);

    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 500));

    // MENSAJES
    await tocar(tester, find.byTooltip('Open navigation menu'));
    await tocar(tester, find.text('Mensajes'));
    await esperar(tester, find.text('Equipo del blog'));
    final otro = OtroUsuario();
    await otro.conectar('carlos@ejemplo.com', 'Usuario123!');

    await tocar(tester, find.text('Carlos Pérez'));
    await esperar(tester, find.text('¡Sí! Me encantó, ya le puse 5 estrellas.'));
    await esperar(tester, find.text('En línea'));

    // Enviar un mensaje: debe confirmarse (ícono ✓) y llegarle a Carlos.
    await tester.enterText(
        find.widgetWithText(TextField, 'Escribe un mensaje...'), 'Hola desde Flutter');
    await tocar(tester, find.byTooltip('Enviar'));
    await esperar(tester, find.text('Hola desde Flutter'));
    await esperar(tester, find.byIcon(Icons.done));
    final finEspera = DateTime.now().add(const Duration(seconds: 5));
    while (!otro.recibidos.any((e) =>
            e['tipo'] == 'mensaje' &&
            (e['mensaje'] as Map)['contenido'] == 'Hola desde Flutter') &&
        DateTime.now().isBefore(finEspera)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      otro.recibidos.any((e) =>
          e['tipo'] == 'mensaje' &&
          (e['mensaje'] as Map)['contenido'] == 'Hola desde Flutter'),
      isTrue,
      reason: 'Carlos debió recibir el mensaje por WebSocket',
    );

    // Carlos escribe y responde: la app lo muestra en tiempo real.
    otro.enviar({'tipo': 'escribiendo', 'conversacion_id': 1});
    await esperar(tester, find.text('escribiendo...'));
    otro.enviar({
      'tipo': 'mensaje',
      'conversacion_id': 1,
      'contenido': 'Respuesta en tiempo real',
    });
    await esperar(tester, find.text('Respuesta en tiempo real'));

    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 500));

    // NUEVO GRUPO
    await tocar(tester, find.byTooltip('Nueva conversación'));
    await tocar(tester, find.text('Nuevo grupo'));
    await esperar(tester, find.widgetWithText(TextField, 'Nombre del grupo'));
    await tester.enterText(
        find.widgetWithText(TextField, 'Nombre del grupo'), 'Grupo de prueba');
    await tocar(tester, find.widgetWithText(CheckboxListTile, 'Carlos Pérez'));
    await tocar(tester, find.text('Administrador'));
    await tocar(tester, find.text('Crear grupo'));
    await esperar(tester, find.text('3 integrantes · 1 en línea'));
    await esperar(tester, find.text('Envía el primer mensaje 👋'));
    // A Carlos le llegó la notificación del grupo nuevo.
    expect(
      otro.recibidos.any((e) =>
          e['tipo'] == 'conversacion' &&
          (e['conversacion'] as Map)['nombre'] == 'Grupo de prueba'),
      isTrue,
    );

    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 500));
    await esperar(tester, find.text('Grupo de prueba'));

    // La sesión quedó en almacenamiento seguro y se puede restaurar
    // (lo que ocurre al volver a abrir la app). En Linux requiere un
    // llavero activo (gnome-keyring o KWallet); sin él la sesión vive
    // sólo en memoria y este paso se omite.
    if (await almacenamientoSeguroDisponible()) {
      expect(await Sesion.instancia.restaurar(), isTrue);
      expect(Sesion.instancia.usuario?.correo, 'adriana@ejemplo.com');
    } else {
      debugPrint('Almacenamiento seguro no disponible: se omite restaurar()');
    }

    // CERRAR SESIÓN
    await tocar(tester, find.byTooltip('Open navigation menu'));
    await tocar(tester, find.text('Cerrar sesión'));
    await esperar(tester, find.text('INICIAR SESIÓN'));
    expect(Sesion.instancia.activa, isFalse);

    await otro.ws.sink.close();
  });
}
