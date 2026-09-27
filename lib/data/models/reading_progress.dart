class ReadingProgress {
  final String comicId;
  final int lastPage;
  final int totalPages;
  final DateTime lastReadAt;

  const ReadingProgress({
    required this.comicId,
    required this.lastPage,
    required this.totalPages,
    required this.lastReadAt,
  });

  double get progressPercent =>
      totalPages > 0 ? lastPage / totalPages : 0.0;

  bool get isFinished => totalPages > 0 && lastPage >= totalPages;

  Map<String, dynamic> toMap() {
    return {
      'comic_id': comicId,
      'last_page': lastPage,
      'total_pages': totalPages,
      'last_read_at': lastReadAt.toIso8601String(),
    };
  }

  factory ReadingProgress.fromMap(Map<String, dynamic> map) {
    return ReadingProgress(
      comicId: map['comic_id'] as String,
      lastPage: map['last_page'] as int? ?? 1,
      totalPages: map['total_pages'] as int? ?? 0,
      lastReadAt: DateTime.tryParse(map['last_read_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  ReadingProgress copyWith({
    String? comicId,
    int? lastPage,
    int? totalPages,
    DateTime? lastReadAt,
  }) {
    return ReadingProgress(
      comicId: comicId ?? this.comicId,
      lastPage: lastPage ?? this.lastPage,
      totalPages: totalPages ?? this.totalPages,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }
}
