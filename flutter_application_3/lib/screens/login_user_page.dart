import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../services/sesion.dart';
import '../widgets/auth_background.dart';
import '../widgets/auth_card.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController usuarioController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  final AuthService authService = AuthService();

  bool ocultarPassword = true;
  bool cargando = false;

  @override
  void dispose() {
    usuarioController.dispose();
    passwordController.dispose();

    super.dispose();
  }

  Future<void> iniciarSesion() async {
    final mensaje = authService.validarLogin(
      usuario: usuarioController.text,
      password: passwordController.text,
    );

    if (mensaje != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensaje)));
      return;
    }

    setState(() {
      cargando = true;
    });

    try {
      // Guarda el token en almacenamiento seguro y abre el chat en tiempo real.
      await authService.autenticar(
        correo: usuarioController.text,
        password: passwordController.text,
      );

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        Sesion.instancia.rutaInicio,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() {
          cargando = false;
        });
      }
    }
  }

  /// Permite apuntar la app al servidor (laptop o Raspberry Pi)
  /// sin recompilar.
  Future<void> configurarServidor() async {
    final controller = TextEditingController(text: ApiConfig.baseUrl);
    String? error;

    final guardar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, actualizar) => AlertDialog(
          title: const Text('Servidor'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dirección IP de la laptop o Raspberry Pi donde corre la API. '
                'En el emulador de Android usa http://10.0.2.2:8000',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'URL de la API',
                  hintText: 'http://192.168.1.50:8000',
                  errorText: error,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => controller.text = ApiConfig.porDefecto,
              child: const Text('Restablecer'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final mensaje = ApiConfig.validar(controller.text);
                if (mensaje != null) {
                  actualizar(() => error = mensaje);
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (guardar == true) {
      await ApiConfig.guardar(controller.text);
      if (mounted) setState(() {});
    }
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        child: Center(
          // Permite desplazarse cuando aparece el teclado.
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: AuthCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  const Icon(Icons.lock, size: 65, color: Color(0xFFC9A227)),

                  const SizedBox(height: 15),

                  const Text(
                    'INICIAR SESIÓN',

                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF08245C),
                    ),
                  ),

                  const SizedBox(height: 25),

                  CustomTextField(
                    controller: usuarioController,

                    label: 'Correo electrónico',

                    prefixIcon: Icons.person,

                    keyboardType: TextInputType.emailAddress,
                  ),

                  const SizedBox(height: 15),

                  CustomTextField(
                    controller: passwordController,

                    label: 'Contraseña',

                    prefixIcon: Icons.lock_outline,

                    obscureText: ocultarPassword,

                    suffixIcon: IconButton(
                      icon: Icon(
                        ocultarPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),

                      onPressed: () {
                        setState(() {
                          ocultarPassword = !ocultarPassword;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  PrimaryButton(
                    text: cargando ? 'VALIDANDO...' : 'INGRESAR',
                    onPressed: () {
                      if (!cargando) iniciarSesion();
                    },
                  ),

                  const SizedBox(height: 15),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [
                      const Text('¿No tienes cuenta?'),

                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/register');
                        },

                        child: const Text('Registrarse'),
                      ),
                    ],
                  ),

                  TextButton.icon(
                    onPressed: configurarServidor,
                    icon: const Icon(Icons.dns_outlined, size: 18),
                    label: Text(
                      ApiConfig.baseUrl,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
