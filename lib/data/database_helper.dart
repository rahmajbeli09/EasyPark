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

  Future<Map<String, dynamic>?> getUserById(int id) async {
    final db = await database;
    final res = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return res.first;
  }

  Future<int> updateUser(int id, Map<String, dynamic> values) async {
    final db = await database;
    final data = Map<String, dynamic>.from(values)..remove('id');
    return await db.update(
      'users',
      data,
      where: 'id = ?',
      whereArgs: [id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  // ===================== RESERVATIONS =====================
  Future<int> createReservation({
    required int userId,
    required int parkingId,
    required int hours,
    required DateTime startAt,
    required DateTime endAt,
    String status = 'active',
  }) async {
    final db = await database;
    return await db.insert('reservations', {
      'userId': userId,
      'parkingId': parkingId,
      'hours': hours,
      'startAt': startAt.toIso8601String(),
      'endAt': endAt.toIso8601String(),
      'status': status,
    });
  }

  Future<int> cancelReservationByParking(int userId, int parkingId) async {
    final db = await database;
    return await db.update(
      'reservations',
      {'status': 'canceled'},
      where: 'userId = ? AND parkingId = ? AND status = ?',
      whereArgs: [userId, parkingId, 'active'],
    );
  }

  Future<List<Map<String, dynamic>>> getUserReservations(int userId) async {
    final db = await database;
    return await db.query(
      'reservations',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'startAt DESC',
    );
  }

  // ===================== NOTIFICATIONS =====================
  Future<int> addNotification({required String title, String? body}) async {
    final db = await database;
    return await db.insert('notifications', {
      'title': title,
      'body': body,
      'date': DateTime.now().toIso8601String(),
      'read': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getNotifications({bool unreadOnly = false}) async {
    final db = await database;
    if (unreadOnly) {
      return await db.query('notifications', where: 'read = 0', orderBy: 'date DESC');
    }
    return await db.query('notifications', orderBy: 'date DESC');
  }

  Future<int> markAllNotificationsRead() async {
    final db = await database;
    return await db.update('notifications', {'read': 1});
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'easyparque.db');

    return await openDatabase(
      path,
      version: 7,
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
        role TEXT NOT NULL,
        name TEXT,
        phone TEXT,
        photo TEXT
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
        promoPercent REAL,
        promoStart TEXT,
        promoEnd TEXT,
        telephone TEXT,
        FOREIGN KEY(ownerId) REFERENCES users(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_parkings_owner ON parkings(ownerId);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_parkings_nom ON parkings(nom);');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reclamations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        type TEXT NOT NULL,
        description TEXT,
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY(userId) REFERENCES users(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_reclamations_user ON reclamations(userId);');

    // Notifications
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        body TEXT,
        date TEXT NOT NULL,
        read INTEGER NOT NULL DEFAULT 0
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(read);');
    // Reservations
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reservations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        parkingId INTEGER NOT NULL,
        hours INTEGER NOT NULL,
        startAt TEXT NOT NULL,
        endAt TEXT NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY(userId) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY(parkingId) REFERENCES parkings(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_reservations_user ON reservations(userId);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_reservations_parking ON reservations(parkingId);');
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
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS reclamations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          userId INTEGER NOT NULL,
          type TEXT NOT NULL,
          description TEXT,
          date TEXT NOT NULL,
          status TEXT NOT NULL,
          FOREIGN KEY(userId) REFERENCES users(id) ON DELETE CASCADE
        );
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_reclamations_user ON reclamations(userId);');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notifications (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          body TEXT,
          date TEXT NOT NULL,
          read INTEGER NOT NULL DEFAULT 0
        );
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(read);');
    }
    if (oldVersion < 5) {
      // Add promotion columns to parkings if they don't exist
      try {
        final cols = await db.rawQuery("PRAGMA table_info(parkings)");
        final hasPromoPercent = cols.any((c) => ((c['name']?.toString().toLowerCase()) ?? '') == 'promopercent');
        final hasPromoStart = cols.any((c) => ((c['name']?.toString().toLowerCase()) ?? '') == 'promostart');
        final hasPromoEnd = cols.any((c) => ((c['name']?.toString().toLowerCase()) ?? '') == 'promoend');
        if (!hasPromoPercent) {
          await db.execute('ALTER TABLE parkings ADD COLUMN promoPercent REAL');
        }
        if (!hasPromoStart) {
          await db.execute('ALTER TABLE parkings ADD COLUMN promoStart TEXT');
        }
        if (!hasPromoEnd) {
          await db.execute('ALTER TABLE parkings ADD COLUMN promoEnd TEXT');
        }
      } on DatabaseException catch (e) {
        final msg = e.toString().toLowerCase();
        if (!msg.contains('duplicate column name')) {
          rethrow;
        }
      }
    }
    if (oldVersion < 6) {
      // Create reservations table if not exists
      await db.execute('''
        CREATE TABLE IF NOT EXISTS reservations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          userId INTEGER NOT NULL,
          parkingId INTEGER NOT NULL,
          hours INTEGER NOT NULL,
          startAt TEXT NOT NULL,
          endAt TEXT NOT NULL,
          status TEXT NOT NULL,
          FOREIGN KEY(userId) REFERENCES users(id) ON DELETE CASCADE,
          FOREIGN KEY(parkingId) REFERENCES parkings(id) ON DELETE CASCADE
        );
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_reservations_user ON reservations(userId);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_reservations_parking ON reservations(parkingId);');
    }
    if (oldVersion < 7) {
      try {
        final cols = await db.rawQuery("PRAGMA table_info(users)");
        bool hasName = cols.any((c) => ((c['name']?.toString().toLowerCase()) ?? '') == 'name');
        bool hasPhone = cols.any((c) => ((c['name']?.toString().toLowerCase()) ?? '') == 'phone');
        bool hasPhoto = cols.any((c) => ((c['name']?.toString().toLowerCase()) ?? '') == 'photo');
        if (!hasName) await db.execute("ALTER TABLE users ADD COLUMN name TEXT");
        if (!hasPhone) await db.execute("ALTER TABLE users ADD COLUMN phone TEXT");
        if (!hasPhoto) await db.execute("ALTER TABLE users ADD COLUMN photo TEXT");
      } on DatabaseException catch (e) {
        final msg = e.toString().toLowerCase();
        if (!msg.contains('duplicate column name')) {
          rethrow;
        }
      }
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

    // Vérifier l'existence de la table 'reclamations' et de la colonne 'status'
    try {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='reclamations'",
      );
      if (tables.isEmpty) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS reclamations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userId INTEGER NOT NULL,
            type TEXT NOT NULL,
            description TEXT,
            date TEXT NOT NULL,
            status TEXT NOT NULL,
            FOREIGN KEY(userId) REFERENCES users(id) ON DELETE CASCADE
          );
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_reclamations_user ON reclamations(userId);');
      } else {
        final rCols = await db.rawQuery("PRAGMA table_info(reclamations)");
        final hasStatus = rCols.any(
          (c) => ((c['name']?.toString().toLowerCase()) ?? '') == 'status',
        );
        if (!hasStatus) {
          await db.execute("ALTER TABLE reclamations ADD COLUMN status TEXT NOT NULL DEFAULT 'Nouvelle'");
        }
      }
    } on DatabaseException catch (e) {
      final msg = e.toString().toLowerCase();
      if (!msg.contains('duplicate column name')) {
        rethrow;
      }
    }

    // Vérifier la table notifications
    try {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='notifications'",
      );
      if (tables.isEmpty) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS notifications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            body TEXT,
            date TEXT NOT NULL,
            read INTEGER NOT NULL DEFAULT 0
          );
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(read);');
      }
    } on DatabaseException {
      // best effort
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
    // Select only needed columns to avoid pulling very large text fields that can overflow CursorWindow
    return await db.query(
      'parkings',
      columns: [
        'id',
        'ownerId',
        'nom',
        // 'description' intentionally omitted for lightweight list
        'region',
        'cite',
        'rue',
        'numeroBloc',
        'totalPlaces',
        'availablePlaces',
        'prixHeure',
        'prixJour',
        'promoPercent',
        'promoStart',
        'promoEnd',
        'telephone',
      ],
      orderBy: 'id DESC',
    );
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

  // ===================== USERS =====================
  Future<List<Map<String, dynamic>>> getAllUsersExcept(String adminEmail) async {
    final db = await database;
    return await db.query(
      'users',
      where: 'LOWER(email) != ?',
      whereArgs: [adminEmail.trim().toLowerCase()],
      orderBy: 'id DESC',
    );
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }
  // ===================== RECLAMATIONS =====================
  Future<int> createReclamation(int userId, String type, String description) async {
    final db = await database;
    final recId = await db.insert('reclamations', {
      'userId': userId,
      'type': type,
      'description': description,
      'date': DateTime.now().toIso8601String(),
      'status': 'Nouvelle',
    });
    // Create a notification for admin
    await addNotification(
      title: 'Nouvelle réclamation',
      body: 'Utilisateur #$userId: $type',
    );
    return recId;
  }

  Future<List<Map<String, dynamic>>> getUserReclamations(int userId) async {
    final db = await database;
    return await db.query(
      'reclamations',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllReclamations() async {
    final db = await database;
    return await db.query('reclamations', orderBy: 'date DESC');
  }
}

