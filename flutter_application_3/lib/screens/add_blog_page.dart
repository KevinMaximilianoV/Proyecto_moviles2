import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../services/sesion.dart';

/// Crea una publicación o, si recibe [post], la edita.
/// Al guardar regresa `true` a la pantalla anterior.
class AddBlogPage extends StatefulWidget {
  final PostModel? post;

  const AddBlogPage({super.key, this.post});

  @override
  State<AddBlogPage> createState() => _AddBlogPageState();
}

class _AddBlogPageState extends State<AddBlogPage> {
  final _formKey = GlobalKey<FormState>();
  late final _titulo = TextEditingController(text: widget.post?.titulo);
  late final _descripcion =
      TextEditingController(text: widget.post?.descripcion);
  late final _imagen = TextEditingController(text: widget.post?.imagen);
  late final _tags = TextEditingController(text: widget.post?.tags);
  final _servicio = PostService();
  bool _guardando = false;

  bool get _esEdicion => widget.post != null;

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    _imagen.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      if (_esEdicion) {
        await _servicio.actualizarPost(
          id: widget.post!.id,
          titulo: _titulo.text,
          descripcion: _descripcion.text,
          imagen: _imagen.text,
          tags: _tags.text,
        );
      } else {
        await _servicio.agregarPost(
          titulo: _titulo.text,
          descripcion: _descripcion.text,
          imagen: _imagen.text,
          tags: _tags.text,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_esEdicion
              ? 'Publicación actualizada correctamente'
              : 'Publicación agregada correctamente'),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre = Sesion.instancia.usuario?.nombre ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar publicación' : 'Nueva publicación'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _esEdicion ? 'Editar publicación' : 'Nueva publicación',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text('Autor: $nombre'),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _titulo,
                        maxLength: 150,
                        decoration: const InputDecoration(
                          labelText: 'Título',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Ingresa el título' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _descripcion,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Descripción',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Ingresa la descripción' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _imagen,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'URL de imagen (opcional)',
                          hintText: 'https://...',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final url = (v ?? '').trim();
                          if (url.isEmpty) return null;
                          final uri = Uri.tryParse(url);
                          final valida = uri != null &&
                              (uri.scheme == 'http' || uri.scheme == 'https') &&
                              uri.host.isNotEmpty;
                          return valida
                              ? null
                              : 'La URL debe iniciar con http:// o https://';
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _tags,
                        maxLength: 255,
                        decoration: const InputDecoration(
                          labelText: 'Etiquetas (opcional)',
                          hintText: 'flutter, tecnología, móvil',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _guardando ? null : _guardar,
                        icon: _guardando
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save),
                        label: Text(_guardando ? 'Guardando...' : 'Guardar publicación'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
