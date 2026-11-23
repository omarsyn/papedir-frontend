import 'package:cached_network_image/cached_network_image.dart';
import 'package:core/core.dart' show authProvider, usuarioFirebaseProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_error.dart';
import '../../core/legal.dart';
import '../../core/preferencias.dart';
import '../../core/tema.dart';
import '../../core/temas_fcm.dart';
import '../../core/widgets/mensajes.dart';
import 'perfil_provider.dart';

/// Mi perfil: datos, contraseña, avisos legales, notificaciones y
/// eliminar la cuenta (lo exigen Google Play y App Store).
class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key, this.conPromociones = false});

  /// Solo el Cliente puede suscribirse al tema `promociones`.
  final bool conPromociones;

  Future<void> _guardar(BuildContext context, WidgetRef ref) async {
    final c = ref.read(perfilCamposProvider);
    if (!(c.form.currentState?.validate() ?? false)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      await ref
          .read(perfilProvider.notifier)
          .guardar(nombre: c.nombre.text.trim(), telefono: c.telefono.text);
      if (context.mounted) mostrarMensaje(context, 'Perfil actualizado');
    } catch (e) {
      if (context.mounted) mostrarError(context, e);
    }
  }

  Future<void> _foto(BuildContext context, WidgetRef ref) async {
    try {
      final cambio = await ref.read(perfilProvider.notifier).cambiarFoto();
      if (cambio && context.mounted) {
        mostrarMensaje(context, 'Foto actualizada');
      }
    } catch (e) {
      if (context.mounted) mostrarError(context, e);
    }
  }

  Future<void> _cambiarPassword(BuildContext context, WidgetRef ref) async {
    final form = GlobalKey<FormState>();
    var actual = '';
    var nueva = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Cambiar contraseña'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña actual',
                ),
                onChanged: (v) => actual = v,
                validator: (v) =>
                    (v ?? '').isEmpty ? 'Escribe tu contraseña actual' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña nueva',
                  helperText: 'Mínimo 8 caracteres',
                ),
                onChanged: (v) => nueva = v,
                validator: (v) {
                  if ((v ?? '').length < 8) return 'Al menos 8 caracteres';
                  if (v == actual) return 'Debe ser distinta de la actual';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirma la nueva',
                ),
                validator: (v) =>
                    v != nueva ? 'Las contraseñas no coinciden' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState?.validate() ?? false) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(perfilProvider.notifier).cambiarPassword(actual, nueva);
      if (context.mounted) {
        mostrarMensaje(
          context,
          'Contraseña cambiada. Se cerraron tus otras sesiones.',
        );
      }
    } on ApiError catch (e) {
      if (!context.mounted) return;
      mostrarMensaje(
        context,
        e.codigo == 'PASSWORD_INCORRECTA'
            ? 'La contraseña actual no es correcta'
            : e.message,
      );
    }
  }

  Future<void> _eliminar(BuildContext context, WidgetRef ref) async {
    final form = GlobalKey<FormState>();
    var password = '';
    // Las cuentas de Firebase (Google, GitHub) no tienen contraseña de PaPedir.
    final esFirebase = ref.read(usuarioFirebaseProvider).valueOrNull != null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final esquema = Theme.of(ctx).colorScheme;
        return AlertDialog(
          scrollable: true,
          icon: Icon(Icons.warning_amber_rounded, color: esquema.error),
          title: const Text('¿Eliminar tu cuenta?'),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Se borrarán tu nombre, correo, teléfono, foto y '
                  'direcciones, y se cerrarán todas tus sesiones. Tus pedidos '
                  'se conservan sin datos personales. No se puede deshacer.',
                ),
                if (!esFirebase) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Escribe tu contraseña para confirmar',
                    ),
                    onChanged: (v) => password = v,
                    validator: (v) =>
                        (v ?? '').isEmpty ? 'Escribe tu contraseña' : null,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: esquema.error,
                foregroundColor: esquema.onError,
              ),
              onPressed: () {
                if (form.currentState?.validate() ?? false) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Eliminar cuenta'),
            ),
          ],
        );
      },
    );
    if (ok != true || !context.mounted) return;
    try {
      // Al cerrar la sesión la app regresa sola al login.
      await ref.read(perfilProvider.notifier).eliminarCuenta(password);
    } on ApiError catch (e) {
      if (!context.mounted) return;
      final String texto;
      switch (e.codigo) {
        case 'PASSWORD_INCORRECTA':
          texto = 'La contraseña no es correcta';
        case 'TIENE_PEDIDOS_ACTIVOS':
          texto =
              'Tienes pedidos en curso. Espera a que terminen o cancélalos '
              'antes de eliminar tu cuenta.';
        default:
          texto = e.message;
      }
      mostrarMensaje(context, texto);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authProvider).usuario;
    final c = ref.watch(perfilCamposProvider);
    final accion = ref.watch(perfilProvider);
    final ocupado = accion != AccionPerfil.ninguna;
    final legal = ref.watch(legalProvider).valueOrNull;
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final nombre = usuario?.nombre ?? '';
    final foto = usuario?.fotoUrl;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: ListView(
        padding: const EdgeInsets.all(Disenio.margen),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: esquema.primaryContainer,
                  backgroundImage: foto == null
                      ? null
                      : CachedNetworkImageProvider(foto),
                  child: foto != null
                      ? null
                      : Text(
                          nombre.isEmpty
                              ? '?'
                              : nombre.characters.first.toUpperCase(),
                          style: tema.textTheme.headlineMedium?.copyWith(
                            color: esquema.onPrimaryContainer,
                          ),
                        ),
                ),
                // Solo las cuentas de correo cambian su foto; las de Google
                // o GitHub usan la del proveedor (puedeCambiarFoto).
                if (usuario?.puedeCambiarFoto ?? false)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: IconButton.filled(
                      tooltip: 'Cambiar foto',
                      onPressed: ocupado ? null : () => _foto(context, ref),
                      icon: accion == AccionPerfil.foto
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_camera_outlined, size: 20),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              usuario?.email ?? '',
              style: tema.textTheme.bodyMedium?.copyWith(
                color: esquema.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Form(
            key: c.form,
            child: Column(
              children: [
                TextFormField(
                  controller: c.nombre,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Escribe tu nombre' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: c.telefono,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) => RegExp(r'^\d{10}$').hasMatch(v ?? '')
                      ? null
                      : 'Deben ser 10 dígitos',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: ocupado ? null : () => _guardar(context, ref),
            child: accion == AccionPerfil.guardando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar cambios'),
          ),
          const SizedBox(height: 24),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Cambiar contraseña'),
                  trailing: const Icon(Icons.chevron_right),
                  enabled: !ocupado,
                  onTap: () => _cambiarPassword(context, ref),
                ),
                if (conPromociones)
                  SwitchListTile(
                    secondary: const Icon(Icons.local_offer_outlined),
                    title: const Text('Recibir promociones'),
                    subtitle: const Text('Cupones y ofertas de las tiendas'),
                    value: ref.watch(promocionesProvider),
                    onChanged: (v) =>
                        ref.read(promocionesProvider.notifier).cambiar(v),
                  ),
                SwitchListTile(
                  secondary: const Icon(Icons.format_size),
                  title: const Text('Texto grande'),
                  subtitle: const Text('Se guarda en tu cuenta'),
                  value: ref.watch(fuenteGrandeProvider),
                  onChanged: (v) =>
                      ref.read(fuenteGrandeProvider.notifier).cambiar(v),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Términos de uso'),
                  subtitle: legal == null
                      ? null
                      : Text('Versión ${legal.version}'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: legal == null
                      ? null
                      : () => abrirLiga(context, legal.terminosUrl),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Aviso de privacidad'),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: legal == null
                      ? null
                      : () => abrirLiga(context, legal.privacidadUrl),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: esquema.error,
              side: BorderSide(color: esquema.error),
            ),
            onPressed: ocupado ? null : () => _eliminar(context, ref),
            icon: accion == AccionPerfil.eliminando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_forever_outlined),
            label: const Text('Eliminar mi cuenta'),
          ),
        ],
      ),
    );
  }
}
