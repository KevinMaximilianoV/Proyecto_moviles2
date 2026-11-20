import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../utils/formato.dart';
import 'avatar_usuario.dart';
import 'estrellas.dart';
class PostCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback onTap;
  final bool esPropio;

  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
    this.esPropio = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.imagen.isNotEmpty)
              Image.network(
                post.imagen,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(
                    height: 110,
                    child: Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: 40,
                      ),
                    ),
                  );
                },
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AvatarUsuario(nombre: post.autorNombre, radio: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          esPropio ? '${post.autorNombre} (tú)' : post.autorNombre,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        formatoRelativo(post.fecha),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (post.tags.isNotEmpty) ...[
                    Text(
                      post.tags,
                      style: const TextStyle(
                        color: Color(0xFF2196F3),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  Text(
                    post.titulo,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF08245C),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    post.descripcion,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Estrellas(valor: post.promedio ?? 0, tamano: 18),
                      const SizedBox(width: 6),
                      Text(
                        post.promedio != null
                            ? '${post.promedio!.toStringAsFixed(1)} (${post.totalCalificaciones})'
                            : 'Sin calificar',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const Spacer(),
                      const Icon(Icons.chat_bubble_outline, size: 17),
                      const SizedBox(width: 4),
                      Text('${post.totalComentarios}'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
