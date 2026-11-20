import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';
import '../models/chat_models.dart';
import 'api_client.dart';
import 'sesion.dart';

enum EstadoConexion { desconectado, conectando, conectado }

/// Mensajería en tiempo real.
///
/// Mantiene un único WebSocket con el servidor mientras haya sesión,
/// se reconecta solo si la red falla y publica los eventos recibidos
/// en [eventos] para que las pantallas se actualicen.
class ChatService {
  ChatService._();
  static final ChatService instancia = ChatService._();

  final ApiClient _api = ApiClient.instancia;

  final ValueNotifier<EstadoConexion> estado =
      ValueNotifier(EstadoConexion.desconectado);

  /// Ids de los usuarios conectados en este momento.
  final ValueNotifier<Set<int>> enLinea = ValueNotifier(<int>{});

  final StreamController<Map<String, dynamic>> _eventos =
      StreamController.broadcast();
  Stream<Map<String, dynamic>> get eventos => _eventos.stream;

  /// Conversación visible en pantalla: sus mensajes no cuentan como no leídos.
  int? conversacionAbierta;

  WebSocketChannel? _canal;
  StreamSubscription<dynamic>? _suscripcion;
  Timer? _ping;
  Timer? _reintento;
  bool _activo = false;
  int _intentos = 0;
  int _generacion = 0;
  int _contadorTemporal = 0;
  final Map<int, DateTime> _ultimoAvisoEscribiendo = {};

  bool get conectado => estado.value == EstadoConexion.conectado;

  // CONEXIÓN

  void conectar() {
    if (_activo) return;
    _activo = true;
    _intentos = 0;
    _abrir();
  }

  void desconectar() {
    _activo = false;
    _reintento?.cancel();
    _canal?.sink.close();
    _limpiar();
    _generacion++;
    estado.value = EstadoConexion.desconectado;
    enLinea.value = {};
    conversacionAbierta = null;
  }

  /// Fuerza un intento inmediato (por ejemplo, al cambiar de servidor).
  void reconectar() {
    desconectar();
    conectar();
  }

  Future<void> _abrir() async {
    final token = Sesion.instancia.token;
    if (!_activo || token == null) return;

    final generacion = ++_generacion;
    estado.value = EstadoConexion.conectando;

    try {
      final canal = WebSocketChannel.connect(Uri.parse(ApiConfig.wsUrl));
      await canal.ready.timeout(const Duration(seconds: 10));
      if (!_activo || generacion != _generacion) {
        canal.sink.close();
        return;
      }

      _canal = canal;
      _suscripcion = canal.stream.listen(
        _alRecibir,
        onDone: () => _alCerrar(generacion),
        onError: (_) => _alCerrar(generacion),
      );

      // El token viaja en el primer mensaje y no en la URL,
      // para que no quede en los registros del servidor.
      canal.sink.add(jsonEncode({'tipo': 'auth', 'token': token}));

      _ping = Timer.periodic(
        const Duration(seconds: 25),
        (_) => _enviar({'tipo': 'ping'}),
      );
    } catch (_) {
      _alCerrar(generacion);
    }
  }

