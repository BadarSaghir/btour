// import 'dart:async';
// import 'package:path/path.dart';
// import 'package:sqflite/sqflite.dart';
// import 'package:btour/models/expense.dart'; // Need to create these models
// import 'package:btour/models/person.dart';
// import 'package:btour/models/tour.dart';
// import 'package:btour/models/category.dart'; // Need category model

// class DatabaseHelper {
//   static const _dbName = 'tourExpenseApp.db';
//   static const _dbVersion = 2; // <<<<<<<<<<<< INCREMENT DB VERSION

//   static final DatabaseHelper instance = DatabaseHelper._init();
//   static Database? _database;

//   DatabaseHelper._init();

//   Future<Database> get database async {
//     if (_database != null) return _database!;
//     _database = await _initDB('tours_expenses.db');
//     return _database!;
//   }

//   Future<Database> _initDB(String filePath) async {
//     final dbPath = await getDatabasesPath();
//     final path = join(dbPath, filePath);
//     print("Database path: $path"); // Log path for debugging
//     return await openDatabase(path, version: 1, onCreate: _createDB);
//   }

//   // IF YOU CHANGE THE SCHEMA, YOU MUST INCREMENT THE VERSION
//   // AND PROVIDE AN onUpgrade METHOD.
//   Future _createDB(Database db, int version) async {
//     const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
//     const textType = 'TEXT NOT NULL';
//     const textTypeNull = 'TEXT';
//     const realType = 'REAL NOT NULL';
//     const intType = 'INTEGER NOT NULL';
//     const intTypeNull = 'INTEGER'; // Allow null for endDate FK etc if needed

//     // --- People Table ---
//     await db.execute('''
//       CREATE TABLE ${Person.tableName} (
//         ${PersonFields.id} $idType,
//         ${PersonFields.name} $textType UNIQUE
//       )
//       ''');

//     // --- Categories Table ---
//     await db.execute('''
//       CREATE TABLE ${Category.tableName} (
//         ${CategoryFields.id} $idType,
//         ${CategoryFields.name} $textType UNIQUE
//       )
//       ''');
//     // Add some default categories
//     await db.insert(Category.tableName, {'name': 'Food'});
//     await db.insert(Category.tableName, {'name': 'Travel'});
//     await db.insert(Category.tableName, {'name': 'Accommodation'});
//     await db.insert(Category.tableName, {'name': 'Shopping'});
//     await db.insert(Category.tableName, {'name': 'Miscellaneous'});

//     // --- Tours Table ---
//     await db.execute('''
//       CREATE TABLE ${Tour.tableName} (
//         ${TourFields.id} $idType,
//         ${TourFields.name} $textType,
//         ${TourFields.startDate} $textType,
//         ${TourFields.endDate} $textTypeNull,
//         ${TourFields.advanceAmount} $realType,
//         ${TourFields.advanceHolderPersonId} $intType,
//         ${TourFields.status} $textType,
//         FOREIGN KEY (${TourFields.advanceHolderPersonId}) REFERENCES ${Person.tableName} (${PersonFields.id})
//       )
//       ''');

//     // --- Tour Participants (Many-to-Many) ---
//     await db.execute('''
//       CREATE TABLE tour_participants (
//         tourId $intType,
//         personId $intType,
//         PRIMARY KEY (tourId, personId),
//         FOREIGN KEY (tourId) REFERENCES ${Tour.tableName} (${TourFields.id}) ON DELETE CASCADE,
//         FOREIGN KEY (personId) REFERENCES ${Person.tableName} (${PersonFields.id}) ON DELETE CASCADE
//       )
//       ''');

//     // --- Expenses Table ---
//     await db.execute('''
//       CREATE TABLE ${Expense.tableName} (
//         ${ExpenseFields.id} $idType,
//         ${ExpenseFields.tourId} $intType,
//         ${ExpenseFields.categoryId} $intType,
//         ${ExpenseFields.amount} $realType,
//         ${ExpenseFields.date} $textType,
//         ${ExpenseFields.description} $textTypeNull,
//         FOREIGN KEY (${ExpenseFields.tourId}) REFERENCES ${Tour.tableName} (${TourFields.id}) ON DELETE CASCADE,
//         FOREIGN KEY (${ExpenseFields.categoryId}) REFERENCES ${Category.tableName} (${CategoryFields.id})
//       )
//       ''');

//     // --- Expense Attendees (Many-to-Many) ---
//     await db.execute('''
//       CREATE TABLE expense_attendees (
//         expenseId $intType,
//         personId $intType,
//         PRIMARY KEY (expenseId, personId),
//         FOREIGN KEY (expenseId) REFERENCES ${Expense.tableName} (${ExpenseFields.id}) ON DELETE CASCADE,
//         FOREIGN KEY (personId) REFERENCES ${Person.tableName} (${PersonFields.id}) ON DELETE CASCADE
//       )
//       ''');

//     // --- Expense Payments (Who paid what for this expense) ---
//     await db.execute('''
//       CREATE TABLE expense_payments (
//         id $idType,
//         expenseId $intType,
//         personId $intType,
//         amountPaid $realType,
//         FOREIGN KEY (expenseId) REFERENCES ${Expense.tableName} (${ExpenseFields.id}) ON DELETE CASCADE,
//         FOREIGN KEY (personId) REFERENCES ${Person.tableName} (${PersonFields.id})
//       )
//       ''');
//   }

//   // --- CRUD Operations ---

