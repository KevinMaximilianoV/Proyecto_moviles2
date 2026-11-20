import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../services/sesion.dart';
import '../utils/formato.dart';
import '../widgets/avatar_usuario.dart';
import 'seleccionar_usuarios_page.dart';

/// Datos del grupo: integrantes, renombrar, agregar personas y salir.
/// Regresa 'salio' si el usuario abandonó el grupo.
class GrupoInfoPage extends StatefulWidget {
  final ConversacionModel conversacion;

  const GrupoInfoPage({super.key, required this.conversacion});

  @override
  State<GrupoInfoPage> createState() => _GrupoInfoPageState();
}

class _GrupoInfoPageState extends State<GrupoInfoPage> {
  final ChatService _chat = ChatService.instancia;
  final int _miId = Sesion.instancia.usuario!.id;
  late ConversacionModel _conv = widget.conversacion;
  StreamSubscription<Map<String, dynamic>>? _suscripcion;
  bool _trabajando = false;

  @override
  void initState() {
    super.initState();
    _suscripcion = _chat.eventos.listen((evento) {
      if (evento['tipo'] != 'conversacion') return;
      final conv = ConversacionModel.fromJson(
        evento['conversacion'] as Map<String, dynamic>,
      );
      if (conv.id == _conv.id && mounted) setState(() => _conv = conv);
    });
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    super.dispose();
  }

  void _mostrar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  Future<void> _ejecutar(Future<void> Function() accion, String error) async {
    setState(() => _trabajando = true);
    try {
      await accion();
    } catch (e) {
      if (mounted) _mostrar('$error: $e');
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Future<void> _renombrar() async {
    final controller = TextEditingController(text: _conv.nombre);
    final nombre = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nombre del grupo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 100,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (nombre == null || nombre.isEmpty || nombre == _conv.nombre) return;

    await _ejecutar(() async {
      final conv = await _chat.renombrarGrupo(_conv.id, nombre);
      if (mounted) setState(() => _conv = conv);
    }, 'No se pudo renombrar');
  }

  Future<void> _agregar() async {
    final resultado = await Navigator.push<ResultadoSeleccion>(
      context,
      MaterialPageRoute(
        builder: (context) => SeleccionarUsuariosPage(
          titulo: 'Agregar integrantes',
          multiple: true,
          excluir: _conv.miembros.map((m) => m.id).toSet(),
        ),
      ),
    );
    if (resultado == null || resultado.usuarios.isEmpty) return;

    await _ejecutar(() async {
      final conv = await _chat.agregarMiembros(
        _conv.id,
        resultado.usuarios.map((u) => u.id).toList(),
      );
      if (mounted) setState(() => _conv = conv);
    }, 'No se pudieron agregar');
  }

  Future<void> _salir() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Salir del grupo'),
        content: Text('¿Deseas salir de "${_conv.nombre}"? '
            'Dejarás de recibir sus mensajes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    await _ejecutar(() async {
      await _chat.salirDeGrupo(_conv.id);
      if (mounted) Navigator.pop(context, 'salio');
    }, 'No se pudo salir del grupo');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Información del grupo')),
      body: AbsorbPointer(
        absorbing: _trabajando,
        child: ValueListenableBuilder<Set<int>>(
          valueListenable: _chat.enLinea,
          builder: (context, enLinea, _) => ListView(
            children: [
              if (_trabajando) const LinearProgressIndicator(),
              const SizedBox(height: 24),
              Center(
                child: AvatarUsuario(nombre: _conv.nombre, esGrupo: true, radio: 44),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      _conv.nombre,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: _renombrar,
                    icon: const Icon(Icons.edit, size: 20),
                    tooltip: 'Cambiar nombre',
                  ),
                ],
              ),
              Center(
                child: Text(
                  'Creado el ${formatoFecha(_conv.fecha)}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  '${_conv.miembros.length} integrantes',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_add)),
                title: const Text('Agregar integrantes'),
                onTap: _agregar,
              ),
              ..._conv.miembros.map((m) {
                final conectado = enLinea.contains(m.id);
                return ListTile(
                  leading: AvatarUsuario(nombre: m.nombre, enLinea: conectado),
                  title: Text(m.id == _miId ? '${m.nombre} (tú)' : m.nombre),
                  subtitle: Text(conectado ? 'En línea' : 'Desconectado'),
                  trailing: m.id == _conv.creadorId
                      ? const Chip(label: Text('Creador'))
                      : null,
                );
              }),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.red),
                title: const Text(
                  'Salir del grupo',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: _salir,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
