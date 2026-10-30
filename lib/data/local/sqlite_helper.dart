import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/task_model.dart';

class SqliteHelper {
  static final SqliteHelper instance = SqliteHelper._init();
  static Database? _database;

  SqliteHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('gig_bounty_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final fullPath = join(dbPath, filePath);

    return await openDatabase(
      fullPath,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Tasks cache table
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT,
        description TEXT,
        category TEXT,
        budget REAL,
        location TEXT,
        posterId TEXT,
        posterName TEXT,
        status TEXT,
        assignedProvider TEXT,
        completionNote TEXT,
        createdAt TEXT
      )
    ''');

    // Offline actions sync queue table
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        actionType TEXT,
        payload TEXT,
        timestamp TEXT
      )
    ''');
  }

  // Cache tasks locally for offline reading
  Future<void> cacheTasks(List<TaskModel> tasks) async {
    final db = await database;
    final batch = db.batch();
    for (var task in tasks) {
      batch.insert(
        'tasks',
        task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // Retrieve locally cached tasks when offline
  Future<List<TaskModel>> getCachedTasks() async {
    final db = await database;
    final result = await db.query('tasks');
    if (result.isNotEmpty) {
      return result.map((json) => TaskModel.fromMap(json)).toList();
    }
    return [];
  }

  // Store offline actions in the queue if connectivity drops
  Future<void> queueOfflineAction(String actionType, String payload) async {
    final db = await database;
    await db.insert('sync_queue', {
      'actionType': actionType,
      'payload': payload,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // Fetch pending offline queue items
  Future<List<Map<String, dynamic>>> getPendingSyncQueue() async {
    final db = await database;
    return await db.query('sync_queue', orderBy: 'timestamp ASC');
  }

  // Clear synchronized queue items once uploaded to Firestore
  Future<void> clearQueueItem(int id) async {
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }
}