import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:core/core.dart'
    show
        authProvider,
        dioProvider,
        firebaseLoginProvider,
        subirAvatar,
        tokenStorageProvider,
        usuarioFirebaseProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/preferencias.dart';
import '../../../core/responsivo.dart';

final _subiendoFotoProvider = StateProvider.autoDispose<bool>((_) => false);
final _eliminandoProvider = StateProvider.autoDispose<bool>((_) => false);

/// Foto de perfil (ACUERDOS §13): la del proveedor (Google/GitHub) o la que
/// sube el usuario. Solo las cuentas de correo pueden cambiarla
/// (`puedeCambiarFoto`); se guarda en Firebase Storage. Usa caché
/// (`cached_network_image`) para verse sin conexión.
class AvatarPerfil extends ConsumerWidget {
  const AvatarPerfil({super.key, required this.inicial});

  final String inicial;

  Future<void> _cambiar(BuildContext context, WidgetRef ref) async {
    final foto = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (foto == null) return;
    ref.read(_subiendoFotoProvider.notifier).state = true;
    try {
      await subirAvatar(ref.read(dioProvider), File(foto.path));
      await ref.read(authProvider.notifier).checkSession();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Foto actualizada')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
      }
    } finally {
      if (context.mounted) ref.read(_subiendoFotoProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authProvider).usuario;
    final subiendo = ref.watch(_subiendoFotoProvider);
    final url = usuario?.fotoUrl;
    final puedeCambiar = usuario?.puedeCambiarFoto ?? false;

    final avatar = CircleAvatar(
      radius: 30,
      backgroundImage: url == null || url.isEmpty
          ? null
          : CachedNetworkImageProvider(url),
      child: subiendo
          ? const CircularProgressIndicator(strokeWidth: 2)
          : (url == null || url.isEmpty)
          ? Text(
              inicial,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            )
          : null,
    );
    if (!puedeCambiar) return avatar;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: subiendo ? null : () => _cambiar(context, ref),
      child: Stack(
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: CircleAvatar(
              radius: 11,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(
                Icons.camera_alt,
                size: 13,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ganancias, documentos y tema (va en el perfil, arriba de "Mi cartera").
class OpcionesCuenta extends ConsumerWidget {
  const OpcionesCuenta({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = ref.watch(temaProvider);
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.payments_outlined),
          title: const Text('Ganancias y corte del día'),
          subtitle: const Text('Envíos, propinas y efectivo a entregar'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/ganancias'),
        ),
        ListTile(
          leading: const Icon(Icons.badge_outlined),
          title: const Text('Mis documentos'),
          subtitle: const Text('INE, licencia y demás'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/documentos'),
        ),
        ListTile(
          leading: const Icon(Icons.dark_mode_outlined),
          title: const Text('Tema'),
          subtitle: Text(etiquetaTema(tema)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => elegirTema(context, ref),
        ),
      ],
    );
  }
}

/// "Eliminar mi cuenta": DELETE /usuarios/me con la contraseña o, en
/// cuentas de Firebase, con un idToken reciente.
class BotonEliminarCuenta extends ConsumerWidget {
  const BotonEliminarCuenta({super.key});

  Future<void> _eliminar(BuildContext context, WidgetRef ref) async {
    final esFirebase = ref.read(usuarioFirebaseProvider).valueOrNull != null;
    final passwordCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar mi cuenta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Se borrarán tus datos y no podrás volver a entrar con esta '
              'cuenta. Esta acción no se puede deshacer.',
            ),
            if (!esFirebase) ...[
              const SizedBox(height: 16),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Escribe tu contraseña',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    final password = passwordCtrl.text;
    passwordCtrl.dispose();
    if (ok != true || !context.mounted) return;

    ref.read(_eliminandoProvider.notifier).state = true;
    try {
      final datos = esFirebase
          ? {'idToken': await ref.read(firebaseLoginProvider).idToken()}
          : {'password': password};
      await ref.read(dioProvider).delete<void>('/usuarios/me', data: datos);
      await ref.read(tokenStorageProvider).clear();
      await ref.read(authProvider.notifier).logout();
    } catch (e) {
      if (context.mounted) {
        ref.read(_eliminandoProvider.notifier).state = false;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensajeDeError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eliminando = ref.watch(_eliminandoProvider);
    return TextButton.icon(
      onPressed: eliminando ? null : () => _eliminar(context, ref),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.error,
      ),
      icon: eliminando
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.delete_forever_outlined),
      label: const Text('Eliminar mi cuenta'),
    );
  }
}
