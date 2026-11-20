import 'package:flutter/material.dart';
import '../services/sesion.dart';

/// Menú lateral común. Las opciones de administración
/// sólo aparecen para usuarios administradores.
class AppDrawer extends StatelessWidget {
  final String rutaActual;

  const AppDrawer({
    super.key,
    required this.rutaActual,
  });

  void _navegar(BuildContext context, String ruta) {
    Navigator.pop(context);
    if (ruta == rutaActual) return;
    Navigator.pushReplacementNamed(context, ruta);
  }

  @override
  Widget build(BuildContext context) {
    final sesion = Sesion.instancia;
    final usuario = sesion.usuario;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF08245C)),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  sesion.esAdmin ? Icons.admin_panel_settings : Icons.person,
                  color: const Color(0xFF08245C),
                  size: 34,
                ),
              ),
              accountName: Text(usuario?.nombre ?? 'Usuario'),
              accountEmail: Text(usuario?.correo ?? ''),
            ),
            _opcion(context, Icons.article_outlined, 'Blog', '/blog'),
            _opcion(context, Icons.chat_bubble_outline, 'Mensajes', '/chats'),
            _opcion(context, Icons.account_circle_outlined, 'Mi perfil',
                '/profile'),
            if (sesion.esAdmin) ...[
              const Divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Administración',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ),
              _opcion(context, Icons.people_alt_outlined,
                  'Gestión de usuarios', '/users'),
              _opcion(context, Icons.person_add_alt_1, 'Registrar usuario',
                  '/register'),
            ],
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Cerrar sesión',
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                await Sesion.instancia.cerrar();
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (route) => false,
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _opcion(
    BuildContext context,
    IconData icono,
    String titulo,
    String ruta,
  ) {
    final seleccionado = ruta == rutaActual;
    return ListTile(
      leading: Icon(icono,
          color: seleccionado ? const Color(0xFF08245C) : null),
      title: Text(titulo),
      selected: seleccionado,
      onTap: () => _navegar(context, ruta),
    );
  }
}
