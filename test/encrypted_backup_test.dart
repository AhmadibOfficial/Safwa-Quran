import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safwa_quran/encrypted_backup.dart';
import 'package:safwa_quran/secure_backup_page.dart';

const testPassword = 'a long passphrase for Safwa #2026';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('encrypted export never exposes plaintext settings', () async {
    SharedPreferences.setMockInitialValues({
      'safwa_prayer_city': 'kaduna',
      'safwa_salah_2026-10-24': <String>['Fajr'],
    });
    const service = EncryptedSafwaBackup();
    final encrypted = await service.createEncryptedBackup(testPassword);
    final data = jsonDecode(encrypted) as Map<String, dynamic>;
    expect(data['format'], EncryptedSafwaBackup.format);
    expect(data['version'], EncryptedSafwaBackup.version);
    expect(data['kdf'], EncryptedSafwaBackup.kdf);
    expect(base64Decode(data['salt'] as String).length, 16);
    expect(base64Decode(data['nonce'] as String).length, 12);
    expect(base64Decode(data['tag'] as String).length, 16);
    expect(encrypted, isNot(contains('kaduna')));
    expect(encrypted, isNot(contains('Fajr')));
    expect(encrypted, isNot(contains(testPassword)));

    final preview = await service.inspect(encrypted, testPassword);
    expect(preview.keyCount, 2);
    expect(preview.journalDays, 1);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('safwa_prayer_city', 'kano');
    final restored = await service.restore(
      encrypted, testPassword, confirmed: true,
    );
    expect(restored, 2);
    expect(prefs.getString('safwa_prayer_city'), 'kaduna');
    expect(
      prefs.getStringList('safwa_salah_2026-10-24'), ['Fajr'],
    );
  });

  test('incorrect password and modified ciphertext cannot be opened',
      () async {
    const service = EncryptedSafwaBackup();
    final encrypted = await service.createEncryptedBackup(testPassword);
    await expectLater(
      service.inspect(encrypted, 'incorrect but lengthy passphrase'),
      throwsFormatException,
    );
    final doc = jsonDecode(encrypted) as Map<String, dynamic>;
    final tag = base64Decode(doc['tag'] as String);
    tag[0] ^= 1;
    doc['tag'] = base64Encode(tag);
    await expectLater(
      service.inspect(jsonEncode(doc), testPassword),
      throwsFormatException,
    );
  });

  test('unapproved restore and unknown format fail without mutation',
      () async {
    const service = EncryptedSafwaBackup();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('safwa_prayer_city', 'lagos');
    await expectLater(
      service.restore('{}', testPassword, confirmed: false),
      throwsStateError,
    );
    expect(prefs.getString('safwa_prayer_city'), 'lagos');
    await expectLater(
      service.inspect('{}', testPassword),
      throwsFormatException,
    );
    await expectLater(
      service.createEncryptedBackup('short'),
      throwsFormatException,
    );
  });

  testWidgets('secure screen shows protected export and gated restore',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SecureBackupPage()));
    await tester.pumpAndSettle();
    expect(find.text('Protected Local Backup'), findsOneWidget);
    expect(find.byKey(const Key('secure_backup_passphrase')), findsOneWidget);
    final button = find.byKey(const Key('secure_backup_export'));
    await tester.scrollUntilVisible(
      button, 140, scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(button, findsOneWidget);
    expect(find.byKey(const Key('secure_backup_restore')), findsNothing);
  });

  testWidgets('password input is obscured', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SecureBackupPage()));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(
      find.byKey(const Key('secure_backup_passphrase')),
    );
    expect(field.obscureText, isTrue);
    expect(field.enableSuggestions, isFalse);
    expect(field.autocorrect, isFalse);
  });
}
