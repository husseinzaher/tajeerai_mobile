import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/features/auth/presentation/helpers/login_identifier_input_formatter.dart';

void main() {
  const LoginIdentifierInputFormatter formatter =
      LoginIdentifierInputFormatter();

  TextEditingValue format(String before, String after) {
    return formatter.formatEditUpdate(
      TextEditingValue(text: before),
      TextEditingValue(text: after),
    );
  }

  test('allows email and phone characters', () {
    expect(format('', 'ada@demo.test').text, 'ada@demo.test');
    expect(format('', '+201008755187').text, '+201008755187');
  });

  test('rejects Arabic characters', () {
    expect(format('', 'مرحبا').text, '');
    expect(format('ada@demo.test', 'ada@demo.testا').text, 'ada@demo.test');
  });
}
