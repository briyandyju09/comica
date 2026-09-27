import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/comic.dart';
import '../models/reading_progress.dart';
import '../models/bookmark.dart';

class DatabaseService {
  static const _dbName = 'comica.db';
  static const _dbVersion = 1;

  static DatabaseService? _instance;
  static Database? _db;

  DatabaseService._();

  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE comics (
        id TEXT PRIMARY KEY,
        path TEXT NOT NULL,
        title TEXT NOT NULL,
        folder_name TEXT NOT NULL,
        sort_number INTEGER,
        total_pages INTEGER DEFAULT 0,
        is_favorite INTEGER DEFAULT 0,
        thumbnail_path TEXT,
        added_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE reading_progress (
        comic_id TEXT PRIMARY KEY,
        last_page INTEGER DEFAULT 1,
        total_pages INTEGER DEFAULT 0,
        last_read_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE bookmarks (
        id TEXT PRIMARY KEY,
        comic_id TEXT NOT NULL,
        page INTEGER NOT NULL,
        note TEXT,
        created_at TEXT,
        FOREIGN KEY (comic_id) REFERENCES comics(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {}

  // ── Comics ────────────────────────────────────────────────
  Future<List<Comic>> getAllComics() async {
    final db = await database;
    final maps = await db.query('comics', orderBy: 'sort_number ASC, title ASC');
    return maps.map(Comic.fromMap).toList();
  }

  Future<Comic?> getComic(String id) async {
    final db = await database;
    final maps = await db.query('comics', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Comic.fromMap(maps.first);
  }

  Future<void> insertComic(Comic comic) async {
    final db = await database;
    await db.insert('comics', comic.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateComic(Comic comic) async {
    final db = await database;
    await db.update('comics', comic.toMap(),
        where: 'id = ?', whereArgs: [comic.id]);
  }

  Future<void> deleteComic(String id) async {
    final db = await database;
    await db.delete('comics', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setFavorite(String id, bool value) async {
    final db = await database;
    await db.update(
      'comics',
      {'is_favorite': value ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateThumbnailPath(String id, String path) async {
    final db = await database;
    await db.update(
      'comics',
      {'thumbnail_path': path},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<String>> getAllComicIds() async {
    final db = await database;
    final result = await db.query('comics', columns: ['id']);
    return result.map((r) => r['id'] as String).toList();
  }

  Future<void> bulkInsertComics(List<Comic> comics) async {
    final db = await database;
    final batch = db.batch();
    for (final c in comics) {
      batch.insert('comics', c.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteComicsByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final id in ids) {
      batch.delete('comics', where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  // ── Reading Progress ──────────────────────────────────────
  Future<ReadingProgress?> getProgress(String comicId) async {
    final db = await database;
    final maps = await db.query('reading_progress',
        where: 'comic_id = ?', whereArgs: [comicId]);
    if (maps.isEmpty) return null;
    return ReadingProgress.fromMap(maps.first);
  }

  Future<void> saveProgress(ReadingProgress progress) async {
    final db = await database;
    await db.insert('reading_progress', progress.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<ReadingProgress?> getMostRecentProgress() async {
    final db = await database;
    final maps = await db.query(
      'reading_progress',
      orderBy: 'last_read_at DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ReadingProgress.fromMap(maps.first);
  }

  // ── Bookmarks ────────────────────────────────────────────
  Future<List<Bookmark>> getBookmarks(String comicId) async {
    final db = await database;
    final maps = await db.query('bookmarks',
        where: 'comic_id = ?', whereArgs: [comicId], orderBy: 'page ASC');
    return maps.map(Bookmark.fromMap).toList();
  }

  Future<void> insertBookmark(Bookmark bookmark) async {
    final db = await database;
    await db.insert('bookmarks', bookmark.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteBookmark(String id) async {
    final db = await database;
    await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }
}