//   // == People ==
//   Future<Person> createPerson(Person person) async {
//     final db = await instance.database;
//     try {
//       final id = await db.insert(Person.tableName, person.toJson());
//       return person.copy(id: id);
//     } catch (e) {
//       // Handle potential unique constraint violation gracefully
//       if (e.toString().contains('UNIQUE constraint failed')) {
//         final existing = await getPersonByName(person.name);
//         if (existing != null) return existing;
//       }
//       print("Error creating person: $e");
//       rethrow; // Or handle differently
//     }
//   }

//   Future<Person?> getPerson(int id) async {
//     final db = await instance.database;
//     final maps = await db.query(
//       Person.tableName,
//       columns: PersonFields.values,
//       where: '${PersonFields.id} = ?',
//       whereArgs: [id],
//     );
//     if (maps.isNotEmpty) {
//       return Person.fromJson(maps.first);
//     } else {
//       return null;
//     }
//   }

//   Future<Person?> getPersonByName(String name) async {
//     final db = await instance.database;
//     final maps = await db.query(
//       Person.tableName,
//       columns: PersonFields.values,
//       where: '${PersonFields.name} = ?',
//       whereArgs: [name],
//     );

//     if (maps.isNotEmpty) {
//       return Person.fromJson(maps.first);
//     } else {
//       return null;
//     }
//   }

//   Future<List<Person>> getAllPeople() async {
//     final db = await instance.database;
//     const orderBy = '${PersonFields.name} ASC';
//     final result = await db.query(Person.tableName, orderBy: orderBy);
//     return result.map((json) => Person.fromJson(json)).toList();
//   }

//   Future<int> updatePerson(Person person) async {
//     final db = await instance.database;
//     return db.update(
//       Person.tableName,
//       person.toJson(),
//       where: '${PersonFields.id} = ?',
//       whereArgs: [person.id],
//     );
//   }

//   Future<int> deletePerson(int id) async {
//     final db = await instance.database;
//     // Be careful: deleting a person might break foreign keys if not handled (ON DELETE CASCADE helps)
//     return db.delete(
//       Person.tableName,
//       where: '${PersonFields.id} = ?',
//       whereArgs: [id],
//     );
//   }

//   // == Categories ==
//   Future<Category> createCategory(Category category) async {
//     final db = await instance.database;
//     try {
//       final id = await db.insert(Category.tableName, category.toJson());
//       return category.copy(id: id);
//     } catch (e) {
//       if (e.toString().contains('UNIQUE constraint failed')) {
//         final existing = await getCategoryByName(category.name);
//         if (existing != null) return existing;
//       }
//       print("Error creating category: $e");
//       rethrow;
//     }
//   }

//   Future<Category?> getCategory(int id) async {
//     final db = await instance.database;
//     final maps = await db.query(
//       Category.tableName,
//       columns: CategoryFields.values,
//       where: '${CategoryFields.id} = ?',
//       whereArgs: [id],
//     );
//     if (maps.isNotEmpty) {
//       return Category.fromJson(maps.first);
//     } else {
//       return null;
//     }
//   }

//   Future<Category?> getCategoryByName(String name) async {
//     final db = await instance.database;
//     final maps = await db.query(
//       Category.tableName,
//       columns: CategoryFields.values,
//       where: '${CategoryFields.name} = ?',
//       whereArgs: [name],
//     );

//     if (maps.isNotEmpty) {
//       return Category.fromJson(maps.first);
//     } else {
//       return null;
//     }
//   }

//   Future<List<Category>> getAllCategories() async {
//     final db = await instance.database;
//     const orderBy = '${CategoryFields.name} ASC';
//     final result = await db.query(Category.tableName, orderBy: orderBy);
//     return result.map((json) => Category.fromJson(json)).toList();
//   }

//   // == Tours ==
//   Future<Tour> createTour(Tour tour, List<int> participantIds) async {
//     final db = await instance.database;
//     final tourId = await db.insert(Tour.tableName, tour.toJson());

//     // Add participants
//     await _updateTourParticipants(tourId, participantIds);

//     return tour.copy(id: tourId);
//   }

//   Future<int> updateTour(Tour tour, List<int> participantIds) async {
//     final db = await instance.database;
//     final tourId = tour.id!; // Assume tour has an ID for update

//     // Update tour details
//     int updateCount = await db.update(
//       Tour.tableName,
//       tour.toJson(),
//       where: '${TourFields.id} = ?',
//       whereArgs: [tourId],
//     );

//     // Update participants (remove old, add new)
//     await _updateTourParticipants(tourId, participantIds);

//     return updateCount;
//   }

//   Future<void> _updateTourParticipants(
//     int tourId,
//     List<int> participantIds,
//   ) async {
//     final db = await instance.database;
//     // Remove existing participants for this tour
//     await db.delete(
//       'tour_participants',
//       where: 'tourId = ?',
//       whereArgs: [tourId],
//     );
//     // Add current participants
//     final batch = db.batch();
//     for (final personId in participantIds) {
//       batch.insert('tour_participants', {
//         'tourId': tourId,
//         'personId': personId,
//       });
//     }
//     await batch.commit(noResult: true);
//   }

//   Future<List<Person>> getTourParticipants(int tourId) async {
//     final db = await instance.database;
//     final result = await db.rawQuery(
//       '''
//       SELECT p.*
//       FROM ${Person.tableName} p
//       JOIN tour_participants tp ON p.${PersonFields.id} = tp.personId
//       WHERE tp.tourId = ?
//       ORDER BY p.${PersonFields.name} ASC
//     ''',
//       [tourId],
//     );
//     return result.map((json) => Person.fromJson(json)).toList();
//   }

