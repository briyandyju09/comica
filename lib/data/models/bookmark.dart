class Bookmark {
  final String id;
  final String comicId;
  final int page;
  final String? note;
  final DateTime createdAt;

  const Bookmark({
    required this.id,
    required this.comicId,
    required this.page,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'comic_id': comicId,
      'page': page,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      id: map['id'] as String,
      comicId: map['comic_id'] as String,
      page: map['page'] as int,
      note: map['note'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
