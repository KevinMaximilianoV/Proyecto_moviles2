import 'package:flutter/material.dart';
import '../models/comentario_model.dart';
import '../models/post_model.dart';
import '../services/comentario_service.dart';
import '../services/post_service.dart';
import '../services/sesion.dart';
import '../utils/formato.dart';
import '../widgets/avatar_usuario.dart';
import '../widgets/estrellas.dart';
import 'add_blog_page.dart';

class PostDetailPage extends StatefulWidget {
  final PostModel post;
  const PostDetailPage({
    super.key,
    required this.post,
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final _postService = PostService();
  final _comentarioService = ComentarioService();
  final _comentarioController = TextEditingController();
  final int _miId = Sesion.instancia.usuario!.id;
  final bool _soyAdmin = Sesion.instancia.esAdmin;

  late PostModel _post = widget.post;
  List<ComentarioModel> _comentarios = [];
  bool _cargandoComentarios = true;
  String? _errorComentarios;
  bool _enviando = false;
  bool _calificando = false;

  bool get _esAutor => _post.usuarioId == _miId;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargandoComentarios = true;
      _errorComentarios = null;
    });
    try {
      final resultados = await Future.wait([
        _postService.obtenerPost(_post.id),
        _comentarioService.obtenerComentarios(_post.id),
      ]);
      if (!mounted) return;
      setState(() {
        _post = resultados[0] as PostModel;
        _comentarios = resultados[1] as List<ComentarioModel>;
      });
    } catch (e) {
      if (mounted) setState(() => _errorComentarios = e.toString());
    } finally {
      if (mounted) setState(() => _cargandoComentarios = false);
    }
  }

  void _mostrar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  Future<void> _calificar(int estrellas) async {
    if (_calificando) return;
    setState(() => _calificando = true);
    try {
      // Tocar la misma estrella otra vez quita la calificación.
      final resumen = estrellas == _post.miCalificacion
          ? await _postService.quitarCalificacion(_post.id)
          : await _postService.calificar(_post.id, estrellas);
      if (mounted) setState(() => _post = _post.conCalificacion(resumen));
    } catch (e) {
      if (mounted) _mostrar('No se pudo calificar: $e');
    } finally {
      if (mounted) setState(() => _calificando = false);
    }
  }

  Future<void> _comentar() async {
    final texto = _comentarioController.text.trim();
    if (texto.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    try {
      final nuevo = await _comentarioService.agregarComentario(_post.id, texto);
      _comentarioController.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
        setState(() => _comentarios = [..._comentarios, nuevo]);
      }
    } catch (e) {
      if (mounted) _mostrar('No se pudo comentar: $e');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _eliminarComentario(ComentarioModel comentario) async {
    final confirmar = await _confirmar(
      'Eliminar comentario',
      '¿Deseas eliminar este comentario?',
    );
    if (!confirmar) return;
    try {
      await _comentarioService.eliminarComentario(comentario.id);
      if (mounted) {
        setState(() => _comentarios =
            _comentarios.where((c) => c.id != comentario.id).toList());
      }
    } catch (e) {
      if (mounted) _mostrar('No se pudo eliminar: $e');
    }
  }

  Future<void> _editar() async {
    final editado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => AddBlogPage(post: _post)),
    );
    if (editado == true) _cargar();
  }

  Future<void> _eliminarPost() async {
    final confirmar = await _confirmar(
      'Eliminar publicación',
      '¿Deseas eliminar "${_post.titulo}"? También se borrarán sus '
          'comentarios y calificaciones.',
    );
    if (!confirmar) return;
    try {
      await _postService.eliminarPost(_post.id);
      if (!mounted) return;
      _mostrar('Publicación eliminada');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) _mostrar('No se pudo eliminar: $e');
    }
  }

  Future<bool> _confirmar(String titulo, String mensaje) async {
    final respuesta = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return respuesta == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de publicación'),
        actions: [
          if (_esAutor || _soyAdmin)
            PopupMenuButton<String>(
              onSelected: (opcion) {
                if (opcion == 'editar') _editar();
                if (opcion == 'eliminar') _eliminarPost();
              },
              itemBuilder: (context) => [
                if (_esAutor)
                  const PopupMenuItem(value: 'editar', child: Text('Editar')),
                const PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                children: [
                  if (_post.imagen.isNotEmpty)
                    Image.network(
                      _post.imagen,
                      height: 230,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox(
                          height: 150,
                          child: Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 48,
                            ),
                          ),
                        );
                      },
                    ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_post.tags.isNotEmpty) ...[
                          Text(
                            _post.tags,
                            style: const TextStyle(
                              color: Color(0xFF2196F3),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Text(
                          _post.titulo,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF08245C),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            AvatarUsuario(nombre: _post.autorNombre, radio: 16),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${_post.autorNombre} · ${formatoFecha(_post.fecha)}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _post.descripcion.isNotEmpty
                              ? _post.descripcion
                              : 'Esta publicación no tiene descripción.',
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _seccionCalificacion(),
                        const SizedBox(height: 24),
                        Text(
                          'Comentarios (${_comentarios.length})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _listaComentarios(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _campoComentario(),
        ],
      ),
    );
  }

  Widget _seccionCalificacion() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _post.promedio?.toStringAsFixed(1) ?? '–',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Estrellas(valor: _post.promedio ?? 0, tamano: 22),
                    Text(
                      _post.totalCalificaciones == 1
                          ? '1 calificación'
                          : '${_post.totalCalificaciones} calificaciones',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            if (_esAutor)
              const Text(
                'No puedes calificar tu propia publicación.',
                style: TextStyle(color: Colors.grey),
              )
            else
              Row(
                children: [
                  Text(_post.miCalificacion == null
                      ? 'Califica esta entrada:'
                      : 'Tu calificación:'),
                  const SizedBox(width: 8),
                  Estrellas(
                    valor: (_post.miCalificacion ?? 0).toDouble(),
                    tamano: 30,
                    onSeleccion: _calificando ? null : _calificar,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _listaComentarios() {
    if (_cargandoComentarios && _comentarios.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorComentarios != null) {
      return Column(
        children: [
          Text('No se pudieron cargar los comentarios: $_errorComentarios'),
          TextButton(onPressed: _cargar, child: const Text('Reintentar')),
        ],
      );
    }
    if (_comentarios.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Sé el primero en comentar.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return Column(
      children: _comentarios.map((c) {
        // Puede borrar: el autor del comentario, el del post o un admin.
        final puedeBorrar = c.usuarioId == _miId || _esAutor || _soyAdmin;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: AvatarUsuario(nombre: c.autorNombre, radio: 18),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  c.autorNombre,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatoRelativo(c.fecha),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          subtitle: Text(c.comentario),
          trailing: puedeBorrar
              ? IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Eliminar comentario',
                  onPressed: () => _eliminarComentario(c),
                )
              : null,
        );
      }).toList(),
    );
  }

  Widget _campoComentario() {
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
                  controller: _comentarioController,
                  maxLength: 1000,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _comentar(),
                  decoration: const InputDecoration(
                    hintText: 'Escribe un comentario...',
                    counterText: '',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                onPressed: _enviando ? null : _comentar,
                icon: _enviando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                tooltip: 'Enviar comentario',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
