import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import '../services/sesion.dart';
import '../widgets/app_drawer.dart';
import '../widgets/post_card.dart';
import 'add_blog_page.dart';
import 'post_detail_page.dart';

class BlogPage extends StatefulWidget {
  const BlogPage({super.key});

  @override
  State<BlogPage> createState() => _BlogPageState();
}

class _BlogPageState extends State<BlogPage> {
  final PostService postService = PostService();
  final int miId = Sesion.instancia.usuario!.id;

  late Future<List<PostModel>> futurePosts;
  late Future<List<PostModel>> futureMisPosts;

  @override
  void initState() {
    super.initState();
    futurePosts = postService.obtenerPosts();
    futureMisPosts = postService.obtenerPosts(autorId: miId);
  }

  void recargarPosts() {
    setState(() {
      futurePosts = postService.obtenerPosts();
      futureMisPosts = postService.obtenerPosts(autorId: miId);
    });
  }

  Future<void> abrirPost(PostModel post) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => PostDetailPage(post: post),
      ),
    );
    // Al regresar se recarga para reflejar comentarios y calificaciones.
    if (mounted) recargarPosts();
  }

  Future<void> nuevaPublicacion() async {
    final creado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const AddBlogPage()),
    );
    if (creado == true && mounted) recargarPosts();
  }

  @override
  Widget build(BuildContext context) {
    final nombreUsuario = Sesion.instancia.usuario?.nombre ?? 'Usuario';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Mi Blog'),
              Text(
                'Bienvenido, $nombreUsuario',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: recargarPosts,
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar publicaciones',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Todas'),
              Tab(text: 'Mis publicaciones'),
            ],
          ),
        ),
        // El cierre de sesión está en el menú lateral, disponible para todos.
        drawer: const AppDrawer(rutaActual: '/blog'),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: nuevaPublicacion,
          icon: const Icon(Icons.post_add),
          label: const Text('Publicar'),
        ),
        body: TabBarView(
          children: [
            _listaPosts(futurePosts, 'No hay publicaciones registradas.'),
            _listaPosts(
              futureMisPosts,
              'Aún no has publicado nada.\nToca "Publicar" para crear tu primera entrada.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _listaPosts(Future<List<PostModel>> futuro, String mensajeVacio) {
    return FutureBuilder<List<PostModel>>(
      future: futuro,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 45),
                  const SizedBox(height: 12),
                  const Text(
                    'No fue posible cargar el blog.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: recargarPosts,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        final posts = snapshot.data ?? <PostModel>[];

        return RefreshIndicator(
          onRefresh: () async {
            recargarPosts();
            try {
              await Future.wait([futurePosts, futureMisPosts]);
            } catch (_) {
              // El error se muestra en la propia lista.
            }
          },
          child: posts.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 120),
                    Text(mensajeVacio, textAlign: TextAlign.center),
                  ],
                )
              : ListView(
                  // Espacio inferior para que el botón flotante no tape la última tarjeta.
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  children: posts
                      .map(
                        (post) => PostCard(
                          post: post,
                          esPropio: post.usuarioId == miId,
                          onTap: () => abrirPost(post),
                        ),
                      )
                      .toList(),
                ),
        );
      },
    );
  }
}
