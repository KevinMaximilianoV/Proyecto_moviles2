import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/sesion.dart';
import '../services/user_service.dart';
import '../widgets/app_drawer.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _userService = UserService();
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _direccion = TextEditingController();
  final _passActual = TextEditingController();
  final _passNueva = TextEditingController();
  final _passConfirmar = TextEditingController();
  final _passFormKey = GlobalKey<FormState>();
  bool _cambiandoPass = false;
  late UserModel _usuario = Sesion.instancia.usuario!;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _nombre.text = _usuario.nombre;
    _correo.text = _usuario.correo;
    _direccion.text = _usuario.direccion ?? '';
  }

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _direccion.dispose();
    _passActual.dispose();
    _passNueva.dispose();
    _passConfirmar.dispose();
    super.dispose();
  }

  Future<void> _cambiarPassword() async {
    if (!_passFormKey.currentState!.validate()) return;
    setState(() => _cambiandoPass = true);
    try {
      await _userService.cambiarPassword(
        usuarioId: _usuario.id,
        actual: _passActual.text,
        nueva: _passNueva.text,
      );
      _passActual.clear();
      _passNueva.clear();
      _passConfirmar.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _cambiandoPass = false);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      // El rol no se envía: un usuario no puede cambiar su propio tipo.
      final actualizado = await _userService.actualizarUsuario(
        UserModel(
          id: _usuario.id,
          nombre: _nombre.text.trim(),
          correo: _correo.text.trim().toLowerCase(),
          direccion: _direccion.text.trim().isEmpty ? null : _direccion.text.trim(),
          tipoUsuario: _usuario.tipoUsuario,
        ),
      );
      _usuario = actualizado;
      await Sesion.instancia.actualizarUsuario(actualizado);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar el perfil: $e')),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      drawer: const AppDrawer(rutaActual: '/profile'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CircleAvatar(
                        radius: 38,
                        child: Icon(Icons.person, size: 42),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _nombre,
                        decoration: const InputDecoration(
                          labelText: 'Nombre completo',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.trim().length < 2
                            ? 'Ingresa un nombre válido' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _correo,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || !v.contains('@')
                            ? 'Ingresa un correo válido' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _direccion,
                        decoration: const InputDecoration(
                          labelText: 'Dirección',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _cargando ? null : _guardar,
                        icon: const Icon(Icons.save),
                        label: Text(_cargando ? 'Guardando...' : 'Guardar cambios'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _passFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Cambiar contraseña',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passActual,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña actual',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Ingresa tu contraseña actual' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passNueva,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Nueva contraseña',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.length < 8
                            ? 'Debe tener al menos 8 caracteres' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passConfirmar,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirmar nueva contraseña',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v != _passNueva.text
                            ? 'Las contraseñas no coinciden' : null,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _cambiandoPass ? null : _cambiarPassword,
                        icon: const Icon(Icons.lock_reset),
                        label: Text(_cambiandoPass ? 'Cambiando...' : 'Cambiar contraseña'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ]),
          ),
        ),
      ),
    );
  }
}
