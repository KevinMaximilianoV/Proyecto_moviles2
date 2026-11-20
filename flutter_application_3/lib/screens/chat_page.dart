import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../services/sesion.dart';
import '../utils/formato.dart';
import '../widgets/avatar_usuario.dart';
import '../widgets/estado_conexion_banner.dart';
import 'grupo_info_page.dart';

class ChatPage extends StatefulWidget {
  final ConversacionModel conversacion;

  const ChatPage({super.key, required this.conversacion});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const int _tamanoPagina = 50;

  final ChatService _chat = ChatService.instancia;
  final int _miId = Sesion.instancia.usuario!.id;
  final TextEditingController _texto = TextEditingController();
  final ScrollController _scroll = ScrollController();

  late ConversacionModel _conv = widget.conversacion;
  // En orden cronológico (el más reciente al final).
  List<MensajeModel> _mensajes = [];
  bool _cargando = true;
  bool _cargandoAnteriores = false;
  bool _hayMas = true;
  String? _error;

  /// Usuarios escribiendo: id -> (nombre, temporizador para ocultarlo).
  final Map<int, (String, Timer)> _escribiendo = {};
  StreamSubscription<Map<String, dynamic>>? _suscripcion;

  @override
  void initState() {
    super.initState();
    _chat.conversacionAbierta = _conv.id;
    _suscripcion = _chat.eventos.listen(_alEvento);
    _scroll.addListener(_alDesplazar);
    _cargar();
  }

