import 'package:core/core.dart' show TicketsListScreen, authProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/catalogos_provider.dart';
import '../../../core/formato.dart';
import '../../../core/models.dart';
import '../../../core/preferencias.dart';
import '../../../core/tienda_activa.dart';
import '../../../core/widgets/imagen_red.dart';
import '../../../core/widgets/mensajes.dart';
import '../../../core/widgets/vista_async.dart';
import '../../cartera/cartera_screen.dart';
import '../../home/navegacion_provider.dart';
import '../../perfil/perfil_screen.dart';
import '../../planes/planes_screen.dart';
import '../../sucursales/screens/mis_tiendas_screen.dart';
import '../providers/mi_tienda_provider.dart';

const _minutosPausa = [15, 30, 60, 120];
const _minutosPreparacion = [10, 15, 20, 30, 45, 60];

class MiTiendaScreen extends ConsumerWidget {
  const MiTiendaScreen({super.key});

  Future<void> _ejecutar(
    BuildContext context,
    Future<void> Function() accion, {
    String? exito,
  }) async {
    try {
      await accion();
      if (exito != null && context.mounted) mostrarMensaje(context, exito);
    } catch (e) {
      if (context.mounted) mostrarError(context, e);
    }
  }

  Future<int?> _elegirMinutos(
    BuildContext context,
    String titulo,
    List<int> opciones,
  ) {
    return showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(titulo),
        children: [
          for (final m in opciones)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, m),
              child: Text('$m minutos'),
            ),
        ],
      ),
    );
  }

  Future<void> _pausar(BuildContext context, WidgetRef ref) async {
    final m = await _elegirMinutos(context, 'Pausar pedidos', _minutosPausa);
    if (m == null || !context.mounted) return;
    await _ejecutar(
      context,
      () => ref.read(miTiendaProvider.notifier).pausar(m),
      exito: 'No recibirás pedidos durante $m minutos',
    );
  }

  Future<void> _tiempo(BuildContext context, WidgetRef ref) async {
    final m = await _elegirMinutos(
      context,
      'Tiempo de preparación',
      _minutosPreparacion,
    );
    if (m == null || !context.mounted) return;
    await _ejecutar(
      context,
      () => ref.read(miTiendaProvider.notifier).cambiarTiempo(m),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tienda = ref.watch(miTiendaProvider);
    final usuario = ref.watch(authProvider).usuario;
    final categorias =
        ref.watch(categoriasProvider).valueOrNull ?? categoriasBase;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi tienda')),
      body: VistaAsync<MiTienda>(
        valor: tienda,
        onReintentar: () => ref.invalidate(miTiendaProvider),
        builder: (t) {
          final notifier = ref.read(miTiendaProvider.notifier);
          return RefreshIndicator(
            onRefresh: () =>
                recargarSilencioso(() => ref.refresh(miTiendaProvider.future)),
            child: ListView(
              children: [
                _Encabezado(
                  tienda: t,
                  categoria: nombreCategoria(categorias, t.categoria),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  secondary: const Icon(Icons.power_settings_new),
                  title: const Text('Tienda abierta'),
                  subtitle: const Text('Apágalo cuando cierres el negocio'),
                  value: t.abierta,
                  onChanged: (v) =>
                      _ejecutar(context, () => notifier.cambiarAbierta(v)),
                ),
                if (t.pausada)
                  ListTile(
                    leading: const Icon(Icons.pause_circle),
                    title: Text('Pausada hasta las ${hora(t.pausadaHasta!)}'),
                    trailing: TextButton(
                      onPressed: () => _ejecutar(
                        context,
                        notifier.quitarPausa,
                        exito: 'Vuelves a recibir pedidos',
                      ),
                      child: const Text('Reanudar'),
                    ),
                  )
                else
                  ListTile(
                    leading: const Icon(Icons.pause_circle_outline),
                    title: const Text('Pausar pedidos un rato'),
                    subtitle: const Text(
                      'Si la cocina está saturada (o agita el teléfono)',
                    ),
                    onTap: t.abierta ? () => _pausar(context, ref) : null,
                  ),
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('Tiempo de preparación'),
                  subtitle: Text('${t.tiempoPreparacionMin} min'),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _tiempo(context, ref),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(usuario?.nombre ?? ''),
                  subtitle: Text(usuario?.email ?? ''),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PerfilScreen(),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Tema'),
                  subtitle: Text(etiquetaTema(ref.watch(temaProvider))),
                  onTap: () => elegirTema(context, ref),
                ),
                ListTile(
                  leading: const Icon(Icons.workspace_premium_outlined),
                  title: const Text('Mi plan'),
                  subtitle: const Text(
                    'Básico, Pro o Premium: baja tu comisión',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PlanesScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.store_mall_directory_outlined),
                  title: const Text('Mis tiendas'),
                  subtitle: const Text('Cambiar de tienda o agregar otra'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MisTiendasScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: const Text('Mi cartera'),
                  subtitle: const Text('Saldo con PaPedir y movimientos'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CarteraScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.support_agent),
                  title: const Text('Soporte'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TicketsListScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Cerrar sesión'),
                  onTap: () async {
                    ref.invalidate(indiceNavegacionProvider);
                    await ref.read(tiendaActivaProvider.notifier).elegir(null);
                    await ref.read(authProvider.notifier).logout();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Tarjeta de color con la foto, el nombre y el estado de la tienda.
class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.tienda, required this.categoria});

  final MiTienda tienda;
  final String categoria;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final t = tienda;
    final activa = t.abiertaAhora;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            esquema.primary,
            Color.lerp(esquema.primary, Colors.black, 0.4)!,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipOval(
                  child: ImagenRed(
                    url: t.imagenUrl,
                    icono: iconoCategoria(t.categoria),
                    ancho: 60,
                    alto: 60,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      categoria,
                      style: tema.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            t.direccion,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tema.textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 10,
                      color: activa ? Colors.green.shade600 : esquema.error,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      activa ? 'Recibiendo pedidos' : 'No recibes pedidos',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (t.calificacion != null) ...[
                const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 2),
                Text(
                  t.calificacion!.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
