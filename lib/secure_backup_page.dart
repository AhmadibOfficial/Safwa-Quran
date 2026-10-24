import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'encrypted_backup.dart';
import 'local_backup.dart';

/// Explicitly opt-in, password-protected clipboard backup screen.
/// Passwords are never stored as local preferences or copied to clipboard.
class SecureBackupPage extends StatefulWidget {
  const SecureBackupPage({super.key});
  @override
  State<SecureBackupPage> createState() => _SecureBackupPageState();
}

class _SecureBackupPageState extends State<SecureBackupPage> {
  final engine = const EncryptedSafwaBackup();
  final password = TextEditingController();
  final repeat = TextEditingController();
  final input = TextEditingController();
  SafwaBackupPreview? preview;
  String? inspectedHash;
  String message = '';
  bool busy = false;

  @override
  void dispose() {
    password.dispose();
    repeat.dispose();
    input.dispose();
    super.dispose();
  }

  void notice(String text) {
    if (mounted) setState(() => message = text);
  }

  String fingerprint() =>
      sha256.convert(utf8.encode(input.text)).toString();

  Future<void> export() async {
    if (busy) return;
    if (password.text.length <
            EncryptedSafwaBackup.minimumPassphraseLength ||
        password.text != repeat.text) {
      notice('Use a matching passphrase with at least 16 characters.');
      return;
    }
    final secret = password.text;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Copy encrypted backup?'),
        content: const Text(
          'The backup will be encrypted before it reaches the clipboard. '
          'The clipboard may still be observed or synced by other apps. '
          'Keep your passphrase separately. Without it, recovery is '
          'not possible. Use trusted private storage.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel')),
          FilledButton(
            key: const Key('secure_confirm_copy'),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Copy encrypted backup'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => busy = true);
    try {
      final encrypted = await engine.createEncryptedBackup(secret);
      await Clipboard.setData(ClipboardData(text: encrypted));
      password.clear();
      repeat.clear();
      notice('Encrypted backup copied. Store it privately.');
    } catch (_) {
      notice('Could not create encrypted backup.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> inspect() async {
    if (busy) return;
    final archiveText = input.text;
    final secret = password.text;
    setState(() {
      busy = true;
      preview = null;
      inspectedHash = null;
    });
    try {
      final result = await engine.inspect(archiveText, secret);
      if (!mounted || input.text != archiveText ||
          password.text != secret) return;
      setState(() {
        preview = result;
        inspectedHash = sha256.convert(utf8.encode(archiveText)).toString();
      });
      notice('Backup authenticated. No preferences changed.');
    } catch (_) {
      notice('Cannot open backup. Check passphrase and encrypted text.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> restore() async {
    if (busy || preview == null || inspectedHash != fingerprint()) {
      notice('Inspect the current encrypted backup first.');
      return;
    }
    final secret = password.text;
    final count = preview!.keyCount;
    final days = preview!.journalDays;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Replace Safwa local data?'),
        content: Text(
          'Replace local settings with $count keys, including $days '
          'Salah journal days? Recognized preferences absent from the '
          'backup will be removed. An interrupted restore may need '
          'the original backup. No Quran source or public release '
          'setting will be imported.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel')),
          FilledButton(
            key: const Key('secure_confirm_restore'),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Replace my settings'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    if (inspectedHash != fingerprint()) {
      notice('Backup changed. Inspect again.');
      return;
    }
    setState(() => busy = true);
    try {
      final restored = await engine.restore(
        input.text, secret, confirmed: true,
      );
      if (!mounted) return;
      setState(() {
        preview = null;
        inspectedHash = null;
        password.clear();
        input.clear();
      });
      notice('Restored $restored keys. Reopen screens to refresh.');
    } catch (_) {
      notice('Restore failed. Retain your original backup.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Protected Local Backup')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Keep your Safwa data private',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        const SizedBox(height: 12),
        const Text(
          'Encrypted backup covers bookmarks, local settings and optional '
          'Salah journal entries. Quran text, reviewer approval and '
          'release controls are excluded.',
        ),
        const SizedBox(height: 12),
        const Card(child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Choose a strong passphrase and keep it safe. A weak '
            'passphrase can still be guessed. Clipboard content may be '
            'accessible to another app or device. No password is '
            'saved, transmitted or recoverable by Safwa.',
          ),
        )),
        if (message.isNotEmpty)
          Semantics(
            liveRegion: true,
            child: Text(
              message,
              key: const Key('secure_backup_status'),
            ),
          ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('secure_backup_passphrase'),
          controller: password,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          maxLength: EncryptedSafwaBackup.maximumPassphraseLength,
          decoration: const InputDecoration(
            labelText: 'Backup passphrase',
            helperText: 'At least 16 characters for a new backup',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) {
            if (preview != null) {
              setState(() { preview = null; inspectedHash = null; });
            }
          },
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('secure_backup_confirm'),
          controller: repeat,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Confirm passphrase for export',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('secure_backup_export'),
          onPressed: busy ? null : export,
          icon: const Icon(Icons.lock_outline),
          label: const Text('Copy encrypted backup'),
        ),
        const SizedBox(height: 24),
        const Text(
          'Restore an encrypted backup',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        const SizedBox(height: 10),
        const Text(
          'Paste encrypted JSON here and enter its passphrase above. '
          'Inspection makes no changes to your data.',
        ),
        TextField(
          key: const Key('secure_backup_import'),
          controller: input,
          minLines: 3,
          maxLines: 5,
          maxLength: EncryptedSafwaBackup.maximumEnvelopeCharacters,
          decoration: const InputDecoration(
            labelText: 'Encrypted backup JSON',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) {
            if (preview != null) {
              setState(() { preview = null; inspectedHash = null; });
            }
          },
        ),
        OutlinedButton.icon(
          key: const Key('secure_backup_inspect'),
          onPressed: busy ? null : inspect,
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Inspect before restoring'),
        ),
        if (preview != null) ...[
          Semantics(
            label: 'Backup preview, no data changed',
            child: Card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Backup authenticated'),
                  Text('Preference keys: ' + preview!.keyCount.toString()),
                  Text('Journal days: ' + preview!.journalDays.toString()),
                  Text('Saved Surahs: ' + preview!.savedSurahs.toString()),
                  Text('Saved ayah refs: ' + preview!.savedAyat.toString()),
                ],
              ),
            )),
          ),
          FilledButton.icon(
            key: const Key('secure_backup_restore'),
            onPressed: busy ? null : restore,
            icon: const Icon(Icons.restore),
            label: const Text('Review replacement'),
          ),
        ],
        if (busy) const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 16),
        const Text(
          'Offline and opt-in only. The previous unencrypted backup '
          'screen is deprecated. Restore is not transactional and '
          'an interrupted operation can require an original backup.',
        ),
      ],
    ),
  );
}
