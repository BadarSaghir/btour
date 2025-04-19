// FILE: lib/models/document_attachment.dart
import 'package:path/path.dart'; // For basename

class DocumentAttachmentFields {
  static final List<String> values = [
    id,
    expenseId,
    filename,
    originalFilename,
    mimeType,
    createdAt,
  ];

  static const String tableName = 'document_attachments';
  static const String id = '_id';
  static const String expenseId = 'expenseId';
  static const String filename = 'filename'; // Stored unique filename
  static const String originalFilename =
      'originalFilename'; // User-visible filename
  static const String mimeType = 'mimeType'; // Optional: Content type
  static const String createdAt = 'createdAt';
}

class DocumentAttachment {
  final int? id;
  final int expenseId;
  final String filename; // The unique name used for storage
  final String? originalFilename; // The name shown to the user
  final String? mimeType;
  final DateTime createdAt;

  DocumentAttachment({
    this.id,
    required this.expenseId,
    required this.filename,
    this.originalFilename,
    this.mimeType,
    required this.createdAt,
  });

  String get displayFilename =>
      originalFilename ??
      basename(filename); // Prefer original, fallback to stored

  DocumentAttachment copy({
    int? id,
    int? expenseId,
    String? filename,
    String? originalFilename,
    String? mimeType,
    DateTime? createdAt,
    bool? clearOriginalFilename, // Helper for copy
    bool? clearMimeType, // Helper for copy
  }) => DocumentAttachment(
    id: id ?? this.id,
    expenseId: expenseId ?? this.expenseId,
    filename: filename ?? this.filename,
    originalFilename:
        clearOriginalFilename == true
            ? null
            : (originalFilename ?? this.originalFilename),
    mimeType: clearMimeType == true ? null : (mimeType ?? this.mimeType),
    createdAt: createdAt ?? this.createdAt,
  );

  static DocumentAttachment fromJson(Map<String, Object?> json) =>
      DocumentAttachment(
        id: json[DocumentAttachmentFields.id] as int?,
        expenseId: json[DocumentAttachmentFields.expenseId] as int,
        filename: json[DocumentAttachmentFields.filename] as String,
        originalFilename:
            json[DocumentAttachmentFields.originalFilename] as String?,
        mimeType: json[DocumentAttachmentFields.mimeType] as String?,
        createdAt: DateTime.parse(
          json[DocumentAttachmentFields.createdAt] as String,
        ),
      );

  Map<String, Object?> toJson() => {
    // Don't include ID for inserts usually
    // DocumentAttachmentFields.id: id,
    DocumentAttachmentFields.expenseId: expenseId,
    DocumentAttachmentFields.filename: filename,
    DocumentAttachmentFields.originalFilename: originalFilename,
    DocumentAttachmentFields.mimeType: mimeType,
    DocumentAttachmentFields.createdAt: createdAt.toIso8601String(),
  };
}
