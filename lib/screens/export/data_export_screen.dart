import 'dart:convert';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/owner_data_backup.dart';

class DataExportScreen extends StatefulWidget {
  const DataExportScreen({super.key});

  @override
  State<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends State<DataExportScreen> {
  bool _isExporting = false;
  String? _statusMessage;
  bool _lastExportSucceeded = false;

  Future<void> _exportBackup() async {
    setState(() {
      _isExporting = true;
      _statusMessage = null;
    });

    try {
      final backup = await OwnerDataBackupService(Supabase.instance.client)
          .createBackup();
      final timestamp = backup.generatedAt.toIso8601String().replaceAll(
        ':',
        '-',
      );

      await FileSaver.instance.saveFile(
        name: 'rent-reminder-backup-$timestamp',
        bytes: Uint8List.fromList(utf8.encode(backup.toJsonString())),
        fileExtension: 'json',
        mimeType: MimeType.json,
      );

      if (!mounted) return;
      setState(() {
        _lastExportSucceeded = true;
        _statusMessage = 'Your owner data backup was downloaded successfully.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _lastExportSucceeded = false;
        _statusMessage = 'Backup export failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Owner data backup')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.backup_outlined, size: 56),
                const SizedBox(height: 20),
                Text(
                  'Download a JSON backup of your account data.',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'The backup includes your properties and tenant details, '
                  'property document metadata (not document file contents), '
                  'payments, reminder preferences, rent-credit allocations, '
                  'maintenance requests, property expenses, and recurring '
                  'expense rules. It contains private information; keep the '
                  'download somewhere secure.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isExporting ? null : _exportBackup,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: Text(
                    _isExporting ? 'Preparing backup…' : 'Download backup',
                  ),
                ),
                if (_statusMessage != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _statusMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _lastExportSucceeded
                            ? Colors.green.shade700
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
