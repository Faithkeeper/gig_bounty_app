import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/task_model.dart';
import '../../models/user_profile.dart';

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
      version: 4,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        await _migrateTasksTable(db);
      },
    );
  }

  Future<void> _migrateTasksTable(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(tasks)');
    final existingColumns =
        columns.map((column) => column['name'] as String).toSet();

    if (existingColumns.isEmpty) {
      await _createDB(db, 4);
      return;
    }

    const requiredColumns = <String, String>{
      'posterId': "TEXT NOT NULL DEFAULT ''",
      'posterName': "TEXT NOT NULL DEFAULT ''",
      'completionNote': 'TEXT',
      'assignedProviderId': 'TEXT',
      'assignedProviderName': 'TEXT',
      'deadline': 'TEXT',
    };

    for (final entry in requiredColumns.entries) {
      if (!existingColumns.contains(entry.key)) {
        await db.execute(
          'ALTER TABLE tasks ADD COLUMN ${entry.key} ${entry.value}',
        );
      }
    }

    if (existingColumns.contains('customerId') &&
        !existingColumns.contains('posterId')) {
      await db.execute(
        "UPDATE tasks SET posterId = customerId WHERE customerId IS NOT NULL",
      );
    }
    if (existingColumns.contains('assignedProvider')) {
      if (!existingColumns.contains('assignedProviderId')) {
        await db.execute(
          'UPDATE tasks SET assignedProviderId = assignedProvider',
        );
      }
      if (!existingColumns.contains('assignedProviderName')) {
        await db.execute(
          'UPDATE tasks SET assignedProviderName = assignedProvider',
        );
      }
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profile (
        uid TEXT PRIMARY KEY,
        email TEXT,
        fullName TEXT,
        role TEXT,
        rating REAL,
        jobsCompleted INTEGER
      )
    ''' );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tasks (
        id TEXT PRIMARY KEY,
        posterId TEXT NOT NULL,
        posterName TEXT NOT NULL,
        title TEXT,
        description TEXT,
        category TEXT,
        budget REAL,
        location TEXT,
        status TEXT,
        assignedProviderId TEXT,
        assignedProviderName TEXT,
        completionNote TEXT,
        createdAt TEXT,
        deadline TEXT
      )
    ''' );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profile (
        uid TEXT PRIMARY KEY,
        email TEXT,
        fullName TEXT,
        role TEXT,
        rating REAL,
        jobsCompleted INTEGER
      )
    ''' );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        actionType TEXT,
        payload TEXT,
        timestamp TEXT
      )
    ''' );
  }

  // Cache tasks locally for offline reading
  Future<void> cacheTasks(List<TaskModel> tasks) async {
    final db = await database;
    final batch = db.batch();
    for (var task in tasks) {
      final sqliteMap = {
        'id': task.id,
        'posterId': task.posterId,
        'posterName': task.posterName,
        'title': task.title,
        'description': task.description,
        'category': task.category,
        'budget': task.budget,
        'location': task.location,
        'status': task.status,
        'assignedProviderId': task.assignedProviderId,
        'assignedProviderName': task.assignedProviderName,
        'completionNote': task.completionNote,
        'createdAt': task.createdAt.toIso8601String(),
        'deadline': task.deadline?.toIso8601String(),
      };
      batch.insert(
        'tasks',
        sqliteMap,
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
      return result.map((json) {
        return TaskModel(
          id: json['id'] as String,
          posterId: json['posterId'] as String? ?? '',
          posterName: json['posterName'] as String? ?? '',
          title: json['title'] as String? ?? '',
          description: json['description'] as String? ?? '',
          category: json['category'] as String? ?? '',
          budget: (json['budget'] as num?)?.toDouble() ?? 0.0,
          location: json['location'] as String? ?? '',
          status: json['status'] as String? ?? 'Open',
          assignedProviderId: json['assignedProviderId'] as String?,
          assignedProviderName: json['assignedProviderName'] as String?,
          completionNote: json['completionNote'] as String?,
          createdAt: json['createdAt'] != null
              ? DateTime.parse(json['createdAt'] as String)
              : DateTime.now(),
          deadline: json['deadline'] != null
              ? DateTime.parse(json['deadline'] as String)
              : null,
        );
      }).toList();
    }
    return [];
  }

  Future<void> cacheUserProfile(UserProfile profile) async {
    final db = await database;
    await db.insert(
      'user_profile',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UserProfile?> getCachedUserProfile() async {
    final db = await database;
    final result = await db.query('user_profile', limit: 1);
    if (result.isNotEmpty) {
      return UserProfile.fromMap(result.first.map((key, value) => MapEntry(key, value)));
    }
    return null;
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
  Future<List<Map<String, Object?>>> getPendingSyncQueue() async {
    final db = await database;
    return db.query('sync_queue', orderBy: 'timestamp ASC');
  }

  // Clear synchronized queue items once uploaded to Firestore
  Future<void> clearQueueItem(int id) async {
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }
}
