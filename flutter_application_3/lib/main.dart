import 'package:flutter/material.dart';
import 'config/api_config.dart';
import 'config/navegacion.dart';
import 'screens/blog_page.dart';
import 'screens/chats_page.dart';
import 'screens/login_user_page.dart';
import 'screens/profile_page.dart';
import 'screens/register_user_page.dart';
import 'screens/users_page.dart';
import 'services/sesion.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.cargar();
  // Si hay un token guardado y sigue vigente, se entra sin pedir contraseña.
  final haySesion = await Sesion.instancia.restaurar();
  runApp(LoginApp(
    rutaInicial: haySesion ? Sesion.instancia.rutaInicio : '/login',
  ));
}

class LoginApp extends StatelessWidget {
  final String rutaInicial;

  const LoginApp({super.key, this.rutaInicial = '/login'});

  /// Control de acceso en la app: sin sesión se manda al login y
  /// las pantallas de administración sólo las ve un administrador.
  /// (La API valida lo mismo del lado del servidor.)
  static WidgetBuilder _protegida(
    WidgetBuilder pantalla, {
    bool soloAdmin = false,
  }) {
    return (context) {
      final sesion = Sesion.instancia;
      if (!sesion.activa) return const LoginPage();
      if (soloAdmin && !sesion.esAdmin) return const BlogPage();
      return pantalla(context);
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aplicación móvil con FastAPI',
      navigatorKey: navegadorGlobal,
      scaffoldMessengerKey: mensajeroGlobal,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2196F3),
        useMaterial3: true,
      ),
      initialRoute: rutaInicial,
      routes: {
        '/login': (context) => const LoginPage(),
        // Registro público o, con sesión de administrador, alta de usuarios.
        '/register': (context) => const RegisterPage(),
        '/blog': _protegida((context) => const BlogPage()),
        '/chats': _protegida((context) => const ChatsPage()),
        '/profile': _protegida((context) => const ProfilePage()),
        '/users': _protegida((context) => const UsersPage(), soloAdmin: true),
      },
    );
  }
}
