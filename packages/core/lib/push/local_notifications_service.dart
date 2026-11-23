import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationsService {
  LocalNotificationsService._();
  static final LocalNotificationsService instance = LocalNotificationsService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _canalPedidos =
      AndroidNotificationChannel(
    'papedir_pedidos_alta',
    'Nuevos pedidos',
    description: 'Alertas sonoras cuando hay un pedido disponible para entregar',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel _canalCuenta =
      AndroidNotificationChannel(
    'papedir_cuenta_seguridad',
    'Cuenta y seguridad',
    description: 'Avisos de aprobación de cuenta y cambios de contraseña',
    importance: Importance.high,
    playSound: true,
  );

  bool _inicializado = false;

  Future<void> inicializar({
    void Function(String? payload)? onTapNotificacion,
  }) async {
    if (_inicializado) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
      onDidReceiveNotificationResponse: (details) {
        onTapNotificacion?.call(details.payload);
      },
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.createNotificationChannel(_canalPedidos);
    await androidPlugin?.createNotificationChannel(_canalCuenta);

    _inicializado = true;
  }

  Future<void> mostrarNuevoPedido({
    required String folio,
    required String tienda,
    required double ganancia,
  }) async {
    await _plugin.show(
      id: folio.hashCode,
      title: 'Nuevo pedido disponible · $folio',
      body: '$tienda · Ganancia estimada: \$${ganancia.toStringAsFixed(2)}',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _canalPedidos.id,
          _canalPedidos.name,
          channelDescription: _canalPedidos.description,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.call,
        ),
        iOS: const DarwinNotificationDetails(presentSound: true),
      ),
      payload: '/mapa',
    );
  }

  Future<void> mostrarCuentaAprobada() async {
    await _plugin.show(
      id: 1001,
      title: '¡Tu cuenta fue aprobada!',
      body: 'Ya puedes conectarte y empezar a recibir pedidos en PaPedir.',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _canalCuenta.id,
          _canalCuenta.name,
          channelDescription: _canalCuenta.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(presentSound: true),
      ),
      payload: '/permisos',
    );
  }

  Future<void> mostrarPasswordActualizada() async {
    await _plugin.show(
      id: 1002,
      title: 'Contraseña actualizada',
      body: 'La contraseña de tu cuenta PaPedir se cambió correctamente.',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _canalCuenta.id,
          _canalCuenta.name,
          channelDescription: _canalCuenta.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(presentSound: true),
      ),
      payload: '/login',
    );
  }

  Future<void> mostrarBienvenidaRepartidor() async {
    await _plugin.show(
      id: 1003,
      title: 'Bienvenido a Papedir Repartidor',
      body: 'Conéctate para recibir pedidos',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _canalCuenta.id,
          _canalCuenta.name,
          channelDescription: _canalCuenta.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(presentSound: true),
      ),
      payload: '/mapa',
    );
  }
}