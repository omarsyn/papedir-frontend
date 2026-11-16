import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cliente/main.dart';

void main() {
  testWidgets('muestra la pantalla de login al abrir la app', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PaPedirCliente()));

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
  });
}