//   Future<Tour?> getTour(int id) async {
//     final db = await instance.database;
//     final maps = await db.query(
//       Tour.tableName,
//       columns: TourFields.values,
//       where: '${TourFields.id} = ?',
//       whereArgs: [id],
//     );

//     if (maps.isNotEmpty) {
//       final tour = Tour.fromJson(maps.first);
//       // Fetch related data (optional here, could be lazy loaded)
//       // final participants = await getTourParticipants(id);
//       // final advanceHolder = await getPerson(tour.advanceHolderPersonId);
//       // You might want to return a more complex object or handle this in the provider/screen
//       return tour;
//     } else {
//       return null;
//     }
//   }

//   Future<List<Tour>> getAllTours() async {
//     final db = await instance.database;
//     final orderBy = '${TourFields.startDate} DESC'; // Example order
//     final result = await db.query(Tour.tableName, orderBy: orderBy);
//     return result.map((json) => Tour.fromJson(json)).toList();
//   }

//   Future<int> deleteTour(int id) async {
//     final db = await instance.database;
//     // Associated data will be deleted due to ON DELETE CASCADE
//     return db.delete(
//       Tour.tableName,
//       where: '${TourFields.id} = ?',
//       whereArgs: [id],
//     );
//   }

//   // == Expenses ==
//   // Note: Expense creation/update needs to handle attendees and payments
//   Future<Expense> createExpense(
//     Expense expense,
//     List<int> attendeeIds,
//     List<ExpensePayment> payments,
//   ) async {
//     final db = await instance.database;
//     final expenseId = await db.insert(Expense.tableName, expense.toJson());

//     await _updateExpenseAttendees(db, expenseId, attendeeIds);
//     await _updateExpensePayments(db, expenseId, payments);

//     return expense.copy(id: expenseId);
//   }

//   Future<int> updateExpense(
//     Expense expense,
//     List<int> attendeeIds,
//     List<ExpensePayment> payments,
//   ) async {
//     final db = await instance.database;
//     final expenseId = expense.id!;

//     int updateCount = await db.update(
//       Expense.tableName,
//       expense.toJson(),
//       where: '${ExpenseFields.id} = ?',
//       whereArgs: [expenseId],
//     );

//     await _updateExpenseAttendees(db, expenseId, attendeeIds);
//     await _updateExpensePayments(db, expenseId, payments);

//     return updateCount;
//   }

//   Future<void> _updateExpenseAttendees(
//     Database db,
//     int expenseId,
//     List<int> attendeeIds,
//   ) async {
//     await db.delete(
//       'expense_attendees',
//       where: 'expenseId = ?',
//       whereArgs: [expenseId],
//     );
//     final batch = db.batch();
//     for (final personId in attendeeIds) {
//       batch.insert('expense_attendees', {
//         'expenseId': expenseId,
//         'personId': personId,
//       });
//     }
//     await batch.commit(noResult: true);
//   }

//   Future<void> _updateExpensePayments(
//     Database db,
//     int expenseId,
//     List<ExpensePayment> payments,
//   ) async {
//     await db.delete(
//       'expense_payments',
//       where: 'expenseId = ?',
//       whereArgs: [expenseId],
//     );
//     final batch = db.batch();
//     for (final payment in payments) {
//       if (payment.amountPaid > 0) {
//         // Only save if amount is positive
//         batch.insert('expense_payments', {
//           'expenseId': expenseId,
//           'personId': payment.personId,
//           'amountPaid': payment.amountPaid,
//         });
//       }
//     }
//     await batch.commit(noResult: true);
//   }

//   Future<List<Expense>> getExpensesForTour(int tourId) async {
//     final db = await instance.database;
//     final orderBy = '${ExpenseFields.date} DESC';
//     final result = await db.query(
//       Expense.tableName,
//       where: '${ExpenseFields.tourId} = ?',
//       whereArgs: [tourId],
//       orderBy: orderBy,
//     );
//     // Fetch details for each expense (attendees, payments) potentially here or lazily
//     return result.map((json) => Expense.fromJson(json)).toList();
//   }

//   Future<List<Person>> getExpenseAttendees(int expenseId) async {
//     final db = await instance.database;
//     final result = await db.rawQuery(
//       '''
//       SELECT p.*
//       FROM ${Person.tableName} p
//       JOIN expense_attendees ea ON p.${PersonFields.id} = ea.personId
//       WHERE ea.expenseId = ?
//     ''',
//       [expenseId],
//     );
//     return result.map((json) => Person.fromJson(json)).toList();
//   }

//   Future<List<ExpensePayment>> getExpensePayments(int expenseId) async {
//     final db = await instance.database;
//     final result = await db.query(
//       'expense_payments',
//       where: 'expenseId = ?',
//       whereArgs: [expenseId],
//     );
//     return result.map((json) => ExpensePayment.fromJson(json)).toList();
//   }

//   Future<int> deleteExpense(int id) async {
//     final db = await instance.database;
//     // Associated attendees/payments will be deleted due to ON DELETE CASCADE
//     return db.delete(
//       Expense.tableName,
//       where: '${ExpenseFields.id} = ?',
//       whereArgs: [id],
//     );
//   }

//   // == Reporting Queries ==
//   Future<double> getTotalExpensesForTour(int tourId) async {
//     final db = await instance.database;
//     final result = await db.rawQuery(
//       '''
//         SELECT SUM(${ExpenseFields.amount}) as total
//         FROM ${Expense.tableName}
//         WHERE ${ExpenseFields.tourId} = ?
//       ''',
//       [tourId],
//     );
//     if (result.isNotEmpty && result.first['total'] != null) {
//       // Ensure conversion is safe
//       final total = result.first['total'];
//       if (total is num) {
//         return total.toDouble();
//       }
//     }
//     return 0.0;
//   }

