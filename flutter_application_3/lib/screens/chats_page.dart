import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../services/sesion.dart';
import '../utils/formato.dart';
import '../widgets/app_drawer.dart';
import '../widgets/avatar_usuario.dart';
import '../widgets/estado_conexion_banner.dart';
import 'chat_page.dart';
import 'seleccionar_usuarios_page.dart';

/// Lista de chats directos y grupos del usuario, actualizada en tiempo real.
class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  final ChatService _chat = ChatService.instancia;
  final int _miId = Sesion.instancia.usuario!.id;

  List<ConversacionModel> _conversaciones = [];
  bool _cargando = true;
  String? _error;
  StreamSubscription<Map<String, dynamic>>? _suscripcion;

  @override
  void initState() {
    super.initState();
    _suscripcion = _chat.eventos.listen(_alEvento);
    _cargar();
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final conversaciones = await _chat.obtenerConversaciones();
      if (!mounted) return;
      setState(() {
        _conversaciones = conversaciones;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _ordenar() {
    _conversaciones.sort((a, b) => b.ultimaActividad.compareTo(a.ultimaActividad));
  }

  void _alEvento(Map<String, dynamic> evento) {
    switch (evento['tipo']) {
      case 'mensaje':
        final mensaje = MensajeModel.fromJson(
          evento['mensaje'] as Map<String, dynamic>,
        );
        final indice = _conversaciones.indexWhere(
          (c) => c.id == mensaje.conversacionId,
        );
        if (indice == -1) {
          // Conversación que aún no estaba en la lista.
          _cargar();
          return;
        }
        final conv = _conversaciones[indice];
        final sumaNoLeido = mensaje.usuarioId != _miId &&
            _chat.conversacionAbierta != conv.id;
        setState(() {
          _conversaciones[indice] = conv.copyWith(
            ultimoMensaje: mensaje,
            noLeidos: sumaNoLeido ? conv.noLeidos + 1 : conv.noLeidos,
          );
          _ordenar();
        });
      case 'conversacion':
        final conv = ConversacionModel.fromJson(
          evento['conversacion'] as Map<String, dynamic>,
        );
        setState(() {
          _conversaciones = [
            conv,
            ..._conversaciones.where((c) => c.id != conv.id),
          ];
          _ordenar();
        });
      case 'conversacion_eliminada':
        setState(() => _conversaciones.removeWhere(
              (c) => c.id == evento['conversacion_id'],
            ));
      case 'autenticado':
        // Al reconectarse se recarga por si llegaron mensajes sin conexión.
        _cargar();
    }
  }

  Future<void> _abrir(ConversacionModel conv) async {
    setState(() {
      final indice = _conversaciones.indexWhere((c) => c.id == conv.id);
      if (indice != -1) {
        _conversaciones[indice] = _conversaciones[indice].copyWith(noLeidos: 0);
      }
    });
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatPage(conversacion: conv)),
    );
    if (mounted) _cargar();
  }

  void _mostrar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  Future<void> _nuevoChat() async {
    final resultado = await Navigator.push<ResultadoSeleccion>(
      context,
      MaterialPageRoute(
        builder: (context) => const SeleccionarUsuariosPage(
          titulo: 'Nuevo chat',
        ),
      ),
    );
    if (resultado == null || resultado.usuarios.isEmpty) return;
    try {
      final conv = await _chat.abrirChatDirecto(resultado.usuarios.first.id);
      if (mounted) _abrir(conv);
    } catch (e) {
      if (mounted) _mostrar('No se pudo abrir el chat: $e');
    }
  }

  Future<void> _nuevoGrupo() async {
    final resultado = await Navigator.push<ResultadoSeleccion>(
      context,
      MaterialPageRoute(
        builder: (context) => const SeleccionarUsuariosPage(
          titulo: 'Nuevo grupo',
          multiple: true,
          pedirNombre: true,
        ),
      ),
    );
    if (resultado == null) return;
    try {
      final conv = await _chat.crearGrupo(
        resultado.nombre!,
        resultado.usuarios.map((u) => u.id).toList(),
      );
      if (mounted) _abrir(conv);
    } catch (e) {
      if (mounted) _mostrar('No se pudo crear el grupo: $e');
    }
  }

  void _opcionesNuevo() {
    showModalBottomSheet<void>(
      context: context,
      builder: (hojaContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Nuevo chat'),
              subtitle: const Text('Conversación privada con un usuario'),
              onTap: () {
                Navigator.pop(hojaContext);
                _nuevoChat();
              },
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('Nuevo grupo'),
              subtitle: const Text('Conversación con varios usuarios'),
              onTap: () {
                Navigator.pop(hojaContext);
                _nuevoGrupo();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mensajes')),
      drawer: const AppDrawer(rutaActual: '/chats'),
      floatingActionButton: FloatingActionButton(
        onPressed: _opcionesNuevo,
        tooltip: 'Nueva conversación',
        child: const Icon(Icons.edit_square),
      ),
      body: Column(
        children: [
          const EstadoConexionBanner(),
          Expanded(child: _contenido()),
        ],
      ),
    );
  }

  Widget _contenido() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _conversaciones.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  setState(() => _cargando = true);
                  _cargar();
                },
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: _conversaciones.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Icon(Icons.forum_outlined, size: 56, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'Aún no tienes conversaciones.\nToca el botón para iniciar una.',
                  textAlign: TextAlign.center,
                ),
              ],
            )
          : ValueListenableBuilder<Set<int>>(
              valueListenable: _chat.enLinea,
              builder: (context, enLinea, _) => ListView.separated(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: _conversaciones.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, indent: 76),
                itemBuilder: (context, index) =>
                    _tile(_conversaciones[index], enLinea),
              ),
            ),
    );
  }

  Widget _tile(ConversacionModel conv, Set<int> enLinea) {
    final otro = conv.otroMiembro(_miId);
    final ultimo = conv.ultimoMensaje;
    final String vistaPrevia;
    if (ultimo == null) {
      vistaPrevia = conv.esGrupo
          ? '${conv.miembros.length} integrantes'
          : 'Sin mensajes';
    } else if (ultimo.usuarioId == _miId) {
      vistaPrevia = 'Tú: ${ultimo.contenido}';
    } else if (conv.esGrupo) {
      vistaPrevia = '${ultimo.autorNombre.split(' ').first}: ${ultimo.contenido}';
    } else {
      vistaPrevia = ultimo.contenido;
    }
    final tieneNoLeidos = conv.noLeidos > 0;

    return ListTile(
      onTap: () => _abrir(conv),
      leading: AvatarUsuario(
        nombre: conv.nombre,
        esGrupo: conv.esGrupo,
        enLinea: otro != null && enLinea.contains(otro.id),
      ),
      title: Text(
        conv.nombre,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: tieneNoLeidos ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        vistaPrevia,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: tieneNoLeidos ? Colors.black87 : Colors.grey,
          fontWeight: tieneNoLeidos ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatoChat(conv.ultimaActividad),
            style: TextStyle(
              fontSize: 12,
              color: tieneNoLeidos ? const Color(0xFF2196F3) : Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          if (tieneNoLeidos)
            Badge(
              label: Text('${conv.noLeidos}'),
              backgroundColor: const Color(0xFF2196F3),
            )
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }
}
