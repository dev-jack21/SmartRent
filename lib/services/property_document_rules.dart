class PropertyDocumentRules {
  static const maxFileSizeBytes = 20 * 1024 * 1024;

  static const mimeTypesByExtension = <String, String>{
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
  };

  static List<String> get allowedExtensions =>
      mimeTypesByExtension.keys.toList(growable: false);

  static String? validationError({
    required String fileName,
    required int fileSizeBytes,
  }) {
    final extension = extensionOf(fileName);
    if (!mimeTypesByExtension.containsKey(extension)) {
      return 'Choose a PDF, Word document, JPG, or PNG file.';
    }
    if (fileSizeBytes <= 0) {
      return 'The selected file is empty.';
    }
    if (fileSizeBytes > maxFileSizeBytes) {
      return 'The file is too large. Maximum size is 20 MB.';
    }
    return null;
  }

  static String extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  static String displaySize(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).ceil()} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
