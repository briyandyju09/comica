import 'dart:convert';

class Comic {
  final String id;
  final String path;
  final String title;
  final String folderName;
  final int? sortNumber;
  final int totalPages;
  final bool isFavorite;
  final String? thumbnailPath;
  final DateTime? addedAt;

  const Comic({
    required this.id,
    required this.path,
    required this.title,
    required this.folderName,
    this.sortNumber,
    this.totalPages = 0,
    this.isFavorite = false,
    this.thumbnailPath,
    this.addedAt,
  });

  Comic copyWith({
    String? id,
    String? path,
    String? title,
    String? folderName,
    int? sortNumber,
    int? totalPages,
    bool? isFavorite,
    String? thumbnailPath,
    DateTime? addedAt,
  }) {
    return Comic(
      id: id ?? this.id,
      path: path ?? this.path,
      title: title ?? this.title,
      folderName: folderName ?? this.folderName,
      sortNumber: sortNumber ?? this.sortNumber,
      totalPages: totalPages ?? this.totalPages,
      isFavorite: isFavorite ?? this.isFavorite,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
      'title': title,
      'folder_name': folderName,
      'sort_number': sortNumber,
      'total_pages': totalPages,
      'is_favorite': isFavorite ? 1 : 0,
      'thumbnail_path': thumbnailPath,
      'added_at': addedAt?.toIso8601String(),
    };
  }

  factory Comic.fromMap(Map<String, dynamic> map) {
    return Comic(
      id: map['id'] as String,
      path: map['path'] as String,
      title: map['title'] as String,
      folderName: map['folder_name'] as String,
      sortNumber: map['sort_number'] as int?,
      totalPages: map['total_pages'] as int? ?? 0,
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      thumbnailPath: map['thumbnail_path'] as String?,
      addedAt: map['added_at'] != null
          ? DateTime.tryParse(map['added_at'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Comic && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Comic(id: $id, title: $title, pages: $totalPages)';
}
