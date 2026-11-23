// API
export 'api/api_client.dart';
export 'api/api_exception.dart';
export 'api/auth_interceptor.dart';

// Auth
export 'auth/auth_provider.dart';
export 'auth/token_storage.dart';
export 'auth/screens/login_screen.dart';
export 'auth/screens/pending_review_screen.dart';

// Soporte
export 'soporte/tickets_provider.dart';
export 'soporte/screens/tickets_list_screen.dart';
export 'soporte/screens/create_ticket_screen.dart';
export 'soporte/screens/ticket_chat_screen.dart';

// Models
export 'models/comunes.dart';
export 'models/enums.dart';
export 'models/pedido.dart';
export 'models/ticket.dart';
export 'models/usuario.dart';
export 'models/viaje.dart';
export 'models/cartera_models.dart';
export 'models/vehiculo_model.dart';
export 'api/cartera_repository.dart';
export 'models/mensaje_pedido.dart';

// Push & Realtime
export 'push/fcm_service.dart';
export 'realtime/socket_service.dart';
export 'push/local_notifications_service.dart';

// Chat
export 'chat/chat_pedido_provider.dart';
export 'chat/chat_pedido_sheet.dart';

// Firebase (ACUERDOS §13): login con Google/GitHub/correo, preferencias en
// Firestore y foto de perfil en Storage.
export 'auth/screens/completar_registro_screen.dart';
export 'firebase/avatar.dart';
export 'firebase/firebase_login.dart';
export 'firebase/preferencias_remotas.dart';
