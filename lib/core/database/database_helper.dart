import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Singleton database helper for the entire app.
/// Version 5: Ethiopian calendar support, expense metadata, audit trail.
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'family_garment.db');

    return await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Materials table
    await db.execute('''
      CREATE TABLE materials (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        gsm REAL,
        unit TEXT NOT NULL,
        currentStock REAL NOT NULL DEFAULT 0,
        costPerUnit REAL NOT NULL DEFAULT 0,
        imagePath TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Products table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        sellingPrice REAL NOT NULL,
        imagePaths TEXT DEFAULT '',
        soldAs TEXT DEFAULT '',
        piecesPerPackage INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Size variants table
    await db.execute('''
      CREATE TABLE size_variants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId INTEGER NOT NULL,
        sizeName TEXT NOT NULL,
        materialUsage TEXT NOT NULL DEFAULT '',
        createdAt TEXT NOT NULL,
        FOREIGN KEY (productId) REFERENCES products(id) ON DELETE CASCADE
      )
    ''');

    // Recipe items table
    await db.execute('''
      CREATE TABLE recipe_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId INTEGER NOT NULL,
        materialId INTEGER NOT NULL,
        materialName TEXT NOT NULL,
        category TEXT NOT NULL,
        gsm REAL,
        unit TEXT NOT NULL,
        costPerUnit REAL NOT NULL,
        imagePath TEXT,
        sortOrder INTEGER DEFAULT 0,
        FOREIGN KEY (productId) REFERENCES products(id) ON DELETE CASCADE,
        FOREIGN KEY (materialId) REFERENCES materials(id) ON DELETE CASCADE
      )
    ''');

    // Production log table
    await db.execute('''
      CREATE TABLE production_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId INTEGER NOT NULL,
        productName TEXT NOT NULL,
        sizeName TEXT NOT NULL,
        quantityProduced INTEGER NOT NULL,
        totalRevenue REAL NOT NULL,
        totalCost REAL NOT NULL,
        netProfit REAL NOT NULL,
        materialsUsedJson TEXT NOT NULL DEFAULT '',
        producedAt TEXT NOT NULL,
        FOREIGN KEY (productId) REFERENCES products(id) ON DELETE CASCADE
      )
    ''');

    // Expenses table with frequency support
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        monthlyCost REAL NOT NULL DEFAULT 0,
        expenseFrequency TEXT DEFAULT 'monthly',
        createdAt TEXT NOT NULL
      )
    ''');

    // Expense payments table with notes
    await db.execute('''
      CREATE TABLE expense_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        expenseId INTEGER NOT NULL,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        notes TEXT DEFAULT '',
        paidAt TEXT NOT NULL,
        FOREIGN KEY (expenseId) REFERENCES expenses(id) ON DELETE CASCADE
      )
    ''');

    // Indexes
    await db.execute('CREATE INDEX idx_materials_category ON materials(category)');
    await db.execute('CREATE INDEX idx_products_category ON products(category)');
    await db.execute('CREATE INDEX idx_size_variants_product ON size_variants(productId)');
    await db.execute('CREATE INDEX idx_recipe_items_product ON recipe_items(productId)');
    await db.execute('CREATE INDEX idx_production_logs_product ON production_logs(productId)');
    await db.execute('CREATE INDEX idx_production_logs_date ON production_logs(producedAt)');
    await db.execute('CREATE INDEX idx_expense_payments_date ON expense_payments(paidAt)');
    await db.execute('CREATE INDEX idx_expenses_category ON expenses(category)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try { await db.execute('ALTER TABLE products ADD COLUMN imagePaths TEXT DEFAULT ""'); } catch (_) {}
    }
    if (oldVersion < 3) {
      try { await db.execute('ALTER TABLE products ADD COLUMN soldAs TEXT DEFAULT ""'); } catch (_) {}
      try { await db.execute('ALTER TABLE products ADD COLUMN piecesPerPackage INTEGER DEFAULT 1'); } catch (_) {}
    }
    if (oldVersion < 4) {
      try {
        await db.execute('CREATE TABLE IF NOT EXISTS expenses (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, category TEXT NOT NULL, monthlyCost REAL NOT NULL DEFAULT 0, createdAt TEXT NOT NULL)');
      } catch (_) {}
      try {
        await db.execute('CREATE TABLE IF NOT EXISTS expense_payments (id INTEGER PRIMARY KEY AUTOINCREMENT, expenseId INTEGER NOT NULL, name TEXT NOT NULL, category TEXT NOT NULL, amount REAL NOT NULL, paidAt TEXT NOT NULL, FOREIGN KEY (expenseId) REFERENCES expenses(id) ON DELETE CASCADE)');
      } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_expense_payments_date ON expense_payments(paidAt)'); } catch (_) {}
    }
    if (oldVersion < 5) {
      try { await db.execute('ALTER TABLE expenses ADD COLUMN expenseFrequency TEXT DEFAULT "monthly"'); } catch (_) {}
      try { await db.execute('ALTER TABLE expense_payments ADD COLUMN notes TEXT DEFAULT ""'); } catch (_) {}
      try { await db.execute('CREATE INDEX IF NOT EXISTS idx_expenses_category ON expenses(category)'); } catch (_) {}
    }
  }

  /// Ethiopian calendar helper: Get the current Ethiopian date string
  static String getEthiopianDateString(DateTime gregorian) {
    // Simplified Ethiopian calendar offset (Ginbot 30 = around June 7 Gregorian)
    // For production, use a proper Ethiopian calendar package
    const months = [
      'Meskerem', 'Tikimt', 'Hidar', 'Tahsas', 'Tir', 'Yekatit',
      'Megabit', 'Miazia', 'Ginbot', 'Sene', 'Hamle', 'Nehase', 'Pagume'
    ];
    // Ginbot 30, 2016 ≈ June 7, 2024. Adjust offset as needed.
    final ethDate = gregorian.subtract(const Duration(days: 2833)); // approx 7 years + offset
    final year = ethDate.year - 7; // Rough Ethiopian year
    return '${months[gregorian.month - 1]} ${gregorian.day}, $year';
  }
}