//   Future<Map<int, double>> getPaymentsPerPersonForTour(int tourId) async {
//     final db = await instance.database;
//     final result = await db.rawQuery(
//       '''
//           SELECT pp.${PersonFields.id} as personId, SUM(ep.amountPaid) as totalPaid
//           FROM expense_payments ep
//           JOIN ${Expense.tableName} e ON ep.expenseId = e.${ExpenseFields.id}
//           JOIN ${Person.tableName} pp ON ep.personId = pp.${PersonFields.id}
//           WHERE e.${ExpenseFields.tourId} = ?
//           GROUP BY pp.${PersonFields.id}
//       ''',
//       [tourId],
//     );

//     final Map<int, double> paymentsMap = {};
//     for (final row in result) {
//       final personId = row['personId'] as int?;
//       final totalPaid =
//           row['totalPaid'] as num?; // SQLite sum might return int or double
//       if (personId != null && totalPaid != null) {
//         paymentsMap[personId] = totalPaid.toDouble();
//       }
//     }
//     return paymentsMap;
//   }

//   // Close DB
//   Future close() async {
//     final db = await instance.database;
//     _database = null; // Force re-initialization on next access if needed
//     db.close();
//   }
// }

/***
 * 
 * SQL LITE 3
 */

import 'dart:async';
import 'dart:io'; // Required for Directory/File operations

import 'package:path/path.dart' as p; // Use prefix to avoid name collisions
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

// Assuming your models are structured like this
import 'package:btour/models/expense.dart';
import 'package:btour/models/person.dart';
import 'package:btour/models/tour.dart';
import 'package:btour/models/category.dart';

