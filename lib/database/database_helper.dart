import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:btour/models/expense.dart'; // Need to create these models
import 'package:btour/models/person.dart';
import 'package:btour/models/tour.dart';
import 'package:btour/models/category.dart'; // Need category model

class DatabaseHelper {
  static const _dbName = 'tourExpenseApp.db';
  static const _dbVersion = 2; // <<<<<<<<<<<< INCREMENT DB VERSION

  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tours_expenses.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    print("Database path: $path"); // Log path for debugging
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  // IF YOU CHANGE THE SCHEMA, YOU MUST INCREMENT THE VERSION
  // AND PROVIDE AN onUpgrade METHOD.
  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textTypeNull = 'TEXT';
    const realType = 'REAL NOT NULL';
    const intType = 'INTEGER NOT NULL';
    const intTypeNull = 'INTEGER'; // Allow null for endDate FK etc if needed

    // --- People Table ---
    await db.execute('''
      CREATE TABLE ${Person.tableName} (
        ${PersonFields.id} $idType,
        ${PersonFields.name} $textType UNIQUE
      )
      ''');

    // --- Categories Table ---
    await db.execute('''
      CREATE TABLE ${Category.tableName} (
        ${CategoryFields.id} $idType,
        ${CategoryFields.name} $textType UNIQUE
      )
      ''');
    // Add some default categories
    await db.insert(Category.tableName, {'name': 'Food'});
    await db.insert(Category.tableName, {'name': 'Travel'});
    await db.insert(Category.tableName, {'name': 'Accommodation'});
    await db.insert(Category.tableName, {'name': 'Shopping'});
    await db.insert(Category.tableName, {'name': 'Miscellaneous'});

    // --- Tours Table ---
    await db.execute('''
      CREATE TABLE ${Tour.tableName} (
        ${TourFields.id} $idType,
        ${TourFields.name} $textType,
        ${TourFields.startDate} $textType,
        ${TourFields.endDate} $textTypeNull,
        ${TourFields.advanceAmount} $realType,
        ${TourFields.advanceHolderPersonId} $intType,
        ${TourFields.status} $textType,
        FOREIGN KEY (${TourFields.advanceHolderPersonId}) REFERENCES ${Person.tableName} (${PersonFields.id})
      )
      ''');

    // --- Tour Participants (Many-to-Many) ---
    await db.execute('''
      CREATE TABLE tour_participants (
        tourId $intType,
        personId $intType,
        PRIMARY KEY (tourId, personId),
        FOREIGN KEY (tourId) REFERENCES ${Tour.tableName} (${TourFields.id}) ON DELETE CASCADE,
        FOREIGN KEY (personId) REFERENCES ${Person.tableName} (${PersonFields.id}) ON DELETE CASCADE
      )
      ''');

    // --- Expenses Table ---
    await db.execute('''
      CREATE TABLE ${Expense.tableName} (
        ${ExpenseFields.id} $idType,
        ${ExpenseFields.tourId} $intType,
        ${ExpenseFields.categoryId} $intType,
        ${ExpenseFields.amount} $realType,
        ${ExpenseFields.date} $textType,
        ${ExpenseFields.description} $textTypeNull,
        FOREIGN KEY (${ExpenseFields.tourId}) REFERENCES ${Tour.tableName} (${TourFields.id}) ON DELETE CASCADE,
        FOREIGN KEY (${ExpenseFields.categoryId}) REFERENCES ${Category.tableName} (${CategoryFields.id})
      )
      ''');

    // --- Expense Attendees (Many-to-Many) ---
    await db.execute('''
      CREATE TABLE expense_attendees (
        expenseId $intType,
        personId $intType,
        PRIMARY KEY (expenseId, personId),
        FOREIGN KEY (expenseId) REFERENCES ${Expense.tableName} (${ExpenseFields.id}) ON DELETE CASCADE,
        FOREIGN KEY (personId) REFERENCES ${Person.tableName} (${PersonFields.id}) ON DELETE CASCADE
      )
      ''');

