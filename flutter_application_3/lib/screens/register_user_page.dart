import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/sesion.dart';
import '../widgets/app_drawer.dart';
import '../widgets/auth_background.dart';
import '../widgets/auth_card.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController nombreController = TextEditingController();

  final TextEditingController correoController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  final TextEditingController confirmarController = TextEditingController();

  final AuthService authService = AuthService();

  final UserService userService = UserService();

  bool cargando = false;

  // 1 = administrador, 2 = usuario regular.
  int tipoUsuario = 2;

  @override
  void dispose() {
    nombreController.dispose();
    correoController.dispose();
    passwordController.dispose();
    confirmarController.dispose();

    super.dispose();
  }

  Future<void> registrarUsuario() async {
    final mensaje = authService.validarRegistro(
      nombre: nombreController.text.trim(),

      correo: correoController.text.trim(),

      password: passwordController.text,

      confirmarpassword: confirmarController.text,
    );

    if (mensaje != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensaje)));

      return;
    }

    setState(() => cargando = true);

    try {
      if (_esAdmin) {
        // Alta por administrador: puede elegir el tipo de usuario.
        await userService.agregarUsuario(
          UserModel(
            id: 0,
            nombre: nombreController.text.trim(),
            correo: correoController.text.trim().toLowerCase(),
            password: passwordController.text,
            tipoUsuario: tipoUsuario,
          ),
        );
      } else {
        // Registro público: el servidor siempre crea un usuario regular.
        await authService.registrar(
          nombre: nombreController.text,
          correo: correoController.text,
          password: passwordController.text,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Usuario ${nombreController.text.trim()} registrado'),
        ),
      );

      nombreController.clear();
      correoController.clear();
      passwordController.clear();
      confirmarController.clear();
      setState(() => tipoUsuario = 2);

      if (!_esAdmin) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  /// Con sesión de administrador la pantalla sirve para dar de alta usuarios.
  bool get _esAdmin => Sesion.instancia.activa && Sesion.instancia.esAdmin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: !_esAdmin ? null : AppBar(title: const Text('Registrar usuario')),

      drawer: !_esAdmin ? null : const AppDrawer(rutaActual: '/register'),

      body: AuthBackground(
        child: Center(
          // Permite desplazarse cuando aparece el teclado.
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: AuthCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  const Icon(
                    Icons.person_add,
                    size: 65,
                    color: Color(0xFF2196F3),
                  ),

                  const SizedBox(height: 15),

                  const Text(
                    'CREAR CUENTA',

                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF08245C),
                    ),
                  ),

                  const SizedBox(height: 25),

                  CustomTextField(
                    controller: nombreController,

                    label: 'Nombre completo',

                    prefixIcon: Icons.person,
                  ),

                  const SizedBox(height: 15),

                  CustomTextField(
                    controller: correoController,

                    label: 'Correo electrónico',

                    prefixIcon: Icons.email,

                    keyboardType: TextInputType.emailAddress,
                  ),

                  const SizedBox(height: 15),

                  CustomTextField(
                    controller: passwordController,

                    label: 'Contraseña',

                    prefixIcon: Icons.lock,

                    obscureText: true,
                  ),

                  const SizedBox(height: 15),

                  CustomTextField(
                    controller: confirmarController,

                    label: 'Confirmar contraseña',

                    prefixIcon: Icons.lock_outline,

                    obscureText: true,
                  ),

                  if (_esAdmin) ...[
                    const SizedBox(height: 15),
                    DropdownButtonFormField<int>(
                      initialValue: tipoUsuario,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de usuario',
                        prefixIcon: Icon(Icons.admin_panel_settings),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 2, child: Text('Regular')),
                        DropdownMenuItem(
                          value: 1,
                          child: Text('Administrador'),
                        ),
                      ],
                      onChanged: (valor) {
                        if (valor != null) {
                          setState(() => tipoUsuario = valor);
                        }
                      },
                    ),
                  ],

                  const SizedBox(height: 25),

                  PrimaryButton(
                    text: cargando ? 'REGISTRANDO...' : 'REGISTRARME',
                    onPressed: () {
                      if (!cargando) registrarUsuario();
                    },
                  ),

                  const SizedBox(height: 15),

                  TextButton(
                    onPressed: () {
                      if (!_esAdmin) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushReplacementNamed(context, '/users');
                      }
                    },

                    child: Text(
                      !_esAdmin ? 'Ya tengo una cuenta' : 'Volver a usuarios',
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