class DatabaseHelper {
  static const _dbName = 'tourExpenseApp.db'; // Use a distinct name
  static const _dbVersion = 1; // Start versioning for sqlite3 schema

  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(_dbName);
    return _database!;
  }

  Future<Database> _initDB(String dbName) async {
    // --- Required for sqlite3_flutter_libs ---
    // Adjust the path definition for sqlite3
    final dbPath = await getApplicationDocumentsDirectory();
    final path = p.join(dbPath.path, dbName);
    print("Database path: $path"); // Log path for debugging

    // Ensure the directory exists (sqlite3 doesn't create it automatically)
    final dbDir = Directory(p.dirname(path));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    // --- Open the database ---
    // This will create the file if it doesn't exist.
    final db = sqlite3.open(path);

    // --- Enable Foreign Keys ---
    // CRITICAL: Enable foreign key constraint enforcement. Disabled by default in SQLite.
    db.execute('PRAGMA foreign_keys = ON;');

    // --- Schema Creation & Versioning ---
    // sqlite3 doesn't have built-in onCreate/onUpgrade. We manage it manually.
    final currentVersion = db.userVersion;
    print("DB User Version: $currentVersion");

    if (currentVersion == 0) {
      // Database doesn't exist or version is not set, create schema
      print("Creating database schema (Version $_dbVersion)...");
      await _createDB(db);
      db.userVersion = _dbVersion; // Set the version after creation
      print("Database schema created. Version set to $_dbVersion.");
    } else if (currentVersion < _dbVersion) {
      // --- Migration Logic (Placeholder) ---
      // If you change the schema later, increment _dbVersion and add migration steps here.
      print(
        "Database version $currentVersion is older than expected $_dbVersion. Migrating...",
      );
      // Example Migration (if you added a new column to Tour in version 2)
      // if (currentVersion == 1) {
      //   db.execute('ALTER TABLE ${Tour.tableName} ADD COLUMN newField TEXT;');
      //   print("Migrated schema from version 1 to 2.");
      // }
      // Add more migration steps as needed for other version jumps
      db.userVersion = _dbVersion; // Update version after successful migration
      print("Migration complete. Version set to $_dbVersion.");
    } else if (currentVersion > _dbVersion) {
      // This shouldn't happen if you manage versions correctly
      print(
        "Warning: Database version $currentVersion is newer than expected $_dbVersion.",
      );
      // Potentially throw an error or handle downgrade if necessary (usually not recommended)
    } else {
      print("Database schema is up to date (Version $_dbVersion).");
    }

    return db;
  }

  // Schema definition remains the same, execution method changes
  Future<void> _createDB(Database db) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textTypeNull = 'TEXT';
    const realType = 'REAL NOT NULL';
    const intType = 'INTEGER NOT NULL';
    const intTypeNull = 'INTEGER'; // Allow null for endDate FK etc if needed

    // Use a transaction for atomic creation
    db.execute('BEGIN TRANSACTION;');
    try {
      // --- People Table ---
      db.execute('''
        CREATE TABLE ${Person.tableName} (
          ${PersonFields.id} $idType,
          ${PersonFields.name} $textType UNIQUE
        )
      ''');

      // --- Categories Table ---
      db.execute('''
        CREATE TABLE ${Category.tableName} (
          ${CategoryFields.id} $idType,
          ${CategoryFields.name} $textType UNIQUE
        )
      ''');
      // Add some default categories (use execute for simplicity here)
      // For variable data, prepared statements are better
      db.execute("INSERT INTO ${Category.tableName} (name) VALUES ('Food');");
      db.execute("INSERT INTO ${Category.tableName} (name) VALUES ('Travel');");
      db.execute(
        "INSERT INTO ${Category.tableName} (name) VALUES ('Accommodation');",
      );
      db.execute(
        "INSERT INTO ${Category.tableName} (name) VALUES ('Shopping');",
      );
      db.execute(
        "INSERT INTO ${Category.tableName} (name) VALUES ('Miscellaneous');",
      );

      // --- Tours Table ---
      db.execute('''
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
      db.execute('''
        CREATE TABLE tour_participants (
          tourId $intType,
          personId $intType,
          PRIMARY KEY (tourId, personId),
          FOREIGN KEY (tourId) REFERENCES ${Tour.tableName} (${TourFields.id}) ON DELETE CASCADE,
          FOREIGN KEY (personId) REFERENCES ${Person.tableName} (${PersonFields.id}) ON DELETE CASCADE
        )
      ''');

      // --- Expenses Table ---
      db.execute('''
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
      db.execute('''
        CREATE TABLE expense_attendees (
          expenseId $intType,
          personId $intType,
          PRIMARY KEY (expenseId, personId),
          FOREIGN KEY (expenseId) REFERENCES ${Expense.tableName} (${ExpenseFields.id}) ON DELETE CASCADE,
          FOREIGN KEY (personId) REFERENCES ${Person.tableName} (${PersonFields.id}) ON DELETE CASCADE
        )
      ''');

      // --- Expense Payments (Who paid what for this expense) ---
      db.execute('''
        CREATE TABLE expense_payments (
          id $idType,
          expenseId $intType,
          personId $intType,
          amountPaid $realType,
          FOREIGN KEY (expenseId) REFERENCES ${Expense.tableName} (${ExpenseFields.id}) ON DELETE CASCADE,
          FOREIGN KEY (personId) REFERENCES ${Person.tableName} (${PersonFields.id})
        )
      ''');

      // Commit transaction if all statements succeeded
      db.execute('COMMIT;');
    } catch (e) {
      // Rollback if any error occurred
      db.execute('ROLLBACK;');
      print("Error creating database schema: $e");
      rethrow; // Rethrow the exception
    }
  }

  // --- Helper for mapping ResultSet to List<Model> ---
  List<T> _mapResultSet<T>(
    ResultSet resultSet,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return resultSet.map((row) => fromJson(row)).toList();
  }

  // --- CRUD Operations ---

  // == People ==
  Future<Person> createPerson(Person person) async {
    final db = await instance.database;
    // Use prepared statement for safety and efficiency
    final stmt = db.prepare(
      'INSERT INTO ${Person.tableName} (${PersonFields.name}) VALUES (?)',
    );
    try {
      stmt.execute([person.name]);
      final id = db.lastInsertRowId;
      return person.copy(id: id);
    } on SqliteException catch (e) {
      // Handle potential unique constraint violation gracefully
      // SQLite error code 19 corresponds to constraint violations (like UNIQUE)
      if (e.extendedResultCode == 19 &&
          e.message.contains('UNIQUE constraint failed')) {
        print(
          "Person '${person.name}' likely already exists. Attempting to fetch.",
        );
        final existing = await getPersonByName(person.name);
        if (existing != null) {
          print("Returning existing person: ${existing.id}");
          return existing; // Return existing if found
        } else {
          // This case is unlikely if the constraint failed, but handle defensively
          print(
            "UNIQUE constraint failed but couldn't find existing person by name. Rethrowing.",
          );
          rethrow;
        }
      }
      print("Error creating person: $e (Code: ${e.extendedResultCode})");
      rethrow; // Re-throw other errors
    } finally {
      stmt.dispose(); // IMPORTANT: Always dispose statements
    }
  }

  Future<Person?> getPerson(int id) async {
    final db = await instance.database;
    final stmt = db.prepare(
      'SELECT * FROM ${Person.tableName} WHERE ${PersonFields.id} = ?',
    );
    final resultSet = stmt.select([id]);
    Person? result;
    if (resultSet.isNotEmpty) {
      result = Person.fromJson(resultSet.first);
    }
    stmt.dispose();
    return result;
  }

  Future<Person?> getPersonByName(String name) async {
    final db = await instance.database;
    final stmt = db.prepare(
      'SELECT * FROM ${Person.tableName} WHERE ${PersonFields.name} = ? COLLATE NOCASE',
    ); // Case-insensitive search often useful
    final resultSet = stmt.select([name]);
    Person? result;
    if (resultSet.isNotEmpty) {
      result = Person.fromJson(resultSet.first);
    }
    stmt.dispose();
    return result;
  }

  Future<List<Person>> getAllPeople() async {
    final db = await instance.database;
    const orderBy = '${PersonFields.name} ASC';
    final stmt = db.prepare(
      'SELECT * FROM ${Person.tableName} ORDER BY $orderBy',
    );
    final resultSet = stmt.select();
    final list = _mapResultSet(resultSet, Person.fromJson);
    stmt.dispose();
    return list;
  }

  Future<int> updatePerson(Person person) async {
    final db = await instance.database;
    final stmt = db.prepare(
      'UPDATE ${Person.tableName} SET ${PersonFields.name} = ? WHERE ${PersonFields.id} = ?',
    );
    stmt.execute([person.name, person.id]);
    final changes = db.getUpdatedRows();
    stmt.dispose();
    return changes;
  }

  Future<int> deletePerson(int id) async {
    final db = await instance.database;
    final stmt = db.prepare(
      'DELETE FROM ${Person.tableName} WHERE ${PersonFields.id} = ?',
    );
    stmt.execute([id]);
    final changes = db.getUpdatedRows();
    stmt.dispose();
    // ON DELETE CASCADE should handle related data in linking tables
    return changes;
  }

  // == Categories ==
  Future<Category> createCategory(Category category) async {
    final db = await instance.database;
    final stmt = db.prepare(
      'INSERT INTO ${Category.tableName} (${CategoryFields.name}) VALUES (?)',
    );
    try {
      stmt.execute([category.name]);
      final id = db.lastInsertRowId;
      return category.copy(id: id);
    } on SqliteException catch (e) {
      if (e.extendedResultCode == 19 &&
          e.message.contains('UNIQUE constraint failed')) {
        print(
          "Category '${category.name}' likely already exists. Attempting to fetch.",
        );
        final existing = await getCategoryByName(category.name);
        if (existing != null) {
          print("Returning existing category: ${existing.id}");
          return existing;
        } else {
          print(
            "UNIQUE constraint failed but couldn't find existing category by name. Rethrowing.",
          );
          rethrow;
        }
      }
      print("Error creating category: $e (Code: ${e.extendedResultCode})");
      rethrow;
    } finally {
      stmt.dispose();
    }
  }

  Future<Category?> getCategory(int id) async {
    final db = await instance.database;
    final stmt = db.prepare(
      'SELECT * FROM ${Category.tableName} WHERE ${CategoryFields.id} = ?',
    );
    final resultSet = stmt.select([id]);
    Category? result;
    if (resultSet.isNotEmpty) {
      result = Category.fromJson(resultSet.first);
    }
    stmt.dispose();
    return result;
  }

  Future<Category?> getCategoryByName(String name) async {
    final db = await instance.database;
    final stmt = db.prepare(
      'SELECT * FROM ${Category.tableName} WHERE ${CategoryFields.name} = ? COLLATE NOCASE',
    );
    final resultSet = stmt.select([name]);
    Category? result;
    if (resultSet.isNotEmpty) {
      result = Category.fromJson(resultSet.first);
    }
    stmt.dispose();
    return result;
  }

  Future<List<Category>> getAllCategories() async {
    final db = await instance.database;
    const orderBy = '${CategoryFields.name} ASC';
    final stmt = db.prepare(
      'SELECT * FROM ${Category.tableName} ORDER BY $orderBy',
    );
    final resultSet = stmt.select();
    final list = _mapResultSet(resultSet, Category.fromJson);
    stmt.dispose();
    return list;
  }

  // == Tours ==
  Future<Tour> createTour(Tour tour, List<int> participantIds) async {
    final db = await instance.database;
    int tourId = -1; // Initialize with invalid ID

    // Use transaction to ensure atomicity of tour creation and participant linking
    db.execute('BEGIN TRANSACTION;');
    try {
      final tourStmt = db.prepare('''
        INSERT INTO ${Tour.tableName} (
          ${TourFields.name}, ${TourFields.startDate}, ${TourFields.endDate},
          ${TourFields.advanceAmount}, ${TourFields.advanceHolderPersonId}, ${TourFields.status}
        ) VALUES (?, ?, ?, ?, ?, ?)
      ''');
      tourStmt.execute([
        tour.name,
        tour.startDate.toIso8601String(), // Store dates as ISO strings
        tour.endDate?.toIso8601String(),
        tour.advanceAmount,
        tour.advanceHolderPersonId,
        tour.status.toString(), // Assuming status is an enum or similar
      ]);
      tourId = db.lastInsertRowId; // Get the ID of the inserted tour
      tourStmt.dispose();

      // Add participants using the obtained tourId
      await _updateTourParticipantsInternal(db, tourId, participantIds);

      // If everything succeeded, commit the transaction
      db.execute('COMMIT;');
      return tour.copy(id: tourId);
    } catch (e) {
      // If any error occurs, roll back the transaction
      db.execute('ROLLBACK;');
      print("Error creating tour: $e");
      rethrow; // Rethrow the error
    }
  }

  Future<int> updateTour(Tour tour, List<int> participantIds) async {
    final db = await instance.database;
    final tourId = tour.id;
    if (tourId == null) {
      throw ArgumentError("Tour must have an ID to be updated.");
    }

    int updateCount = 0;
    db.execute('BEGIN TRANSACTION;');
    try {
      final tourStmt = db.prepare('''
        UPDATE ${Tour.tableName} SET
          ${TourFields.name} = ?, ${TourFields.startDate} = ?, ${TourFields.endDate} = ?,
          ${TourFields.advanceAmount} = ?, ${TourFields.advanceHolderPersonId} = ?, ${TourFields.status} = ?
        WHERE ${TourFields.id} = ?
      ''');
      tourStmt.execute([
        tour.name,
        tour.startDate.toIso8601String(),
        tour.endDate?.toIso8601String(),
        tour.advanceAmount,
        tour.advanceHolderPersonId,
        tour.status.toString(),
        tourId,
      ]);
      updateCount = db.getUpdatedRows(); // Get rows affected by the UPDATE
      tourStmt.dispose();

      // Update participants
      await _updateTourParticipantsInternal(db, tourId, participantIds);

      db.execute('COMMIT;');
      return updateCount; // Return the number of tours updated (should be 1 or 0)
    } catch (e) {
      db.execute('ROLLBACK;');
      print("Error updating tour $tourId: $e");
      rethrow;
    }
  }

  // Internal helper for participant updates, assumes transaction is handled externally
  Future<void> _updateTourParticipantsInternal(
    Database db,
    int tourId,
    List<int> participantIds,
  ) async {
    // Remove existing participants for this tour
    final deleteStmt = db.prepare(
      'DELETE FROM tour_participants WHERE tourId = ?',
    );
    deleteStmt.execute([tourId]);
    deleteStmt.dispose();

    // Add current participants (if any)
    if (participantIds.isNotEmpty) {
      // Use a prepared statement for batch inserts
      final insertStmt = db.prepare(
        'INSERT INTO tour_participants (tourId, personId) VALUES (?, ?)',
      );
      for (final personId in participantIds) {
        insertStmt.execute([tourId, personId]);
      }
      insertStmt.dispose();
    }
  }

  Future<List<Person>> getTourParticipants(int tourId) async {
    final db = await instance.database;
    // Use rawQuery-like approach with prepare/select for joins
    final stmt = db.prepare('''
      SELECT p.*
      FROM ${Person.tableName} p
      JOIN tour_participants tp ON p.${PersonFields.id} = tp.personId
      WHERE tp.tourId = ?
      ORDER BY p.${PersonFields.name} ASC
    ''');
    final resultSet = stmt.select([tourId]);
    final list = _mapResultSet(resultSet, Person.fromJson);
    stmt.dispose();
    return list;
  }

  Future<Tour?> getTour(int id) async {
    final db = await instance.database;
    final stmt = db.prepare(
      'SELECT * FROM ${Tour.tableName} WHERE ${TourFields.id} = ?',
    );
    final resultSet = stmt.select([id]);
    Tour? result;
    if (resultSet.isNotEmpty) {
      // Make sure Tour.fromJson handles date strings and status strings
      result = Tour.fromJson(resultSet.first);
    }
    stmt.dispose();
    // Fetching related data (participants, etc.) can be done here or separately
    // Example:
    // if (result != null) {
    //   final participants = await getTourParticipants(id);
    //   // You might want a TourWithDetails object or attach to the result
    // }
    return result;
  }

  Future<List<Tour>> getAllTours() async {
    final db = await instance.database;
    final orderBy = '${TourFields.startDate} DESC'; // Example order
    final stmt = db.prepare(
      'SELECT * FROM ${Tour.tableName} ORDER BY $orderBy',
    );
    final resultSet = stmt.select();
    // Ensure Tour.fromJson handles the data correctly
    final list = _mapResultSet(resultSet, Tour.fromJson);
    stmt.dispose();
    return list;
  }

  Future<int> deleteTour(int id) async {
    final db = await instance.database;
    // ON DELETE CASCADE handles participants, expenses, etc.
    final stmt = db.prepare(
      'DELETE FROM ${Tour.tableName} WHERE ${TourFields.id} = ?',
    );
    stmt.execute([id]);
    final changes = db.getUpdatedRows();
    stmt.dispose();
    return changes;
  }

  // == Expenses ==
  Future<Expense> createExpense(
    Expense expense,
    List<int> attendeeIds,
    List<ExpensePayment> payments,
  ) async {
    final db = await instance.database;
    int expenseId = -1;

    db.execute('BEGIN TRANSACTION;');
    try {
      final expenseStmt = db.prepare('''
        INSERT INTO ${Expense.tableName} (
          ${ExpenseFields.tourId}, ${ExpenseFields.categoryId}, ${ExpenseFields.amount},
          ${ExpenseFields.date}, ${ExpenseFields.description}
        ) VALUES (?, ?, ?, ?, ?)
      ''');
      expenseStmt.execute([
        expense.tourId,
        expense.categoryId,
        expense.amount,
        expense.date.toIso8601String(), // Store date as string
        expense.description,
      ]);
      expenseId = db.lastInsertRowId;
      expenseStmt.dispose();

      await _updateExpenseAttendeesInternal(db, expenseId, attendeeIds);
      await _updateExpensePaymentsInternal(db, expenseId, payments);

      db.execute('COMMIT;');
      return expense.copy(id: expenseId);
    } catch (e) {
      db.execute('ROLLBACK;');
      print("Error creating expense: $e");
      rethrow;
    }
  }

  Future<int> updateExpense(
    Expense expense,
    List<int> attendeeIds,
    List<ExpensePayment> payments,
  ) async {
    final db = await instance.database;
    final expenseId = expense.id;
    if (expenseId == null) {
      throw ArgumentError("Expense must have an ID to be updated.");
    }

    int updateCount = 0;
    db.execute('BEGIN TRANSACTION;');
    try {
      final expenseStmt = db.prepare('''
        UPDATE ${Expense.tableName} SET
          ${ExpenseFields.tourId} = ?, ${ExpenseFields.categoryId} = ?, ${ExpenseFields.amount} = ?,
          ${ExpenseFields.date} = ?, ${ExpenseFields.description} = ?
        WHERE ${ExpenseFields.id} = ?
      ''');
      expenseStmt.execute([
        expense.tourId,
        expense.categoryId,
        expense.amount,
        expense.date.toIso8601String(),
        expense.description,
        expenseId,
      ]);
      updateCount = db.getUpdatedRows();
      expenseStmt.dispose();

      await _updateExpenseAttendeesInternal(db, expenseId, attendeeIds);
      await _updateExpensePaymentsInternal(db, expenseId, payments);

      db.execute('COMMIT;');
      return updateCount;
    } catch (e) {
      db.execute('ROLLBACK;');
      print("Error updating expense $expenseId: $e");
      rethrow;
    }
  }

  // Internal helper for attendee updates
  Future<void> _updateExpenseAttendeesInternal(
    Database db,
    int expenseId,
    List<int> attendeeIds,
  ) async {
    final deleteStmt = db.prepare(
      'DELETE FROM expense_attendees WHERE expenseId = ?',
    );
    deleteStmt.execute([expenseId]);
    deleteStmt.dispose();

    if (attendeeIds.isNotEmpty) {
      final insertStmt = db.prepare(
        'INSERT INTO expense_attendees (expenseId, personId) VALUES (?, ?)',
      );
      for (final personId in attendeeIds) {
        insertStmt.execute([expenseId, personId]);
      }
      insertStmt.dispose();
    }
  }

  // Internal helper for payment updates
  Future<void> _updateExpensePaymentsInternal(
    Database db,
    int expenseId,
    List<ExpensePayment> payments,
  ) async {
    final deleteStmt = db.prepare(
      'DELETE FROM expense_payments WHERE expenseId = ?',
    );
    deleteStmt.execute([expenseId]);
    deleteStmt.dispose();

    if (payments.isNotEmpty) {
      final insertStmt = db.prepare(
        'INSERT INTO expense_payments (expenseId, personId, amountPaid) VALUES (?, ?, ?)',
      );
      for (final payment in payments) {
        if (payment.amountPaid > 0) {
          // Only save if amount is positive
          // Note: We use the expenseId passed to the function, not necessarily the one in the payment object
          // The payment object passed in might not have an expenseId yet if it's part of a new expense creation.
          insertStmt.execute([expenseId, payment.personId, payment.amountPaid]);
        }
      }
      insertStmt.dispose();
    }
  }

  Future<List<Expense>> getExpensesForTour(int tourId) async {
    final db = await instance.database;
    final orderBy = '${ExpenseFields.date} DESC';
    final stmt = db.prepare(
      'SELECT * FROM ${Expense.tableName} WHERE ${ExpenseFields.tourId} = ? ORDER BY $orderBy',
    );
    final resultSet = stmt.select([tourId]);
    // Ensure Expense.fromJson handles date string
    final list = _mapResultSet(resultSet, Expense.fromJson);
    stmt.dispose();
    // Details like attendees/payments are fetched separately if needed
    return list;
  }

  Future<List<Person>> getExpenseAttendees(int expenseId) async {
    final db = await instance.database;
    final stmt = db.prepare('''
      SELECT p.*
      FROM ${Person.tableName} p
      JOIN expense_attendees ea ON p.${PersonFields.id} = ea.personId
      WHERE ea.expenseId = ?
      ORDER BY p.${PersonFields.name} ASC
    ''');
    final resultSet = stmt.select([expenseId]);
    final list = _mapResultSet(resultSet, Person.fromJson);
    stmt.dispose();
    return list;
  }

  Future<List<ExpensePayment>> getExpensePayments(int expenseId) async {
    final db = await instance.database;
    final stmt = db.prepare(
      'SELECT * FROM expense_payments WHERE expenseId = ?',
    );
    final resultSet = stmt.select([expenseId]);
    // Ensure ExpensePayment.fromJson exists and works
    final list = _mapResultSet(resultSet, ExpensePayment.fromJson);
    stmt.dispose();
    return list;
  }

  Future<int> deleteExpense(int id) async {
    final db = await instance.database;
    // ON DELETE CASCADE handles attendees/payments
    final stmt = db.prepare(
      'DELETE FROM ${Expense.tableName} WHERE ${ExpenseFields.id} = ?',
    );
    stmt.execute([id]);
    final changes = db.getUpdatedRows();
    stmt.dispose();
    return changes;
  }

  // == Reporting Queries ==
  Future<double> getTotalExpensesForTour(int tourId) async {
    final db = await instance.database;
    final stmt = db.prepare('''
        SELECT SUM(${ExpenseFields.amount}) as total
        FROM ${Expense.tableName}
        WHERE ${ExpenseFields.tourId} = ?
      ''');
    final resultSet = stmt.select([tourId]);
    double total = 0.0;
    if (resultSet.isNotEmpty) {
      // SUM returns NULL if there are no rows, or a number otherwise.
      final resultValue = resultSet.first['total'];
      if (resultValue is num) {
        total = resultValue.toDouble();
      }
    }
    stmt.dispose();
    return total;
  }

  Future<Map<int, double>> getPaymentsPerPersonForTour(int tourId) async {
    final db = await instance.database;
    // Ensure Person table alias 'pp' matches column names used in Map processing
    final stmt = db.prepare('''
          SELECT pp.${PersonFields.id} as personId, SUM(ep.amountPaid) as totalPaid
          FROM expense_payments ep
          JOIN ${Expense.tableName} e ON ep.expenseId = e.${ExpenseFields.id}
          JOIN ${Person.tableName} pp ON ep.personId = pp.${PersonFields.id}
          WHERE e.${ExpenseFields.tourId} = ?
          GROUP BY pp.${PersonFields.id}
      ''');
    final resultSet = stmt.select([tourId]);

    final Map<int, double> paymentsMap = {};
    for (final row in resultSet) {
      final personId = row['personId'] as int?; // Alias used in SELECT
      final totalPaid = row['totalPaid'] as num?; // Alias used in SELECT
      if (personId != null && totalPaid != null) {
        paymentsMap[personId] = totalPaid.toDouble();
      }
    }
    stmt.dispose();
    return paymentsMap;
  }

  // Close DB
  Future<void> close() async {
    final db = _database; // Get current instance
    if (db != null) {
      print("Closing database...");
      db.dispose(); // Use dispose() for sqlite3
      _database = null; // Force re-initialization on next access
      print("Database closed.");
    }
  }
}
