import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/property_document_rules.dart';

class ManagePropertyDocumentsScreen extends StatefulWidget {
  const ManagePropertyDocumentsScreen({super.key});

  @override
  State<ManagePropertyDocumentsScreen> createState() =>
      _ManagePropertyDocumentsScreenState();
}

class _ManagePropertyDocumentsScreenState
    extends State<ManagePropertyDocumentsScreen> {
  static const _bucketName = 'property-documents';

  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _properties = [];
  List<Map<String, dynamic>> _documents = [];
  String? _selectedPropertyId;
  String? _loadError;
  String? _workingDocumentId;
  bool _isLoading = true;
  bool _isUploading = false;

  List<Map<String, dynamic>> get _selectedDocuments => _documents
      .where((item) => item['property_id']?.toString() == _selectedPropertyId)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'You are not logged in. Please log in again.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        _supabase
            .from('properties')
            .select('id, name')
            .eq('user_id', user.id)
            .order('name'),
        _supabase
            .from('property_documents')
            .select(
              'id, property_id, original_name, content_type, file_size, storage_path, created_at',
            )
            .eq('user_id', user.id)
            .order('created_at', ascending: false),
      ]);
      if (!mounted) return;

      final properties = List<Map<String, dynamic>>.from(results[0]);
      setState(() {
        _properties = properties;
        _documents = List<Map<String, dynamic>>.from(results[1]);
        if (!properties.any(
          (item) => item['id'].toString() == _selectedPropertyId,
        )) {
          _selectedPropertyId = properties.isEmpty
              ? null
              : properties.first['id'].toString();
        }
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError =
            'Could not load documents: ${error.message}. Apply the property documents migration and retry.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Could not load documents: $error';
      });
    }
  }

  Future<void> _uploadDocument() async {
    final user = _supabase.auth.currentUser;
    final propertyId = _selectedPropertyId;
    if (user == null) {
      _showMessage('You are not logged in. Please log in again.');
      return;
    }
    if (propertyId == null ||
        !_properties.any((item) => item['id'].toString() == propertyId)) {
      _showMessage('Select one of your properties first.');
      return;
    }

    try {
      final pickedFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: PropertyDocumentRules.allowedExtensions,
      );
      if (pickedFiles.isEmpty || !mounted) return;
      final file = pickedFiles.single;
      final fileSize = file.lengthSync() ?? await file.length();
      if (fileSize == null) {
        _showMessage(
          'Could not read the selected file size. Please try again.',
        );
        return;
      }
      final validationError = PropertyDocumentRules.validationError(
        fileName: file.name,
        fileSizeBytes: fileSize,
      );
      if (validationError != null) {
        _showMessage(validationError);
        return;
      }
      final Uint8List bytes = await file.readAsBytes();
      if (bytes.length != fileSize) {
        _showMessage('Could not read the selected file. Please try again.');
        return;
      }

      setState(() => _isUploading = true);
      final extension = PropertyDocumentRules.extensionOf(file.name);
      final contentType =
          PropertyDocumentRules.mimeTypesByExtension[extension]!;
      String? documentId;
      String? storagePath;
      try {
        final row = await _supabase
            .from('property_documents')
            .insert({
              'user_id': user.id,
              'property_id': propertyId,
              'original_name': file.name,
              'content_type': contentType,
              'file_size': bytes.length,
            })
            .select('id')
            .single();
        documentId = row['id'].toString();
        final safeName = file.name
            .replaceAll(RegExp(r'[/\\]'), '_')
            .replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_')
            .trim();
        storagePath =
            '$propertyId/$documentId/'
            '${safeName.isEmpty ? 'document.$extension' : safeName}';

        await _supabase.storage
            .from(_bucketName)
            .uploadBinary(
              storagePath,
              bytes,
              fileOptions: FileOptions(contentType: contentType),
            );
        await _supabase
            .from('property_documents')
            .update({'storage_path': storagePath})
            .eq('id', documentId)
            .eq('user_id', user.id);
        if (!mounted) return;
        await _loadData();
        if (mounted) _showMessage('Document uploaded.');
      } catch (error) {
        final cleanupErrors = <String>[];
        if (storagePath != null) {
          try {
            await _supabase.storage.from(_bucketName).remove([storagePath]);
          } catch (cleanupError) {
            cleanupErrors.add('storage cleanup failed: $cleanupError');
          }
        }
        if (documentId != null) {
          try {
            await _supabase
                .from('property_documents')
                .delete()
                .eq('id', documentId)
                .eq('user_id', user.id);
          } catch (cleanupError) {
            cleanupErrors.add('metadata cleanup failed: $cleanupError');
          }
        }
        if (cleanupErrors.isNotEmpty) {
          throw StateError(
            'Upload failed: $error. ${cleanupErrors.join('; ')}.',
          );
        }
        rethrow;
      }
    } on PostgrestException catch (error) {
      if (mounted) _showMessage('Could not upload document: ${error.message}');
    } catch (error) {
      if (mounted) _showMessage('Could not upload document: $error');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _downloadDocument(Map<String, dynamic> document) async {
    final id = document['id']?.toString();
    final path = document['storage_path']?.toString();
    final originalName = document['original_name']?.toString() ?? 'document';
    if (id == null || path == null || path.isEmpty) {
      _showMessage('This document is not available to download.');
      return;
    }

    setState(() => _workingDocumentId = id);
    try {
      final bytes = await _supabase.storage.from(_bucketName).download(path);
      final extension = PropertyDocumentRules.extensionOf(originalName);
      final name = extension.isEmpty
          ? originalName
          : originalName.substring(
              0,
              originalName.length - extension.length - 1,
            );
      await FileSaver.instance.saveFile(
        name: name,
        bytes: bytes,
        fileExtension: extension,
        mimeType: MimeType.custom,
        customMimeType: document['content_type']?.toString(),
      );
      if (mounted) _showMessage('Document downloaded.');
    } catch (error) {
      if (mounted) _showMessage('Could not download document: $error');
    } finally {
      if (mounted) setState(() => _workingDocumentId = null);
    }
  }

  Future<void> _deleteDocument(Map<String, dynamic> document) async {
    final id = document['id']?.toString();
    if (id == null) return;
    final path = document['storage_path']?.toString();
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text(
          '“${document['original_name'] ?? 'Document'}” will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;

    setState(() => _workingDocumentId = id);
    try {
      if (path != null && path.isNotEmpty) {
        await _supabase.storage.from(_bucketName).remove([path]);
      }
      final user = _supabase.auth.currentUser;
      if (user == null) throw StateError('You are not logged in.');
      await _supabase
          .from('property_documents')
          .delete()
          .eq('id', id)
          .eq('user_id', user.id);
      if (!mounted) return;
      setState(
        () => _documents.removeWhere((item) => item['id'].toString() == id),
      );
      _showMessage('Document deleted.');
    } catch (error) {
      if (mounted) _showMessage('Could not delete document: $error');
    } finally {
      if (mounted) setState(() => _workingDocumentId = null);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Property documents')),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _loadError != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_loadError!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        : _buildDocuments(),
  );

  Widget _buildDocuments() {
    if (_properties.isEmpty) {
      return const Center(
        child: Text('Add a property before uploading documents.'),
      );
    }
    final documents = _selectedDocuments;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedPropertyId,
          decoration: const InputDecoration(
            labelText: 'Property',
            border: OutlineInputBorder(),
          ),
          items: _properties
              .map(
                (property) => DropdownMenuItem(
                  value: property['id'].toString(),
                  child: Text(property['name']?.toString() ?? 'Property'),
                ),
              )
              .toList(),
          onChanged: _isUploading
              ? null
              : (value) => setState(() => _selectedPropertyId = value),
        ),
        const SizedBox(height: 12),
        const Text('PDF, Word, JPG, or PNG · Maximum 20 MB per file'),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _isUploading ? null : _uploadDocument,
          icon: _isUploading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file),
          label: Text(_isUploading ? 'Uploading…' : 'Upload document'),
        ),
        const SizedBox(height: 20),
        if (documents.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No documents for this property yet.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...documents.map(_documentTile),
      ],
    );
  }

  Widget _documentTile(Map<String, dynamic> document) {
    final id = document['id'].toString();
    final isWorking = id == _workingDocumentId;
    final size = int.tryParse(document['file_size']?.toString() ?? '') ?? 0;
    final createdAt = DateTime.tryParse(
      document['created_at']?.toString() ?? '',
    );
    final dateLabel = createdAt == null
        ? ''
        : ' · ${createdAt.day}/${createdAt.month}/${createdAt.year}';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.description_outlined),
        title: Text(
          document['original_name']?.toString() ?? 'Document',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('${PropertyDocumentRules.displaySize(size)}$dateLabel'),
        trailing: isWorking
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Wrap(
                children: [
                  IconButton(
                    tooltip: 'Download document',
                    onPressed: () => _downloadDocument(document),
                    icon: const Icon(Icons.download_outlined),
                  ),
                  IconButton(
                    tooltip: 'Delete document',
                    onPressed: () => _deleteDocument(document),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
      ),
    );
  }
}
