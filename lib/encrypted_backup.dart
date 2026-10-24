import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'local_backup.dart';

/// Password-protected envelope for Safwa's *allowlisted* preferences.
///
/// Fixed KDF parameters are never accepted from untrusted backup metadata.
/// AES-GCM authenticates the payload; Argon2id slows offline password guesses.
/// Neither can make a weak user password secure or prevent OS clipboard leaks.
class EncryptedSafwaBackup {
  const EncryptedSafwaBackup();

  static const format = 'safwa-encrypted-preferences';
  static const version = 1;
  static const kdf = 'argon2id-m19456-t2-p1';
  static const maximumEnvelopeCharacters = 1600000;
  static const minimumPassphraseLength = 16;
  static const maximumPassphraseLength = 256;

  static final _argon2 = Argon2id(
    memory: 19456,
    parallelism: 1,
    iterations: 2,
    hashLength: 32,
  );
  static final _cipher = AesGcm.with256bits();
  static final _metadata = utf8.encode(
    'Safwa encrypted preferences | version 1 | Argon2id 19456 KiB 2x | AES-256-GCM',
  );
  static final _base64Bytes = RegExp(r'^[A-Za-z0-9+/]*={0,2}$');

  static void _validatePassword(String password, {bool exporting = false}) {
    if (password.isEmpty ||
        password.length > maximumPassphraseLength ||
        (exporting && password.length < minimumPassphraseLength)) {
      throw const FormatException('Invalid backup passphrase length');
    }
  }

  static Uint8List _randomSalt() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
  }

  static List<int> _decodeField(Object? encoded, int? requiredBytes) {
    if (encoded is! String || encoded.isEmpty ||
        encoded.length > maximumEnvelopeCharacters ||
        !_base64Bytes.hasMatch(encoded)) {
      throw const FormatException('Malformed encrypted backup');
    }
    final result = base64.decode(encoded);
    if (requiredBytes != null && result.length != requiredBytes) {
      throw const FormatException('Malformed encrypted backup length');
    }
    return result;
  }

  static Future<SecretKey> _key(String passphrase, List<int> salt) {
    return _argon2.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );
  }

  Future<String> createEncryptedBackup(String passphrase) async {
    _validatePassword(passphrase, exporting: true);
    final plaintext = await const LocalSafwaBackup().createBackupJson();
    final salt = _randomSalt();
    final key = await _key(passphrase, salt);
    final box = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      aad: _metadata,
    );
    final envelope = {
      'format': format,
      'version': version,
      'kdf': kdf,
      'salt': base64.encode(salt),
      'nonce': base64.encode(box.nonce),
      'ciphertext': base64.encode(box.cipherText),
      'tag': base64.encode(box.mac.bytes),
    };
    final output = jsonEncode(envelope);
    if (output.length > maximumEnvelopeCharacters) {
      throw const FormatException('Encrypted backup too large');
    }
    return output;
  }

  Future<String> _decrypt(String envelope, String passphrase) async {
    _validatePassword(passphrase);
    if (envelope.isEmpty ||
        envelope.length > maximumEnvelopeCharacters) {
      throw const FormatException('Invalid encrypted backup size');
    }
    final decoded = jsonDecode(envelope);
    if (decoded is! Map<String, dynamic> ||
        decoded.length != 7 ||
        decoded['format'] != format ||
        decoded['version'] != version ||
        decoded['kdf'] != kdf ||
        !decoded.keys.toSet().containsAll({
          'format', 'version', 'kdf', 'salt', 'nonce', 'ciphertext', 'tag',
        })) {
      throw const FormatException('Unsupported encrypted backup version');
    }
    final salt = _decodeField(decoded['salt'], 16);
    final nonce = _decodeField(decoded['nonce'], 12);
    final cipherText = _decodeField(decoded['ciphertext'], null);
    final tag = _decodeField(decoded['tag'], 16);
    // Reject untrusted metadata/lengths *before* expensive derivation.
    if (cipherText.length > LocalSafwaBackup.maximumCharacters * 2) {
      throw const FormatException('Encrypted backup payload too large');
    }
    try {
      final key = await _key(passphrase, salt);
      final bytes = await _cipher.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(tag)),
        secretKey: key,
        aad: _metadata,
      );
      final text = utf8.decode(bytes);
      if (text.length > LocalSafwaBackup.maximumCharacters) {
        throw const FormatException('Decrypted preferences too large');
      }
      return text;
    } on SecretBoxAuthenticationError {
      throw const FormatException('Incorrect passphrase or modified backup');
    }
  }

  Future<SafwaBackupPreview> inspect(
    String encryptedJson,
    String passphrase,
  ) async {
    final plaintext = await _decrypt(encryptedJson, passphrase);
    return const LocalSafwaBackup().inspect(plaintext);
  }

  Future<int> restore(
    String encryptedJson,
    String passphrase, {
    required bool confirmed,
  }) async {
    if (!confirmed) {
      throw StateError('Explicit user consent required');
    }
    final plaintext = await _decrypt(encryptedJson, passphrase);
    return const LocalSafwaBackup().restoreBackup(
      plaintext,
      confirmed: true,
    );
  }
}
