import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../services/sesion.dart';
import '../services/user_service.dart';
import '../widgets/avatar_usuario.dart';

class ResultadoSeleccion {
  /// Nombre del grupo, cuando se pidió.
  final String? nombre;
  final List<MiembroModel> usuarios;

  const ResultadoSeleccion({this.nombre, required this.usuarios});
}

/// Elige uno o varios usuarios del directorio (para chats y grupos).
class SeleccionarUsuariosPage extends StatefulWidget {
  final String titulo;
  final bool multiple;
  final bool pedirNombre;
  final Set<int> excluir;

  const SeleccionarUsuariosPage({
    super.key,
    required this.titulo,
    this.multiple = false,
    this.pedirNombre = false,
    this.excluir = const {},
  });

  @override
  State<SeleccionarUsuariosPage> createState() =>
      _SeleccionarUsuariosPageState();
}

class _SeleccionarUsuariosPageState extends State<SeleccionarUsuariosPage> {
  final _userService = UserService();
  final _nombre = TextEditingController();
  final _busqueda = TextEditingController();
  final int _miId = Sesion.instancia.usuario!.id;

  late Future<List<MiembroModel>> _futuro = _userService.obtenerDirectorio();
  final Map<int, MiembroModel> _seleccionados = {};

  @override
  void initState() {
    super.initState();
    _nombre.addListener(() => setState(() {}));
    _busqueda.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nombre.dispose();
    _busqueda.dispose();
    super.dispose();
  }

  bool get _puedeConfirmar =>
      _seleccionados.isNotEmpty &&
      (!widget.pedirNombre || _nombre.text.trim().isNotEmpty);

  void _confirmar() {
    Navigator.pop(
      context,
      ResultadoSeleccion(
        nombre: widget.pedirNombre ? _nombre.text.trim() : null,
        usuarios: _seleccionados.values.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo),
        bottom: widget.multiple && _seleccionados.isNotEmpty
            ? PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('${_seleccionados.length} seleccionados'),
                ),
              )
            : null,
      ),
      floatingActionButton: widget.multiple
          ? FloatingActionButton.extended(
              onPressed: _puedeConfirmar ? _confirmar : null,
              backgroundColor: _puedeConfirmar ? null : Colors.grey.shade300,
              icon: const Icon(Icons.check),
              label: Text(widget.pedirNombre ? 'Crear grupo' : 'Agregar'),
            )
          : null,
      body: Column(
        children: [
          if (widget.pedirNombre)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TextField(
                controller: _nombre,
                maxLength: 100,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre del grupo',
                  prefixIcon: Icon(Icons.groups_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _busqueda,
              decoration: const InputDecoration(
                hintText: 'Buscar usuario',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(child: _lista()),
        ],
      ),
    );
  }

  Widget _lista() {
    return FutureBuilder<List<MiembroModel>>(
      future: _futuro,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${snapshot.error}', textAlign: TextAlign.center),
                TextButton(
                  onPressed: () => setState(
                    () => _futuro = _userService.obtenerDirectorio(),
                  ),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }

        final filtro = _busqueda.text.trim().toLowerCase();
        final usuarios = (snapshot.data ?? [])
            .where((u) => u.id != _miId && !widget.excluir.contains(u.id))
            .where((u) => u.nombre.toLowerCase().contains(filtro))
            .toList();

        if (usuarios.isEmpty) {
          return const Center(child: Text('No hay usuarios disponibles'));
        }

        // El estado en línea se actualiza en vivo con el WebSocket.
        return ValueListenableBuilder<Set<int>>(
          valueListenable: ChatService.instancia.enLinea,
          builder: (context, enLinea, _) => ListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: usuarios.length,
            itemBuilder: (context, index) {
              final u = usuarios[index];
              final conectado = enLinea.contains(u.id);
              final avatar = AvatarUsuario(nombre: u.nombre, enLinea: conectado);
              final estado = Text(conectado ? 'En línea' : 'Desconectado');

              if (!widget.multiple) {
                return ListTile(
                  leading: avatar,
                  title: Text(u.nombre),
                  subtitle: estado,
                  onTap: () => Navigator.pop(
                    context,
                    ResultadoSeleccion(usuarios: [u]),
                  ),
                );
              }
              return CheckboxListTile(
                secondary: avatar,
                title: Text(u.nombre),
                subtitle: estado,
                value: _seleccionados.containsKey(u.id),
                onChanged: (marcado) => setState(() {
                  if (marcado == true) {
                    _seleccionados[u.id] = u;
                  } else {
                    _seleccionados.remove(u.id);
                  }
                }),
              );
            },
          ),
        );
      },
    );
  }
}