  void _alRecibir(dynamic datos) {
    final Map<String, dynamic> evento;
    try {
      evento = jsonDecode(datos as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    switch (evento['tipo']) {
      case 'autenticado':
        _intentos = 0;
        estado.value = EstadoConexion.conectado;
        enLinea.value = {
          ...(evento['en_linea'] as List).map((id) => id as int),
        };
      case 'presencia':
        final id = evento['usuario_id'] as int;
        final nuevos = {...enLinea.value};
        if (evento['en_linea'] == true) {
          nuevos.add(id);
        } else {
          nuevos.remove(id);
        }
        enLinea.value = nuevos;
      case 'pong':
        return;
    }

    _eventos.add(evento);
  }

  void _alCerrar(int generacion) {
    // onError y onDone pueden llegar ambos; sólo se atiende el primero.
    if (generacion != _generacion) return;
    _generacion++;

    final codigoCierre = _canal?.closeCode;
    _limpiar();
    estado.value = EstadoConexion.desconectado;
    enLinea.value = {};

    if (!_activo) return;

    // 1008: el servidor rechazó el token (venció o es inválido).
    if (codigoCierre == 1008) {
      _activo = false;
      Sesion.instancia.expirar();
      return;
    }

    // Reintentos con espera creciente: 1, 2, 4, 8, 16, 30, 30... segundos.
    final segundos = min(30, 1 << min(_intentos, 5));
    _intentos++;
    _reintento = Timer(Duration(seconds: segundos), _abrir);
  }

  void _limpiar() {
    _ping?.cancel();
    _ping = null;
    _suscripcion?.cancel();
    _suscripcion = null;
    _canal = null;
  }

  bool _enviar(Map<String, dynamic> datos) {
    final canal = _canal;
    if (!conectado || canal == null) return false;
    canal.sink.add(jsonEncode(datos));
    return true;
  }

  // ACCIONES EN TIEMPO REAL

  String nuevoTempId() =>
      'tmp-${DateTime.now().microsecondsSinceEpoch}-${_contadorTemporal++}';

  /// Envía un mensaje por WebSocket; si no hay conexión usa la API REST.
  /// La confirmación llega como evento 'mensaje' con el mismo [tempId].
  Future<void> enviarMensaje(
    int conversacionId,
    String contenido,
    String tempId,
  ) async {
    final enviado = _enviar({
      'tipo': 'mensaje',
      'conversacion_id': conversacionId,
      'contenido': contenido,
      'temp_id': tempId,
    });
    if (enviado) return;

    final datos = await _api.post(
      '/chats/$conversacionId/mensajes',
      cuerpo: {'contenido': contenido},
    );
    _eventos.add({'tipo': 'mensaje', 'mensaje': datos, 'temp_id': tempId});
  }

  /// Avisa que el usuario está escribiendo (máximo una vez cada 3 s).
  void notificarEscribiendo(int conversacionId) {
    final ahora = DateTime.now();
    final ultimo = _ultimoAvisoEscribiendo[conversacionId];
    if (ultimo != null && ahora.difference(ultimo).inSeconds < 3) return;
    _ultimoAvisoEscribiendo[conversacionId] = ahora;
    _enviar({'tipo': 'escribiendo', 'conversacion_id': conversacionId});
  }

  void marcarLeido(int conversacionId) {
    final enviado = _enviar({
      'tipo': 'leido',
      'conversacion_id': conversacionId,
    });
    if (!enviado) {
      _api.post('/chats/$conversacionId/leido').catchError((_) => null);
    }
  }

  // REST

  Future<List<ConversacionModel>> obtenerConversaciones() async {
    final List<dynamic> datos = await _api.get('/chats');
    return datos
        .map((c) => ConversacionModel.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<ConversacionModel> obtenerConversacion(int id) async {
    final datos = await _api.get('/chats/$id');
    return ConversacionModel.fromJson(datos as Map<String, dynamic>);
  }

  Future<List<MensajeModel>> obtenerMensajes(
    int conversacionId, {
    int? antesDe,
    int limite = 50,
  }) async {
    final List<dynamic> datos = await _api.get(
      '/chats/$conversacionId/mensajes',
      query: {
        'limite': '$limite',
        if (antesDe != null) 'antes_de': '$antesDe',
      },
    );
    return datos
        .map((m) => MensajeModel.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<ConversacionModel> abrirChatDirecto(int usuarioId) async {
    final datos = await _api.post(
      '/chats/directo',
      cuerpo: {'usuario_id': usuarioId},
    );
    return ConversacionModel.fromJson(datos as Map<String, dynamic>);
  }

  Future<ConversacionModel> crearGrupo(String nombre, List<int> miembros) async {
    final datos = await _api.post(
      '/chats/grupo',
      cuerpo: {'nombre': nombre.trim(), 'miembros': miembros},
    );
    return ConversacionModel.fromJson(datos as Map<String, dynamic>);
  }

  Future<ConversacionModel> renombrarGrupo(int id, String nombre) async {
    final datos = await _api.put('/chats/$id', cuerpo: {'nombre': nombre.trim()});
    return ConversacionModel.fromJson(datos as Map<String, dynamic>);
  }

  Future<ConversacionModel> agregarMiembros(int id, List<int> usuarios) async {
    final datos = await _api.post(
      '/chats/$id/miembros',
      cuerpo: {'usuarios': usuarios},
    );
    return ConversacionModel.fromJson(datos as Map<String, dynamic>);
  }

  Future<void> salirDeGrupo(int id) async {
    await _api.delete('/chats/$id/miembros/yo');
  }
}