  @override
  void dispose() {
    if (_chat.conversacionAbierta == _conv.id) {
      _chat.conversacionAbierta = null;
    }
    _suscripcion?.cancel();
    for (final (_, temporizador) in _escribiendo.values) {
      temporizador.cancel();
    }
    _texto.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final mensajes = await _chat.obtenerMensajes(_conv.id, limite: _tamanoPagina);
      if (!mounted) return;
      setState(() {
        // Se conservan los mensajes propios que aún esperan confirmación.
        final pendientes = _mensajes.where((m) =>
            m.pendiente &&
            !mensajes.any((n) => n.usuarioId == _miId && n.contenido == m.contenido));
        _mensajes = [...mensajes, ...pendientes];
        _hayMas = mensajes.length == _tamanoPagina;
        _error = null;
      });
      _chat.marcarLeido(_conv.id);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// La lista está invertida: el "final" del scroll son los mensajes viejos.
  void _alDesplazar() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _cargarAnteriores();
    }
  }

  Future<void> _cargarAnteriores() async {
    if (!_hayMas || _cargandoAnteriores || _cargando) return;
    final masAntiguo = _mensajes.where((m) => !m.pendiente).firstOrNull;
    if (masAntiguo == null) return;

    setState(() => _cargandoAnteriores = true);
    try {
      final anteriores = await _chat.obtenerMensajes(
        _conv.id,
        antesDe: masAntiguo.id,
        limite: _tamanoPagina,
      );
      if (!mounted) return;
      setState(() {
        _mensajes = [...anteriores, ..._mensajes];
        _hayMas = anteriores.length == _tamanoPagina;
      });
    } catch (_) {
      // Se reintentará en el siguiente desplazamiento.
    } finally {
      if (mounted) setState(() => _cargandoAnteriores = false);
    }
  }

  void _alEvento(Map<String, dynamic> evento) {
    switch (evento['tipo']) {
      case 'mensaje':
        final mensaje = MensajeModel.fromJson(
          evento['mensaje'] as Map<String, dynamic>,
        );
        if (mensaje.conversacionId != _conv.id) return;
        final tempId = evento['temp_id'];
        setState(() {
          final pendiente = _mensajes.indexWhere(
            (m) => m.tempId != null && m.tempId == tempId,
          );
          if (pendiente != -1) {
            _mensajes[pendiente] = mensaje;
          } else if (!_mensajes.any((m) => m.id == mensaje.id)) {
            _mensajes.add(mensaje);
          }
          _quitarEscribiendo(mensaje.usuarioId);
        });
        if (mensaje.usuarioId != _miId) _chat.marcarLeido(_conv.id);

      case 'error':
        final tempId = evento['temp_id'];
        if (tempId == null) return;
        final antes = _mensajes.length;
        setState(() => _mensajes.removeWhere((m) => m.tempId == tempId));
        if (_mensajes.length != antes) {
          _mostrar('No se envió el mensaje: ${evento['detalle']}');
        }

      case 'escribiendo':
        if (evento['conversacion_id'] != _conv.id) return;
        final usuarioId = evento['usuario_id'] as int;
        _escribiendo[usuarioId]?.$2.cancel();
        setState(() {
          _escribiendo[usuarioId] = (
            evento['nombre'] as String,
            Timer(const Duration(seconds: 4), () {
              if (mounted) setState(() => _quitarEscribiendo(usuarioId));
            }),
          );
        });

      case 'conversacion':
        final conv = ConversacionModel.fromJson(
          evento['conversacion'] as Map<String, dynamic>,
        );
        if (conv.id == _conv.id) setState(() => _conv = conv);

      case 'conversacion_eliminada':
        if (evento['conversacion_id'] == _conv.id && mounted) {
          Navigator.pop(context);
        }

      case 'autenticado':
        // Reconexión: se recuperan los mensajes que llegaron sin conexión.
        _cargar();
    }
  }

  void _quitarEscribiendo(int usuarioId) {
    _escribiendo.remove(usuarioId)?.$2.cancel();
  }

  void _mostrar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  Future<void> _enviar() async {
    final contenido = _texto.text.trim();
    if (contenido.isEmpty) return;

    // Se muestra de inmediato y se confirma cuando el servidor responde.
    final tempId = _chat.nuevoTempId();
    setState(() {
      _mensajes.add(MensajeModel(
        id: -1,
        conversacionId: _conv.id,
        usuarioId: _miId,
        autorNombre: Sesion.instancia.usuario!.nombre,
        contenido: contenido,
        fecha: DateTime.now(),
        tempId: tempId,
      ));
    });
    _texto.clear();
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }

    try {
      await _chat.enviarMensaje(_conv.id, contenido, tempId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _mensajes.removeWhere((m) => m.tempId == tempId));
      _texto.text = contenido;
      _mostrar('No se envió el mensaje: $e');
    }
  }

  Future<void> _abrirInfo() async {
    if (!_conv.esGrupo) return;
    final resultado = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => GrupoInfoPage(conversacion: _conv)),
    );
    if (!mounted) return;
    if (resultado == 'salio') {
      Navigator.pop(context);
      return;
    }
    try {
      final conv = await _chat.obtenerConversacion(_conv.id);
      if (mounted) setState(() => _conv = conv);
    } catch (_) {}
  }

  String _subtitulo(Set<int> enLinea) {
    if (_escribiendo.isNotEmpty) {
      final nombres = _escribiendo.values.map((e) => e.$1.split(' ').first);
      return _conv.esGrupo
          ? '${nombres.join(', ')} ${_escribiendo.length == 1 ? 'está' : 'están'} escribiendo...'
          : 'escribiendo...';
    }
    if (_conv.esGrupo) {
      final conectados =
          _conv.miembros.where((m) => m.id != _miId && enLinea.contains(m.id)).length;
      return '${_conv.miembros.length} integrantes · $conectados en línea';
    }
    final otro = _conv.otroMiembro(_miId);
    return otro != null && enLinea.contains(otro.id) ? 'En línea' : 'Desconectado';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: ValueListenableBuilder<Set<int>>(
          valueListenable: _chat.enLinea,
          builder: (context, enLinea, _) {
            final otro = _conv.otroMiembro(_miId);
            return InkWell(
              onTap: _conv.esGrupo ? _abrirInfo : null,
              child: Row(
                children: [
                  AvatarUsuario(
                    nombre: _conv.nombre,
                    esGrupo: _conv.esGrupo,
                    enLinea: otro != null && enLinea.contains(otro.id),
                    radio: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_conv.nombre, overflow: TextOverflow.ellipsis),
                        Text(
                          _subtitulo(enLinea),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          if (_conv.esGrupo)
            IconButton(
              onPressed: _abrirInfo,
              icon: const Icon(Icons.info_outline),
              tooltip: 'Información del grupo',
            ),
        ],
      ),
      body: Column(
        children: [
          const EstadoConexionBanner(),
          Expanded(child: _listaMensajes()),
          _barraEscritura(),
        ],
      ),
    );
  }

  Widget _listaMensajes() {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    if (_error != null && _mensajes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            TextButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    if (_mensajes.isEmpty) {
      return const Center(
        child: Text(
          'Envía el primer mensaje 👋',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      itemCount: _mensajes.length + (_cargandoAnteriores ? 1 : 0),
      itemBuilder: (context, indice) {
        if (indice == _mensajes.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        // Índice cronológico (la lista se dibuja de abajo hacia arriba).
        final i = _mensajes.length - 1 - indice;
        final mensaje = _mensajes[i];
        final anterior = i > 0 ? _mensajes[i - 1] : null;
        final nuevoDia = anterior == null ||
            !_mismoDia(anterior.fecha, mensaje.fecha);
        final mismoAutor = !nuevoDia && anterior.usuarioId == mensaje.usuarioId;

        return Column(
          children: [
            if (nuevoDia) _separadorFecha(mensaje.fecha),
            _burbuja(mensaje, mostrarAutor: _conv.esGrupo && !mismoAutor),
          ],
        );
      },
    );
  }

  bool _mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _separadorFecha(DateTime fecha) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            formatoFecha(fecha),
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
      ),
    );
  }

  Widget _burbuja(MensajeModel mensaje, {required bool mostrarAutor}) {
    final mio = mensaje.usuarioId == _miId;
    final colorFondo = mio ? const Color(0xFF2196F3) : Colors.grey.shade200;
    final colorTexto = mio ? Colors.white : Colors.black87;

    return Align(
      alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          margin: EdgeInsets.only(top: mostrarAutor ? 8 : 2, bottom: 2),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: colorFondo,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mio ? 16 : 4),
              bottomRight: Radius.circular(mio ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (mostrarAutor && !mio)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    mensaje.autorNombre,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7E57C2),
                    ),
                  ),
                ),
              Text(mensaje.contenido, style: TextStyle(color: colorTexto, fontSize: 15)),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatoHora(mensaje.fecha),
                    style: TextStyle(
                      fontSize: 11,
                      color: mio ? Colors.white70 : Colors.black45,
                    ),
                  ),
                  if (mio) ...[
                    const SizedBox(width: 4),
                    Icon(
                      mensaje.pendiente ? Icons.schedule : Icons.done,
                      size: 13,
                      color: Colors.white70,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barraEscritura() {
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _texto,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onChanged: (_) => _chat.notificarEscribiendo(_conv.id),
                  onSubmitted: (_) => _enviar(),
                  decoration: InputDecoration(
                    hintText: 'Escribe un mensaje...',
                    counterText: '',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                onPressed: _enviar,
                icon: const Icon(Icons.send),
                tooltip: 'Enviar',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
