import 'package:flutter_test/flutter_test.dart';
import 'package:proj/security/authorization/roles.dart';

void main() {
  group('UserRole parsing', () {
    test('accepts enum values and stable string values', () {
      expect(parseUserRole(UserRole.farmOwner), UserRole.farmOwner);
      expect(parseUserRole('farmOwner'), UserRole.farmOwner);
      expect(parseUserRole('Farm Owner'), UserRole.farmOwner);
      expect(parseUserRole(null), UserRole.viewer);
    });

    test('exposes a safe value and label without relying on enum.name', () {
      expect(UserRole.farmOwner.value, 'farmOwner');
      expect(UserRole.farmManager.label, 'Farm manager');
    });
  });
}