    // --- Expense Payments (Who paid what for this expense) ---
    await db.execute('''
      CREATE TABLE expense_payments (
        id $idType,
        expenseId $intType,
        personId $intType,
        amountPaid $realType,
        FOREIGN KEY (expenseId) REFERENCES ${Expense.tableName} (${ExpenseFields.id}) ON DELETE CASCADE,
        FOREIGN KEY (personId) REFERENCES ${Person.tableName} (${PersonFields.id})
      )
      ''');
  }

  // --- CRUD Operations ---

  // == People ==
  Future<Person> createPerson(Person person) async {
    final db = await instance.database;
    try {
      final id = await db.insert(Person.tableName, person.toJson());
      return person.copy(id: id);
    } catch (e) {
      // Handle potential unique constraint violation gracefully
      if (e.toString().contains('UNIQUE constraint failed')) {
        final existing = await getPersonByName(person.name);
        if (existing != null) return existing;
      }
      print("Error creating person: $e");
      rethrow; // Or handle differently
    }
  }

  Future<Person?> getPerson(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      Person.tableName,
      columns: PersonFields.values,
      where: '${PersonFields.id} = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Person.fromJson(maps.first);
    } else {
      return null;
    }
  }

  Future<Person?> getPersonByName(String name) async {
    final db = await instance.database;
    final maps = await db.query(
      Person.tableName,
      columns: PersonFields.values,
      where: '${PersonFields.name} = ?',
      whereArgs: [name],
    );

    if (maps.isNotEmpty) {
      return Person.fromJson(maps.first);
    } else {
      return null;
    }
  }

  Future<List<Person>> getAllPeople() async {
    final db = await instance.database;
    const orderBy = '${PersonFields.name} ASC';
    final result = await db.query(Person.tableName, orderBy: orderBy);
    return result.map((json) => Person.fromJson(json)).toList();
  }

  Future<int> updatePerson(Person person) async {
    final db = await instance.database;
    return db.update(
      Person.tableName,
      person.toJson(),
      where: '${PersonFields.id} = ?',
      whereArgs: [person.id],
    );
  }

  Future<int> deletePerson(int id) async {
    final db = await instance.database;
    // Be careful: deleting a person might break foreign keys if not handled (ON DELETE CASCADE helps)
    return db.delete(
      Person.tableName,
      where: '${PersonFields.id} = ?',
      whereArgs: [id],
    );
  }

  // == Categories ==
  Future<Category> createCategory(Category category) async {
    final db = await instance.database;
    try {
      final id = await db.insert(Category.tableName, category.toJson());
      return category.copy(id: id);
    } catch (e) {
      if (e.toString().contains('UNIQUE constraint failed')) {
        final existing = await getCategoryByName(category.name);
        if (existing != null) return existing;
      }
      print("Error creating category: $e");
      rethrow;
    }
  }

  Future<Category?> getCategory(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      Category.tableName,
      columns: CategoryFields.values,
      where: '${CategoryFields.id} = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Category.fromJson(maps.first);
    } else {
      return null;
    }
  }

  Future<Category?> getCategoryByName(String name) async {
    final db = await instance.database;
    final maps = await db.query(
      Category.tableName,
      columns: CategoryFields.values,
      where: '${CategoryFields.name} = ?',
      whereArgs: [name],
    );

    if (maps.isNotEmpty) {
      return Category.fromJson(maps.first);
    } else {
      return null;
    }
  }

  Future<List<Category>> getAllCategories() async {
    final db = await instance.database;
    const orderBy = '${CategoryFields.name} ASC';
    final result = await db.query(Category.tableName, orderBy: orderBy);
    return result.map((json) => Category.fromJson(json)).toList();
  }

  // == Tours ==
  Future<Tour> createTour(Tour tour, List<int> participantIds) async {
    final db = await instance.database;
    final tourId = await db.insert(Tour.tableName, tour.toJson());

    // Add participants
    await _updateTourParticipants(tourId, participantIds);

    return tour.copy(id: tourId);
  }

  Future<int> updateTour(Tour tour, List<int> participantIds) async {
    final db = await instance.database;
    final tourId = tour.id!; // Assume tour has an ID for update

    // Update tour details
    int updateCount = await db.update(
      Tour.tableName,
      tour.toJson(),
      where: '${TourFields.id} = ?',
      whereArgs: [tourId],
    );

    // Update participants (remove old, add new)
    await _updateTourParticipants(tourId, participantIds);

    return updateCount;
  }

  Future<void> _updateTourParticipants(
    int tourId,
    List<int> participantIds,
  ) async {
    final db = await instance.database;
    // Remove existing participants for this tour
    await db.delete(
      'tour_participants',
      where: 'tourId = ?',
      whereArgs: [tourId],
    );
    // Add current participants
    final batch = db.batch();
    for (final personId in participantIds) {
      batch.insert('tour_participants', {
        'tourId': tourId,
        'personId': personId,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<Person>> getTourParticipants(int tourId) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      '''
      SELECT p.*
      FROM ${Person.tableName} p
      JOIN tour_participants tp ON p.${PersonFields.id} = tp.personId
      WHERE tp.tourId = ?
      ORDER BY p.${PersonFields.name} ASC
    ''',
      [tourId],
    );
    return result.map((json) => Person.fromJson(json)).toList();
  }

  Future<Tour?> getTour(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      Tour.tableName,
      columns: TourFields.values,
      where: '${TourFields.id} = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      final tour = Tour.fromJson(maps.first);
      // Fetch related data (optional here, could be lazy loaded)
      // final participants = await getTourParticipants(id);
      // final advanceHolder = await getPerson(tour.advanceHolderPersonId);
      // You might want to return a more complex object or handle this in the provider/screen
      return tour;
    } else {
      return null;
    }
  }

  Future<List<Tour>> getAllTours() async {
    final db = await instance.database;
    final orderBy = '${TourFields.startDate} DESC'; // Example order
    final result = await db.query(Tour.tableName, orderBy: orderBy);
    return result.map((json) => Tour.fromJson(json)).toList();
  }

  Future<int> deleteTour(int id) async {
    final db = await instance.database;
    // Associated data will be deleted due to ON DELETE CASCADE
    return db.delete(
      Tour.tableName,
      where: '${TourFields.id} = ?',
      whereArgs: [id],
    );
  }

  // == Expenses ==
  // Note: Expense creation/update needs to handle attendees and payments
  Future<Expense> createExpense(
    Expense expense,
    List<int> attendeeIds,
    List<ExpensePayment> payments,
  ) async {
    final db = await instance.database;
    final expenseId = await db.insert(Expense.tableName, expense.toJson());

    await _updateExpenseAttendees(db, expenseId, attendeeIds);
    await _updateExpensePayments(db, expenseId, payments);

    return expense.copy(id: expenseId);
  }

  Future<int> updateExpense(
    Expense expense,
    List<int> attendeeIds,
    List<ExpensePayment> payments,
  ) async {
    final db = await instance.database;
    final expenseId = expense.id!;

    int updateCount = await db.update(
      Expense.tableName,
      expense.toJson(),
      where: '${ExpenseFields.id} = ?',
      whereArgs: [expenseId],
    );

    await _updateExpenseAttendees(db, expenseId, attendeeIds);
    await _updateExpensePayments(db, expenseId, payments);

    return updateCount;
  }

  Future<void> _updateExpenseAttendees(
    Database db,
    int expenseId,
    List<int> attendeeIds,
  ) async {
    await db.delete(
      'expense_attendees',
      where: 'expenseId = ?',
      whereArgs: [expenseId],
    );
    final batch = db.batch();
    for (final personId in attendeeIds) {
      batch.insert('expense_attendees', {
        'expenseId': expenseId,
        'personId': personId,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> _updateExpensePayments(
    Database db,
    int expenseId,
    List<ExpensePayment> payments,
  ) async {
    await db.delete(
      'expense_payments',
      where: 'expenseId = ?',
      whereArgs: [expenseId],
    );
    final batch = db.batch();
    for (final payment in payments) {
      if (payment.amountPaid > 0) {
        // Only save if amount is positive
        batch.insert('expense_payments', {
          'expenseId': expenseId,
          'personId': payment.personId,
          'amountPaid': payment.amountPaid,
        });
      }
    }
    await batch.commit(noResult: true);
  }

  Future<List<Expense>> getExpensesForTour(int tourId) async {
    final db = await instance.database;
    final orderBy = '${ExpenseFields.date} DESC';
    final result = await db.query(
      Expense.tableName,
      where: '${ExpenseFields.tourId} = ?',
      whereArgs: [tourId],
      orderBy: orderBy,
    );
    // Fetch details for each expense (attendees, payments) potentially here or lazily
    return result.map((json) => Expense.fromJson(json)).toList();
  }

  Future<List<Person>> getExpenseAttendees(int expenseId) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      '''
      SELECT p.*
      FROM ${Person.tableName} p
      JOIN expense_attendees ea ON p.${PersonFields.id} = ea.personId
      WHERE ea.expenseId = ?
    ''',
      [expenseId],
    );
    return result.map((json) => Person.fromJson(json)).toList();
  }

  Future<List<ExpensePayment>> getExpensePayments(int expenseId) async {
    final db = await instance.database;
    final result = await db.query(
      'expense_payments',
      where: 'expenseId = ?',
      whereArgs: [expenseId],
    );
    return result.map((json) => ExpensePayment.fromJson(json)).toList();
  }

  Future<int> deleteExpense(int id) async {
    final db = await instance.database;
    // Associated attendees/payments will be deleted due to ON DELETE CASCADE
    return db.delete(
      Expense.tableName,
      where: '${ExpenseFields.id} = ?',
      whereArgs: [id],
    );
  }

  // == Reporting Queries ==
  Future<double> getTotalExpensesForTour(int tourId) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      '''
        SELECT SUM(${ExpenseFields.amount}) as total
        FROM ${Expense.tableName}
        WHERE ${ExpenseFields.tourId} = ?
      ''',
      [tourId],
    );
    if (result.isNotEmpty && result.first['total'] != null) {
      // Ensure conversion is safe
      final total = result.first['total'];
      if (total is num) {
        return total.toDouble();
      }
    }
    return 0.0;
  }

  Future<Map<int, double>> getPaymentsPerPersonForTour(int tourId) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      '''
          SELECT pp.${PersonFields.id} as personId, SUM(ep.amountPaid) as totalPaid
          FROM expense_payments ep
          JOIN ${Expense.tableName} e ON ep.expenseId = e.${ExpenseFields.id}
          JOIN ${Person.tableName} pp ON ep.personId = pp.${PersonFields.id}
          WHERE e.${ExpenseFields.tourId} = ?
          GROUP BY pp.${PersonFields.id}
      ''',
      [tourId],
    );

    final Map<int, double> paymentsMap = {};
    for (final row in result) {
      final personId = row['personId'] as int?;
      final totalPaid =
          row['totalPaid'] as num?; // SQLite sum might return int or double
      if (personId != null && totalPaid != null) {
        paymentsMap[personId] = totalPaid.toDouble();
      }
    }
    return paymentsMap;
  }

  // Close DB
  Future close() async {
    final db = await instance.database;
    _database = null; // Force re-initialization on next access if needed
    db.close();
  }
}
