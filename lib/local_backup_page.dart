import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'local_backup.dart';

const _navy = Color(0xFF142547);

/// No cloud or file access. Both clipboard export and replacement require
/// explicit user interaction and a privacy warning.
class SafwaBackupPage extends StatefulWidget {
  const SafwaBackupPage({super.key});

  @override
  State<SafwaBackupPage> createState() => _SafwaBackupPageState();
}

class _SafwaBackupPageState extends State<SafwaBackupPage> {
  final service = const LocalSafwaBackup();
  final input = TextEditingController();
  SafwaBackupPreview? preview;
  bool busy = false;

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _export() async {
    if (busy) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Copy unencrypted backup?'),
        content: const Text(
          'This includes private Salah journal entries, bookmarks and '
          'settings. Clipboard content may be read by other apps or synced '
          'to other devices. Only use a trusted device and secure storage. '
          'SHA-256 checks for changes but does not encrypt or authenticate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('backup_confirm_copy'),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Copy backup'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => busy = true);
    try {
      final archive = await service.createBackupJson();
      await Clipboard.setData(ClipboardData(text: archive));
      _notice('Backup copied. Store it privately; clipboard is not secure.');
    } catch (_) {
      _notice('Backup could not be created or copied.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _inspect() {
    if (busy) return;
    try {
      final result = service.inspect(input.text);
      setState(() => preview = result);
      _notice('Backup checksum checked. No preferences changed.');
    } catch (_) {
      setState(() => preview = null);
      _notice('Backup invalid, too large or checksum mismatch.');
    }
  }

  Future<void> _restore() async {
    if (busy || preview == null) return;
    SafwaBackupPreview candidate;
    try {
      candidate = service.inspect(input.text);
      if (candidate.sha256 != preview!.sha256) {
        throw const FormatException('Backup changed');
      }
    } catch (_) {
      setState(() => preview = null);
      _notice('Backup changed. Inspect again.');
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Replace local Safwa preferences?'),
        content: Text(
          'Restore ${candidate.keyCount} entries, including '
          '${candidate.journalDays} journal days? '
          'Recognized Safwa preferences absent in this backup will '
          'be removed. An interrupted restore can require your original '
          'backup for recovery. Only import a backup you trust; the checksum '
          'does NOT authenticate its author. No Quran source or release '
          'authorization can be restored through this screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('backup_confirm_restore'),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Replace my data'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => busy = true);
    try {
      final count = await service.restoreBackup(
        input.text, confirmed: true,
      );
      if (!mounted) return;
      setState(() => preview = null);
      input.clear();
      _notice(
        'Restored $count preferences. Reopen Safwa screens '
        'to refresh their displayed settings.',
      );
    } catch (_) {
      _notice('Restore failed. Keep your original backup for recovery.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Local Backup & Restore')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text(
        'Keep a private copy of your settings',
        style: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w800, color: _navy,
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'Export bookmarks, saved personal preferences and optional Salah '
        'journal records only. Quran text and approval/release controls '
        'are NEVER part of these backups.',
      ),
      const SizedBox(height: 16),
      const Card(child: Padding(
        padding: EdgeInsets.all(18),
        child: Text(
          'Warning: backups are NOT encrypted. Clipboard data can be '
          'exposed to other software and device sync. Do not paste backups '
          'into public chats or websites. SHA-256 detects changes but '
          'does not prove that a backup came from a trusted person.',
        ),
      )),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        key: const Key('backup_export'),
        onPressed: busy ? null : _export,
        icon: const Icon(Icons.copy_outlined),
        label: const Text('Copy unencrypted backup (review warning)'),
      ),
      const SizedBox(height: 24),
      const Text(
        'Import an existing Safwa backup',
        style: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w700, color: _navy,
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        key: const Key('backup_import_text'),
        controller: input,
        minLines: 3,
        maxLines: 6,
        maxLength: LocalSafwaBackup.maximumCharacters,
        decoration: const InputDecoration(
          labelText: 'Paste backup JSON',
          border: OutlineInputBorder(),
        ),
        onChanged: (_) {
          if (preview != null) setState(() => preview = null);
        },
      ),
      OutlinedButton.icon(
        key: const Key('backup_inspect'),
        onPressed: busy ? null : _inspect,
        icon: const Icon(Icons.fact_check_outlined),
        label: const Text('Inspect backup — no data changes'),
      ),
      if (preview != null) ...[
        const SizedBox(height: 14),
        Card(child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Backup structure and checksum valid',
                style: TextStyle(
                  color: _navy, fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text('Stored keys: ${preview!.keyCount}'),
              Text('Journal days: ${preview!.journalDays}'),
              Text('Saved Surahs: ${preview!.savedSurahs}'),
              Text('Saved ayah references: ${preview!.savedAyat}'),
              const Text('Origin NOT authenticated.'),
            ],
          ),
        )),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('backup_restore'),
          onPressed: busy ? null : _restore,
          icon: const Icon(Icons.restore),
          label: const Text('Review and restore'),
        ),
      ],
      const SizedBox(height: 20),
      const Text(
        'No automatic backups or uploads are performed. '
        'Restored values take effect when affected app screens are reopened.',
        style: TextStyle(fontSize: 12, color: _navy),
      ),
    ]),
  );
}
