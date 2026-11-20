import 'package:flutter/material.dart';
import '../services/chat_service.dart';

/// Franja que avisa cuando el chat en tiempo real no está conectado.
class EstadoConexionBanner extends StatelessWidget {
  const EstadoConexionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EstadoConexion>(
      valueListenable: ChatService.instancia.estado,
      builder: (context, estado, _) {
        if (estado == EstadoConexion.conectado) return const SizedBox.shrink();
        final conectando = estado == EstadoConexion.conectando;
        return Material(
          color: conectando ? Colors.amber.shade100 : Colors.red.shade100,
          child: InkWell(
            onTap: conectando ? null : ChatService.instancia.reconectar,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  if (conectando)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.wifi_off, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      conectando
                          ? 'Conectando al servidor de mensajes...'
                          : 'Sin conexión en tiempo real. Toca para reintentar.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
