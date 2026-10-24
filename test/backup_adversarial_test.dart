import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safwa_quran/encrypted_backup.dart';
import 'package:safwa_quran/local_backup.dart';

const testPassphrase = 'SAFWA-014 strong test passphrase #2026';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({
        'safwa_prayer_city': 'kaduna',
      }));

  test('fresh exports use distinct salts, nonces and ciphertext', () async {
    const backup = EncryptedSafwaBackup();
    final first = jsonDecode(await backup.createEncryptedBackup(testPassphrase))
        as Map<String, dynamic>;
    final second = jsonDecode(await backup.createEncryptedBackup(testPassphrase))
        as Map<String, dynamic>;
    expect(first['salt'], isNot(second['salt']));
    expect(first['nonce'], isNot(second['nonce']));
    expect(first['ciphertext'], isNot(second['ciphertext']));
    expect(base64Decode(first['salt'] as String), hasLength(16));
    expect(base64Decode(first['nonce'] as String), hasLength(12));
    expect(base64Decode(first['tag'] as String), hasLength(16));
  });

  test('envelope schema and KDF cannot be arbitrarily replaced', () async {
    const backup = EncryptedSafwaBackup();
    final source = jsonDecode(await backup.createEncryptedBackup(testPassphrase))
        as Map<String, dynamic>;
    final attempts = <Map<String, dynamic>>[
      {...source, 'version': 2},
      {...source, 'kdf': 'argon2id-m999999-t999-p9'},
      {...source, 'format': 'unknown'},
      {...source, 'role': 'public-release'},
      {...source}..remove('tag'),
      {...source, 'salt': 'AA=='},
      {...source, 'nonce': 'AA=='},
      {...source, 'tag': 'AA=='},
      {...source, 'ciphertext': '@@invalid@@'},
    ];
    for (final envelope in attempts) {
      await expectLater(
        backup.inspect(jsonEncode(envelope), testPassphrase),
        throwsFormatException,
      );
    }
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('safwa_prayer_city'), 'kaduna');
    expect(prefs.containsKey(LocalSafwaBackup.recoveryKey), isFalse);
  });

  test('authenticated ciphertext, nonce, salt and tag tampering is rejected',
      () async {
    const backup = EncryptedSafwaBackup();
    final source = jsonDecode(await backup.createEncryptedBackup(testPassphrase))
        as Map<String, dynamic>;
    for (final field in ['ciphertext', 'nonce', 'salt', 'tag']) {
      final changed = Map<String, dynamic>.from(source);
      final bytes = base64Decode(changed[field] as String);
      bytes[0] ^= 1;
      changed[field] = base64Encode(bytes);
      await expectLater(
        backup.inspect(jsonEncode(changed), testPassphrase),
        throwsFormatException,
      );
    }
  });

  test('malformed and oversized envelopes fail closed', () async {
    const backup = EncryptedSafwaBackup();
    for (final document in [
      '',
      '{bad-json',
      '[]',
      '{}',
      'x' * (EncryptedSafwaBackup.maximumEnvelopeCharacters + 1),
    ]) {
      await expectLater(
        backup.inspect(document, testPassphrase),
        throwsFormatException,
      );
    }
    await expectLater(
      backup.inspect(
        await backup.createEncryptedBackup(testPassphrase),
        'wrong password but long enough',
      ),
      throwsFormatException,
    );
  });

  test('invalid per-Surah verse references are rejected on export', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_ayat', ['1:8']);
    await expectLater(
      const LocalSafwaBackup().createBackupJson(),
      throwsFormatException,
    );
    await prefs.setStringList('saved_ayat', ['2:286']);
    expect(
      const LocalSafwaBackup().inspect(
        await const LocalSafwaBackup().createBackupJson(),
      ).savedAyat,
      1,
    );
    await prefs.setString('last_read', '114:7');
    await expectLater(
      const LocalSafwaBackup().createBackupJson(),
      throwsFormatException,
    );
  });

  test('encrypted restore requires confirmation even for valid ciphertext',
      () async {
    const backup = EncryptedSafwaBackup();
    final payload = await backup.createEncryptedBackup(testPassphrase);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('safwa_prayer_city', 'kano');
    await expectLater(
      backup.restore(payload, testPassphrase, confirmed: false),
      throwsStateError,
    );
    expect(prefs.getString('safwa_prayer_city'), 'kano');
    expect(prefs.containsKey(LocalSafwaBackup.recoveryKey), isFalse);
  });
}
