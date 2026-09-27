import 'package:hive/hive.dart';

part 'comic.g.dart';

@HiveType(typeId: 0)
class Comic extends HiveObject {
  @HiveField(0)
  late String id; // unique: folder path hash or folder path

  @HiveField(1)
  late String title;

  @HiveField(2)
  late String folderPath;

  @HiveField(3)
  late List<String> filePaths; // all PDF/image files inside folder, sorted

  @HiveField(4)
  late int sortNumber; // extracted from (XXX) prefix; -1 if none

  @HiveField(5)
  late bool isFavorite;

  @HiveField(6)
  late List<int> bookmarkedPages;

  @HiveField(7)
  late int lastReadPage; // 0-indexed; -1 means unread

  @HiveField(8)
  late String? coverImagePath; // cached cover thumbnail path

  @HiveField(9)
  late DateTime? lastOpenedAt;

  @HiveField(10)
  late String? seriesName; // extracted from folder name

  Comic({
    required this.id,
    required this.title,
    required this.folderPath,
    required this.filePaths,
    required this.sortNumber,
    this.isFavorite = false,
    List<int>? bookmarkedPages,
    this.lastReadPage = -1,
    this.coverImagePath,
    this.lastOpenedAt,
    this.seriesName,
  }) : bookmarkedPages = bookmarkedPages ?? [];

  /// Total pages across all files (approximation stored separately)
  int get totalFiles => filePaths.length;

  bool get isRead => lastReadPage >= 0;

  double get readProgress {
    if (lastReadPage < 0 || _cachedTotalPages == null || _cachedTotalPages! <= 0) {
      return 0.0;
    }
    return (lastReadPage + 1) / _cachedTotalPages!;
  }

  int? _cachedTotalPages;
  void setTotalPages(int pages) => _cachedTotalPages = pages;

  /// Parse sort number from folder name like "(001) Title" or "(23) Title"
  static int parseSortNumber(String folderName) {
    final regex = RegExp(r'^\((\d+)\)');
    final match = regex.firstMatch(folderName.trim());
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? -1;
    }
    return -1;
  }

  /// Parse clean title from folder name
  static String parseTitle(String folderName) {
    final cleaned = folderName
        .replaceAll(RegExp(r'^\(\d+\)\s*'), '') // remove (XXX) prefix
        .trim();
    return cleaned.isEmpty ? folderName : cleaned;
  }

  /// Extract series name (e.g. "Space Action" from "Space Action #1")
  static String? parseSeriesName(String title) {
    final hashRegex = RegExp(r'(.+?)\s*#\d+$');
    final match = hashRegex.firstMatch(title);
    if (match != null) return match.group(1)!.trim();

    final volRegex = RegExp(r'(.+?)\s*[Vv]ol\.?\s*\d+$');
    final volMatch = volRegex.firstMatch(title);
    if (volMatch != null) return volMatch.group(1)!.trim();

    return null;
  }

  Comic copyWith({
    bool? isFavorite,
    List<int>? bookmarkedPages,
    int? lastReadPage,
    String? coverImagePath,
    DateTime? lastOpenedAt,
  }) {
    return Comic(
      id: id,
      title: title,
      folderPath: folderPath,
      filePaths: filePaths,
      sortNumber: sortNumber,
      isFavorite: isFavorite ?? this.isFavorite,
      bookmarkedPages: bookmarkedPages ?? this.bookmarkedPages,
      lastReadPage: lastReadPage ?? this.lastReadPage,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      seriesName: seriesName,
    );
  }
}

@HiveType(typeId: 1)
class AppSettings extends HiveObject {
  @HiveField(0)
  late String? rootDirectoryPath;

  @HiveField(1)
  late bool isDarkMode;

  @HiveField(2)
  late bool useVerticalScroll;

  @HiveField(3)
  late String? lastOpenedComicId;

  AppSettings({
    this.rootDirectoryPath,
    this.isDarkMode = true,
    this.useVerticalScroll = false,
    this.lastOpenedComicId,
  });
}
