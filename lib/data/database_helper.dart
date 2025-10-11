import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'easyparque.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        role TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE parkings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ownerId INTEGER NOT NULL,
        nom TEXT NOT NULL,
        description TEXT,
        region TEXT,
        cite TEXT,
        rue TEXT,
        numeroBloc TEXT,
        totalPlaces INTEGER NOT NULL,
        availablePlaces INTEGER NOT NULL,
        prixHeure REAL NOT NULL,
        prixJour REAL,
        telephone TEXT,
        FOREIGN KEY(ownerId) REFERENCES users(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_parkings_owner ON parkings(ownerId);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_parkings_nom ON parkings(nom);');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Ajout de la colonne role avec une valeur par défaut
      await db.execute("ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'conducteur'");
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS parkings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ownerId INTEGER NOT NULL,
          nom TEXT NOT NULL,
          description TEXT,
          region TEXT,
          cite TEXT,
          rue TEXT,
          numeroBloc TEXT,
          totalPlaces INTEGER NOT NULL,
          availablePlaces INTEGER NOT NULL,
          prixHeure REAL NOT NULL,
          prixJour REAL,
          telephone TEXT,
          FOREIGN KEY(ownerId) REFERENCES users(id) ON DELETE CASCADE
        );
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_parkings_owner ON parkings(ownerId);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_parkings_nom ON parkings(nom);');
    }
  }

  Future<void> _onOpen(Database db) async {
    // Activer les clés étrangères
    await db.execute('PRAGMA foreign_keys = ON;');
    // Vérifie que la colonne 'role' existe, sinon l'ajoute.
    try {
      final cols = await db.rawQuery("PRAGMA table_info(users)");
      final hasRole = cols.any(
        (c) => ((c['name']?.toString().toLowerCase()) ?? '') == 'role',
      );
      if (!hasRole) {
        await db.execute("ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'conducteur'");
      }
    } on DatabaseException catch (e) {
      // Si la colonne existe déjà, on ignore l'erreur
      final msg = e.toString().toLowerCase();
      if (!msg.contains('duplicate column name')) {
        rethrow;
      }
    }
  }

  Future<int> insertUser({required String email, required String password, required String role}) async {
    final db = await database;
    return await db.insert(
      'users',
      {
        'email': email.trim(),
        'password': password,
        'role': role,
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await database;
    final res = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim()],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return res.first;
  }

  // ===================== PARKINGS =====================
  Future<int> insertParking(Map<String, dynamic> parking) async {
    final db = await database;
    return await db.insert('parkings', parking, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<List<Map<String, dynamic>>> getAllParkings() async {
    final db = await database;
    return await db.query('parkings', orderBy: 'id DESC');
  }

  Future<List<Map<String, dynamic>>> getParkingsByOwner(int ownerId) async {
    final db = await database;
    return await db.query(
      'parkings',
      where: 'ownerId = ?',
      whereArgs: [ownerId],
      orderBy: 'id DESC',
    );
  }

  Future<List<Map<String, dynamic>>> searchParkings(String query) async {
    final db = await database;
    final q = '%${query.trim()}%';
    return await db.query(
      'parkings',
      where: 'nom LIKE ? OR region LIKE ? OR cite LIKE ? OR rue LIKE ? OR description LIKE ?',
      whereArgs: [q, q, q, q, q],
      orderBy: 'id DESC',
    );
  }

  Future<int> deleteParking(int id) async {
    final db = await database;
    return await db.delete('parkings', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateParking(int id, Map<String, dynamic> values) async {
    final db = await database;
    // Ne pas permettre de changer l'id
    final data = Map<String, dynamic>.from(values)..remove('id');
    return await db.update(
      'parkings',
      data,
      where: 'id = ?',
      whereArgs: [id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }
}
