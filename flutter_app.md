Okay, here is the complete Flutter code structured with the `// FILE:` markers for the Node.js script.

Save the following content into a single file, for example, `flutter_app_code.md`.

```markdown
// FILE: lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:btour/providers/tour_provider.dart';
import 'package:btour/screens/tour_list_screen.dart';
import 'database/database_helper.dart'; // Ensure this path is correct

void main() async {
  // Required for plugins like sqflite before runApp
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize database (optional here, can be lazy loaded)
  await DatabaseHelper.instance.database;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Use Provider for simple state management / dependency injection
    return ChangeNotifierProvider(
      create: (context) => TourProvider(),
      child: MaterialApp(
        title: 'Tour Expense Tracker',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          useMaterial3: true, // Optional: Use Material 3 design
          inputDecorationTheme: const InputDecorationTheme(
             border: OutlineInputBorder(),
             contentPadding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
          ),
          cardTheme: CardTheme(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        home: const TourListScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
```

```markdown
// FILE: lib/database/database_helper.dart
import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:btour/models/expense.dart'; // Need to create these models
import 'package:btour/models/person.dart';
import 'package:btour/models/tour.dart';
import 'package:btour/models/category.dart'; // Need category model

class DatabaseHelper {
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

  Future<void> _updateTourParticipants(int tourId, List<int> participantIds) async {
     final db = await instance.database;
     // Remove existing participants for this tour
     await db.delete('tour_participants', where: 'tourId = ?', whereArgs: [tourId]);
     // Add current participants
     final batch = db.batch();
     for (final personId in participantIds) {
       batch.insert('tour_participants', {'tourId': tourId, 'personId': personId});
     }
     await batch.commit(noResult: true);
  }

  Future<List<Person>> getTourParticipants(int tourId) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT p.*
      FROM ${Person.tableName} p
      JOIN tour_participants tp ON p.${PersonFields.id} = tp.personId
      WHERE tp.tourId = ?
      ORDER BY p.${PersonFields.name} ASC
    ''', [tourId]);
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
 Future<Expense> createExpense(Expense expense, List<int> attendeeIds, List<ExpensePayment> payments) async {
    final db = await instance.database;
    final expenseId = await db.insert(Expense.tableName, expense.toJson());

    await _updateExpenseAttendees(db, expenseId, attendeeIds);
    await _updateExpensePayments(db, expenseId, payments);

    return expense.copy(id: expenseId);
  }

  Future<int> updateExpense(Expense expense, List<int> attendeeIds, List<ExpensePayment> payments) async {
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

  Future<void> _updateExpenseAttendees(Database db, int expenseId, List<int> attendeeIds) async {
     await db.delete('expense_attendees', where: 'expenseId = ?', whereArgs: [expenseId]);
     final batch = db.batch();
     for (final personId in attendeeIds) {
       batch.insert('expense_attendees', {'expenseId': expenseId, 'personId': personId});
     }
     await batch.commit(noResult: true);
  }

   Future<void> _updateExpensePayments(Database db, int expenseId, List<ExpensePayment> payments) async {
     await db.delete('expense_payments', where: 'expenseId = ?', whereArgs: [expenseId]);
     final batch = db.batch();
     for (final payment in payments) {
        if (payment.amountPaid > 0) { // Only save if amount is positive
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
    final result = await db.rawQuery('''
      SELECT p.*
      FROM ${Person.tableName} p
      JOIN expense_attendees ea ON p.${PersonFields.id} = ea.personId
      WHERE ea.expenseId = ?
    ''', [expenseId]);
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
      final result = await db.rawQuery('''
        SELECT SUM(${ExpenseFields.amount}) as total
        FROM ${Expense.tableName}
        WHERE ${ExpenseFields.tourId} = ?
      ''', [tourId]);
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
      final result = await db.rawQuery('''
          SELECT pp.${PersonFields.id} as personId, SUM(ep.amountPaid) as totalPaid
          FROM expense_payments ep
          JOIN ${Expense.tableName} e ON ep.expenseId = e.${ExpenseFields.id}
          JOIN ${Person.tableName} pp ON ep.personId = pp.${PersonFields.id}
          WHERE e.${ExpenseFields.tourId} = ?
          GROUP BY pp.${PersonFields.id}
      ''', [tourId]);

      final Map<int, double> paymentsMap = {};
      for (final row in result) {
         final personId = row['personId'] as int?;
         final totalPaid = row['totalPaid'] as num?; // SQLite sum might return int or double
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
```

```markdown
// FILE: lib/models/person.dart
class PersonFields {
  static final List<String> values = [id, name];

  static const String id = '_id';
  static const String name = 'name';
}

const String personTable = 'people'; // Use Person.tableName instead

class Person {
  static const String tableName = 'people'; // Define table name here

  final int? id;
  final String name;

  const Person({this.id, required this.name});

  Person copy({int? id, String? name}) => Person(
        id: id ?? this.id,
        name: name ?? this.name,
      );

  static Person fromJson(Map<String, Object?> json) => Person(
        id: json[PersonFields.id] as int?,
        name: json[PersonFields.name] as String,
      );

  Map<String, Object?> toJson() => {
        PersonFields.id: id,
        PersonFields.name: name,
      };

  // For comparison in lists/dropdowns
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Person &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;

   @override
  String toString() {
    return 'Person{id: $id, name: $name}';
  }
}
```

```markdown
// FILE: lib/models/category.dart
class CategoryFields {
  static final List<String> values = [id, name];
  static const String id = '_id';
  static const String name = 'name';
}

class Category {
  static const String tableName = 'categories';

  final int? id;
  final String name;

  const Category({this.id, required this.name});

  Category copy({int? id, String? name}) => Category(
        id: id ?? this.id,
        name: name ?? this.name,
      );

  static Category fromJson(Map<String, Object?> json) => Category(
        id: json[CategoryFields.id] as int?,
        name: json[CategoryFields.name] as String,
      );

  Map<String, Object?> toJson() => {
        CategoryFields.id: id,
        CategoryFields.name: name,
      };

   // For comparison in lists/dropdowns
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;

  @override
  String toString() {
    return 'Category{id: $id, name: $name}';
  }
}
```

```markdown
// FILE: lib/models/tour.dart
import 'package:intl/intl.dart'; // For date formatting

class TourFields {
  static final List<String> values = [id, name, startDate, endDate, advanceAmount, advanceHolderPersonId, status];

  static const String id = '_id';
  static const String name = 'name';
  static const String startDate = 'startDate';
  static const String endDate = 'endDate';
  static const String advanceAmount = 'advanceAmount';
  static const String advanceHolderPersonId = 'advanceHolderPersonId';
  static const String status = 'status'; // 'Created', 'Started', 'Ended'
}

enum TourStatus { Created, Started, Ended }

class Tour {
   static const String tableName = 'tours';

  final int? id;
  final String name;
  final DateTime startDate;
  final DateTime? endDate;
  final double advanceAmount;
  final int advanceHolderPersonId; // Foreign Key to Person table
  final TourStatus status;

  Tour({
    this.id,
    required this.name,
    required this.startDate,
    this.endDate,
    required this.advanceAmount,
    required this.advanceHolderPersonId,
    this.status = TourStatus.Created,
  });

  // --- Getters for display ---
  String get formattedStartDate => DateFormat('yyyy-MM-dd').format(startDate);
  String get formattedEndDate => endDate != null ? DateFormat('yyyy-MM-dd').format(endDate!) : 'Ongoing';
  String get statusString => status.toString().split('.').last;


  Tour copy({
    int? id,
    String? name,
    DateTime? startDate,
    DateTime? endDate, // Need a way to explicitly set null
    bool clearEndDate = false, // Flag to clear end date
    double? advanceAmount,
    int? advanceHolderPersonId,
    TourStatus? status,
  }) =>
      Tour(
        id: id ?? this.id,
        name: name ?? this.name,
        startDate: startDate ?? this.startDate,
        endDate: clearEndDate ? null : (endDate ?? this.endDate),
        advanceAmount: advanceAmount ?? this.advanceAmount,
        advanceHolderPersonId: advanceHolderPersonId ?? this.advanceHolderPersonId,
        status: status ?? this.status,
      );

  static Tour fromJson(Map<String, Object?> json) => Tour(
        id: json[TourFields.id] as int?,
        name: json[TourFields.name] as String,
        startDate: DateTime.parse(json[TourFields.startDate] as String),
        endDate: json[TourFields.endDate] != null ? DateTime.parse(json[TourFields.endDate] as String) : null,
        advanceAmount: json[TourFields.advanceAmount] as double,
        advanceHolderPersonId: json[TourFields.advanceHolderPersonId] as int,
        status: TourStatus.values.firstWhere(
           (e) => e.toString() == 'TourStatus.${json[TourFields.status] as String}',
           orElse: () => TourStatus.Created, // Default if status is invalid
        ),
      );

  Map<String, Object?> toJson() => {
        TourFields.id: id,
        TourFields.name: name,
        // Store dates as ISO 8601 strings
        TourFields.startDate: startDate.toIso8601String(),
        TourFields.endDate: endDate?.toIso8601String(),
        TourFields.advanceAmount: advanceAmount,
        TourFields.advanceHolderPersonId: advanceHolderPersonId,
        TourFields.status: status.toString().split('.').last, // Store enum name as string
      };

  @override
  String toString() {
    return 'Tour{id: $id, name: $name, startDate: $formattedStartDate, endDate: $formattedEndDate, advance: $advanceAmount, holderId: $advanceHolderPersonId, status: $statusString}';
  }
}
```

```markdown
// FILE: lib/models/expense.dart
import 'package:intl/intl.dart';
import 'package:btour/models/person.dart'; // Import Person for payments

class ExpenseFields {
  static final List<String> values = [id, tourId, categoryId, amount, date, description];

  static const String id = '_id';
  static const String tourId = 'tourId';
  static const String categoryId = 'categoryId';
  static const String amount = 'amount';
  static const String date = 'date';
  static const String description = 'description';
}

class Expense {
  static const String tableName = 'expenses';

  final int? id;
  final int tourId;
  final int categoryId;
  final double amount;
  final DateTime date;
  final String? description;

  // These are not stored directly in the expense table but are related
  List<Person>? attendees; // Loaded separately
  List<ExpensePayment>? payments; // Loaded separately

  Expense({
    this.id,
    required this.tourId,
    required this.categoryId,
    required this.amount,
    required this.date,
    this.description,
    this.attendees, // Optional init
    this.payments,   // Optional init
  });

  String get formattedDate => DateFormat('yyyy-MM-dd').format(date);

  Expense copy({
    int? id,
    int? tourId,
    int? categoryId,
    double? amount,
    DateTime? date,
    String? description,
    List<Person>? attendees,
    List<ExpensePayment>? payments,
  }) =>
      Expense(
        id: id ?? this.id,
        tourId: tourId ?? this.tourId,
        categoryId: categoryId ?? this.categoryId,
        amount: amount ?? this.amount,
        date: date ?? this.date,
        description: description ?? this.description,
        attendees: attendees ?? this.attendees,
        payments: payments ?? this.payments,
      );

  static Expense fromJson(Map<String, Object?> json) => Expense(
        id: json[ExpenseFields.id] as int?,
        tourId: json[ExpenseFields.tourId] as int,
        categoryId: json[ExpenseFields.categoryId] as int,
        amount: json[ExpenseFields.amount] as double,
        date: DateTime.parse(json[ExpenseFields.date] as String),
        description: json[ExpenseFields.description] as String?,
        // Related data (attendees, payments) needs to be loaded separately
      );

  Map<String, Object?> toJson() => {
        ExpenseFields.id: id,
        ExpenseFields.tourId: tourId,
        ExpenseFields.categoryId: categoryId,
        ExpenseFields.amount: amount,
        ExpenseFields.date: date.toIso8601String(),
        ExpenseFields.description: description,
      };

  @override
  String toString() {
    return 'Expense{id: $id, tourId: $tourId, catId: $categoryId, amount: $amount, date: $formattedDate, desc: $description}';
  }
}


// Represents the 'expense_payments' table structure
class ExpensePayment {
    final int? id; // Primary key of the payment record itself
    final int expenseId;
    final int personId;
    final double amountPaid;

    // Optional: Include Person object if needed after fetching
    final Person? person;

    ExpensePayment({
        this.id,
        required this.expenseId,
        required this.personId,
        required this.amountPaid,
        this.person,
    });

    static ExpensePayment fromJson(Map<String, Object?> json) => ExpensePayment(
        id: json['id'] as int?, // Assuming 'id' is the PK column name in DB table
        expenseId: json['expenseId'] as int,
        personId: json['personId'] as int,
        amountPaid: json['amountPaid'] as double,
        // Person data would need to be joined/fetched separately usually
    );

     Map<String, Object?> toJson() => {
        'id': id,
        'expenseId': expenseId,
        'personId': personId,
        'amountPaid': amountPaid,
    };

    ExpensePayment copyWith({
        int? id,
        int? expenseId,
        int? personId,
        double? amountPaid,
        Person? person,
    }) {
        return ExpensePayment(
            id: id ?? this.id,
            expenseId: expenseId ?? this.expenseId,
            personId: personId ?? this.personId,
            amountPaid: amountPaid ?? this.amountPaid,
            person: person ?? this.person, // Keep or update person object
        );
    }
}
```

```markdown
// FILE: lib/providers/tour_provider.dart
import 'package:flutter/material.dart';
import 'package:btour/database/database_helper.dart';
import 'package:btour/models/category.dart';
import 'package:btour/models/expense.dart';
import 'package:btour/models/person.dart';
import 'package:btour/models/tour.dart';

// Basic provider using ChangeNotifier for simplicity
class TourProvider with ChangeNotifier {
  List<Tour> _tours = [];
  List<Person> _people = [];
  List<Category> _categories = [];
  bool _isLoading = false;

  // Keep track of data for the currently viewed tour detail
  Tour? _currentTour;
  List<Person> _currentTourParticipants = [];
  Person? _currentTourAdvanceHolder;
  List<Expense> _currentTourExpenses = [];
  double _currentTourTotalSpent = 0.0;
  Map<int, double> _currentTourPaymentsByPerson = {}; // Map<personId, totalPaid>
  Map<int, Person> _peopleMap = {}; // Cache people for quicker lookup by ID

  List<Tour> get tours => [..._tours]; // Return copies
  List<Person> get people => [..._people];
  List<Category> get categories => [..._categories];
  bool get isLoading => _isLoading;

  Tour? get currentTour => _currentTour;
  List<Person> get currentTourParticipants => _currentTourParticipants;
  Person? get currentTourAdvanceHolder => _currentTourAdvanceHolder;
  List<Expense> get currentTourExpenses => _currentTourExpenses;
  double get currentTourTotalSpent => _currentTourTotalSpent;
  Map<int, double> get currentTourPaymentsByPerson => _currentTourPaymentsByPerson;
  Map<int, Person> get peopleMap => _peopleMap; // Expose map for lookups


  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  TourProvider() {
    // Load initial data when the provider is created
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    _setLoading(true);
    await fetchAllPeople(); // Fetch people first
    await fetchAllCategories();
    await fetchAllTours();
    _setLoading(false);
  }

  void _setLoading(bool value) {
    // Avoid unnecessary notifications if state hasn't changed
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  // --- People Methods ---
  Future<void> fetchAllPeople() async {
    _people = await _dbHelper.getAllPeople();
    // Update people map cache
    _peopleMap = {for (var p in _people) p.id!: p};
    notifyListeners();
  }

  Future<Person> addPerson(String name) async {
     final existing = await _dbHelper.getPersonByName(name.trim());
     if (existing != null) {
        // Optionally update local list if somehow out of sync, but usually just return existing
        if (!_people.any((p) => p.id == existing.id)) {
           _people.add(existing);
           _peopleMap[existing.id!] = existing; // Update cache
           notifyListeners();
        }
        return existing; // Return existing person
     }

     // Create new person
     final newPerson = Person(name: name.trim());
     final createdPerson = await _dbHelper.createPerson(newPerson);
     _people.add(createdPerson);
     _peopleMap[createdPerson.id!] = createdPerson; // Update cache
     notifyListeners();
     return createdPerson;
  }


  // --- Category Methods ---
   Future<void> fetchAllCategories() async {
    _categories = await _dbHelper.getAllCategories();
    notifyListeners();
  }

  Future<Category> addCategory(String name) async {
     final existing = await _dbHelper.getCategoryByName(name.trim());
     if (existing != null) {
         if (!_categories.any((c) => c.id == existing.id)) {
             _categories.add(existing);
             notifyListeners();
         }
         return existing;
     }
     final newCategory = Category(name: name.trim());
     final createdCategory = await _dbHelper.createCategory(newCategory);
     _categories.add(createdCategory);
     notifyListeners();
     return createdCategory;
  }

  // --- Tour Methods ---
  Future<void> fetchAllTours() async {
    _setLoading(true); // Indicate loading started
    _tours = await _dbHelper.getAllTours();
    // Ensure list is sorted (e.g., active first, then by date)
    _tours.sort((a, b) {
        if (a.status != TourStatus.Ended && b.status == TourStatus.Ended) return -1;
        if (a.status == TourStatus.Ended && b.status != TourStatus.Ended) return 1;
        return b.startDate.compareTo(a.startDate); // Sort by date descending otherwise
    });
    _setLoading(false); // Indicate loading finished (this notifies listeners)
  }

  Future<Tour> addTour(Tour tour, List<int> participantIds) async {
    _setLoading(true);
    final newTour = await _dbHelper.createTour(tour, participantIds);
    // Fetch again to maintain sort order and reflect DB state
    await fetchAllTours();
    // _tours.insert(0, newTour); // Add to beginning might break sort order
    _setLoading(false);
    return newTour;
  }

  Future<void> updateTour(Tour tour, List<int> participantIds) async {
    _setLoading(true);
    await _dbHelper.updateTour(tour, participantIds);
    final index = _tours.indexWhere((t) => t.id == tour.id);
    if (index != -1) {
       _tours[index] = tour; // Update local list immediately for responsiveness
       // Re-sort potentially needed if status/date changed affecting order
       _tours.sort((a, b) {
         if (a.status != TourStatus.Ended && b.status == TourStatus.Ended) return -1;
         if (a.status == TourStatus.Ended && b.status != TourStatus.Ended) return 1;
         return b.startDate.compareTo(a.startDate);
       });
    }
    // If this is the current tour, update its details too
    if (_currentTour?.id == tour.id) {
       await fetchTourDetails(tour.id!); // Refetch details
    } else {
       _setLoading(false); // Ensure loading state is reset if details weren't refetched
    }
    // fetchTourDetails calls setLoading(false) at the end, so no need here if called
  }

  Future<void> deleteTour(int tourId) async {
      _setLoading(true);
      await _dbHelper.deleteTour(tourId);
      _tours.removeWhere((t) => t.id == tourId);
      // If the deleted tour was the current one, clear details
      if (_currentTour?.id == tourId) {
          _clearCurrentTourDetails();
      }
      _setLoading(false);
  }

  Future<void> changeTourStatus(int tourId, TourStatus newStatus, {DateTime? endDate}) async {
      _setLoading(true); // Indicate loading
      final tourIndex = _tours.indexWhere((t) => t.id == tourId);
      if (tourIndex == -1) {
          _setLoading(false);
          return;
      }

      Tour currentTourState = _tours[tourIndex];
      Tour updatedTour = currentTourState.copy(
          status: newStatus,
          // Only set endDate if status is Ended AND it wasn't already set (or use provided)
          endDate: newStatus == TourStatus.Ended
                    ? (endDate ?? currentTourState.endDate ?? DateTime.now())
                    : currentTourState.endDate,
          // Explicitly clear end date if moving away from Ended status
          clearEndDate: currentTourState.status == TourStatus.Ended && newStatus != TourStatus.Ended
      );

      // Fetch participants to pass to updateTour (DB method requires it)
      List<Person> participants = await _dbHelper.getTourParticipants(tourId);
      List<int> participantIds = participants.map((p) => p.id!).toList();

      // Update using the general update method which handles DB and local state
      await updateTour(updatedTour, participantIds);
      // updateTour handles setLoading(false) and notifications
  }


  // --- Current Tour Detail Methods ---
  void _clearCurrentTourDetails() {
      _currentTour = null;
      _currentTourParticipants = [];
      _currentTourAdvanceHolder = null;
      _currentTourExpenses = [];
      _currentTourTotalSpent = 0.0;
      _currentTourPaymentsByPerson = {};
      // Don't notify here, let the caller decide (e.g., fetchTourDetails or deleteTour)
  }

  Future<void> fetchTourDetails(int tourId) async {
    _setLoading(true);
    _clearCurrentTourDetails(); // Clear previous details first

    _currentTour = await _dbHelper.getTour(tourId);

    if (_currentTour != null) {
      // Fetch related data in parallel for efficiency
      final results = await Future.wait([
          _dbHelper.getTourParticipants(tourId),
          _dbHelper.getPerson(_currentTour!.advanceHolderPersonId),
          _dbHelper.getExpensesForTour(tourId),
          _dbHelper.getTotalExpensesForTour(tourId),
          _dbHelper.getPaymentsPerPersonForTour(tourId),
          // Removed pre-loading expense details here for simplicity
      ]);

      _currentTourParticipants = results[0] as List<Person>;
      _currentTourAdvanceHolder = results[1] as Person?;
      _currentTourExpenses = results[2] as List<Expense>;
      _currentTourTotalSpent = results[3] as double;
      _currentTourPaymentsByPerson = results[4] as Map<int, double>;

    }
    // Don't clear again if not found, _clearCurrentTourDetails was called at start
    _setLoading(false); // Notifies listeners
  }

  // --- Expense Methods (relative to current tour) ---
  Future<Expense> addExpenseToCurrentTour(Expense expense, List<int> attendeeIds, List<ExpensePayment> payments) async {
      if (_currentTour == null) {
          throw Exception("No current tour selected to add expense to.");
      }
      _setLoading(true);
      // Ensure the expense has the correct tourId
      final expenseToAdd = expense.copy(tourId: _currentTour!.id);
      final newExpense = await _dbHelper.createExpense(expenseToAdd, attendeeIds, payments);

      // Refresh current tour data silently (don't show global loading indicator again)
      await _refreshCurrentTourDataOnExpenseChange();
      _setLoading(false); // Set loading false after refresh is done

      // Find the newly added expense in the refreshed list to return it
      final addedExpense = _currentTourExpenses.firstWhere((e) => e.id == newExpense.id, orElse: () => newExpense);
      return addedExpense;
  }

  Future<void> updateExpenseInCurrentTour(Expense expense, List<int> attendeeIds, List<ExpensePayment> payments) async {
     if (_currentTour == null || expense.id == null) {
         throw Exception("Cannot update expense without a current tour or expense ID.");
     }
     _setLoading(true);
     await _dbHelper.updateExpense(expense, attendeeIds, payments);
     // Refresh current tour data silently
     await _refreshCurrentTourDataOnExpenseChange();
     _setLoading(false);
  }

  Future<void> deleteExpenseFromCurrentTour(int expenseId) async {
     if (_currentTour == null) {
          throw Exception("No current tour selected to delete expense from.");
      }
      _setLoading(true);
      await _dbHelper.deleteExpense(expenseId);
      // Refresh current tour data silently
      await _refreshCurrentTourDataOnExpenseChange();
      _setLoading(false);
  }

  // Helper to refresh necessary tour details after expense CRUD without full page reload indicator
  Future<void> _refreshCurrentTourDataOnExpenseChange() async {
     if (_currentTour == null) return;
      // Refetch only data affected by expense changes
       final results = await Future.wait([
          _dbHelper.getExpensesForTour(_currentTour!.id!),
          _dbHelper.getTotalExpensesForTour(_currentTour!.id!),
          _dbHelper.getPaymentsPerPersonForTour(_currentTour!.id!),
      ]);
       _currentTourExpenses = results[0] as List<Expense>;
       _currentTourTotalSpent = results[1] as double;
       _currentTourPaymentsByPerson = results[2] as Map<int, double>;
       // No need to notify here, the main methods (add/update/delete expense) will handle it
  }


  // --- Helper to get Person Name from ID ---
  String getPersonNameById(int personId) {
      return _peopleMap[personId]?.name ?? 'Unknown Person [$personId]';
  }

  // --- Helper to get Category Name from ID ---
   String getCategoryNameById(int categoryId) {
       final category = _categories.firstWhere((cat) => cat.id == categoryId, orElse: () => const Category(id: -1, name: 'Unknown'));
       return category.name;
   }
}
```

```markdown
// FILE: lib/screens/tour_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:btour/models/tour.dart';
import 'package:btour/providers/tour_provider.dart';
import 'package:btour/screens/add_edit_tour_screen.dart';
import 'package:btour/screens/tour_detail_screen.dart';
import 'package:btour/widgets/tour_card.dart'; // Create this widget

class TourListScreen extends StatefulWidget {
  const TourListScreen({super.key});

  @override
  State<TourListScreen> createState() => _TourListScreenState();
}

class _TourListScreenState extends State<TourListScreen> {

  // No initState needed as Provider handles initial loading

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tour Expense Tracker'),
        actions: [
          // Optional: Add actions like managing people globally
          // IconButton(
          //   icon: Icon(Icons.people),
          //   onPressed: () { /* Navigate to manage people screen */ },
          // ),
        ],
      ),
      body: Consumer<TourProvider>(
        builder: (context, tourProvider, child) {
          // Show loading indicator only during the very initial load
          if (tourProvider.isLoading && tourProvider.tours.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Separate tours based on status AFTER checking for empty list
          final activeTours = tourProvider.tours
              .where((tour) => tour.status != TourStatus.Ended)
              .toList();
          final finishedTours = tourProvider.tours
              .where((tour) => tour.status == TourStatus.Ended)
              .toList();

          // Handle case where there are tours, but all might be filtered out (unlikely here but good practice)
           if (tourProvider.tours.isEmpty && !tourProvider.isLoading) {
             return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No tours yet. Tap the "+" button to create your first tour!',
                     textAlign: TextAlign.center,
                     style: TextStyle(fontSize: 16, color: Colors.grey),
                     ),
                )
             );
          }


          return RefreshIndicator(
             onRefresh: () => tourProvider.fetchAllTours(), // Refresh only tours on pull-down
             child: ListView(
                padding: const EdgeInsets.all(8.0),
                children: [
                  if (activeTours.isNotEmpty)
                     _buildSectionTitle(context, 'Active Tours (${activeTours.length})'),
                  ...activeTours.map((tour) => TourCard(
                        tour: tour,
                        onTap: () => _navigateToTourDetail(context, tour.id!),
                      )).toList(),

                  if (finishedTours.isNotEmpty) ...[
                     if (activeTours.isNotEmpty) const SizedBox(height: 16), // Add space only if active tours exist
                     _buildSectionTitle(context, 'Finished Tours (${finishedTours.length})'),
                    ...finishedTours.map((tour) => TourCard(
                           tour: tour,
                           onTap: () => _navigateToTourDetail(context, tour.id!),
                         )).toList(),
                  ],

                   // Add some bottom padding if needed
                   const SizedBox(height: 80),
                ],
              ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Ensure necessary data (like people) is available before navigating
          final tourProvider = Provider.of<TourProvider>(context, listen: false);
          if (tourProvider.people.isEmpty) {
             // Optionally fetch people again or show a message
             tourProvider.fetchAllPeople().then((_) {
                Navigator.of(context).push(
                 MaterialPageRoute(builder: (context) => const AddEditTourScreen()),
               );
             });
          } else {
             Navigator.of(context).push(
               MaterialPageRoute(builder: (context) => const AddEditTourScreen()),
             );
          }
        },
        tooltip: 'Add Tour',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
     return Padding(
       padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
       child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
     );
  }


  void _navigateToTourDetail(BuildContext context, int tourId) {
     // Fetch details *before* navigating to ensure the detail screen has data
     // Show loading indicator potentially
     final tourProvider = Provider.of<TourProvider>(context, listen: false);

     // Show a loading dialog while fetching details
      showDialog(
        context: context,
        barrierDismissible: false, // Prevent closing while loading
        builder: (BuildContext context) {
          return const Center(child: CircularProgressIndicator());
        },
      );


     tourProvider.fetchTourDetails(tourId).then((_) {
        Navigator.of(context).pop(); // Close the loading dialog
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const TourDetailScreen()),
        );
     }).catchError((error) {
         Navigator.of(context).pop(); // Close the loading dialog on error too
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error loading tour details: $error')),
         );
     });
  }
}
```

```markdown
// FILE: lib/widgets/tour_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For currency formatting
import 'package:provider/provider.dart';
import 'package:btour/models/tour.dart';
import 'package:btour/providers/tour_provider.dart'; // To get holder name etc.

class TourCard extends StatelessWidget {
  final Tour tour;
  final VoidCallback onTap;

  const TourCard({
    super.key,
    required this.tour,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Use provider for lookups but don't need to listen here
    final tourProvider = Provider.of<TourProvider>(context, listen: false);
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: "\$"); // Example INR

    return Card(
      clipBehavior: Clip.antiAlias, // Ensures inkwell ripple stays within bounds
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tour Name and Status Chip row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded( // Allow name to take available space
                    child: Text(
                      tour.name,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 2, // Allow wrapping slightly
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8), // Space before chip
                  Chip(
                    label: Text(tour.statusString),
                    backgroundColor: _getStatusColor(tour.status),
                    labelStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Date Range
              Text(
                '${tour.formattedStartDate} - ${tour.formattedEndDate}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),

              // Advance Holder
              Text.rich(
                 TextSpan(
                   text: 'Holder: ',
                   style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                   children: [
                     TextSpan(
                       text: tourProvider.getPersonNameById(tour.advanceHolderPersonId),
                       style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                     ),
                   ]
                 ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Advance Amount
              Text(
                 'Advance: ${currencyFormat.format(tour.advanceAmount)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.green.shade700),
              ),

              // Show Spent/Remaining only for Finished tours on the card
              if (tour.status == TourStatus.Ended)
                 Padding(
                   padding: const EdgeInsets.only(top: 6.0),
                   child: FutureBuilder<double>(
                     // Fetch total spent specifically for this finished card
                     // This ensures accuracy even if provider state isn't perfectly synced
                     // Could be optimized if performance becomes an issue
                     future: tourProvider.getTotalExpensesForTour(tour.id!),
                     builder: (context, snapshot) {
                       if (snapshot.connectionState == ConnectionState.waiting) {
                         // Show a placeholder or small indicator
                         return Row(
                             mainAxisAlignment: MainAxisAlignment.end,
                             children: [
                               Text('Calculating...', style: Theme.of(context).textTheme.bodySmall),
                             ],
                         );
                       }
                       if (snapshot.hasError) {
                          return Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('Error', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red)),
                             ],
                          );
                       }

                       final spent = snapshot.data ?? 0.0;
                       final remaining = tour.advanceAmount - spent;
                       return Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Text(
                             'Spent: ${currencyFormat.format(spent)}',
                             style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red.shade700),
                           ),
                           Text(
                             'Remaining: ${currencyFormat.format(remaining)}',
                             style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                 fontWeight: FontWeight.bold,
                                 color: remaining >= 0 ? Colors.blue.shade800 : Colors.orange.shade900),
                           ),
                         ],
                       );
                     },
                   ),
                 ),

              // Optionally show participant count asynchronously
              // FutureBuilder<List<Person>>(
              //   future: tourProvider.getTourParticipants(tour.id!),
              //   builder: (context, snapshot) {
              //     if (snapshot.hasData) {
              //       return Text('Participants: ${snapshot.data!.length}', style: Theme.of(context).textTheme.bodySmall);
              //     }
              //     return SizedBox.shrink(); // Or a placeholder
              //   }
              // ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(TourStatus status) {
     switch (status) {
        case TourStatus.Created: return Colors.grey.shade500;
        case TourStatus.Started: return Colors.blue.shade600;
        case TourStatus.Ended: return Colors.green.shade600;
     }
  }
}
```

```markdown
// FILE: lib/screens/add_edit_tour_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:btour/models/person.dart';
import 'package:btour/models/tour.dart';
import 'package:btour/providers/tour_provider.dart';
import 'package:btour/widgets/person_multi_selector.dart';

class AddEditTourScreen extends StatefulWidget {
  final Tour? tourToEdit; // Pass tour if editing

  const AddEditTourScreen({super.key, this.tourToEdit});

  bool get isEditing => tourToEdit != null;

  @override
  State<AddEditTourScreen> createState() => _AddEditTourScreenState();
}

class _AddEditTourScreenState extends State<AddEditTourScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _advanceAmountController;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate; // Nullable for ongoing tours
  Person? _selectedAdvanceHolder;
  List<Person> _selectedParticipants = [];
  List<Person> _allPeople = []; // To populate dropdowns/selectors

  bool _isLoading = false; // Local loading state for form submission
  bool _isDataLoading = true; // Separate state for initial data loading


  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tourToEdit?.name);
    _advanceAmountController = TextEditingController(
        text: widget.tourToEdit?.advanceAmount.toStringAsFixed(2) ?? '');
    _startDate = widget.tourToEdit?.startDate ?? DateTime.now();
    _endDate = widget.tourToEdit?.endDate; // Can be null

    // Fetch available people and set initial selections if editing
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
     setState(() => _isDataLoading = true);
     final tourProvider = Provider.of<TourProvider>(context, listen: false);
     // Ensure people list is up-to-date, fetch if needed
     if(tourProvider.people.isEmpty) {
        await tourProvider.fetchAllPeople();
     }
     _allPeople = tourProvider.people;

     if (widget.isEditing && widget.tourToEdit != null) {
        // Pre-select advance holder safely
        try {
           _selectedAdvanceHolder = _allPeople.firstWhere(
               (p) => p.id == widget.tourToEdit!.advanceHolderPersonId,
            );
        } catch (e) {
           print("Error finding initial advance holder: $e");
           // Handle case where holder might have been deleted? Assign null or first person?
           _selectedAdvanceHolder = null; // Or _allPeople.isNotEmpty ? _allPeople.first : null;
        }


        // Pre-select participants
        final participants = await DatabaseHelper.instance.getTourParticipants(widget.tourToEdit!.id!); // Direct DB call ok here
        _selectedParticipants = participants;


        // Ensure advance holder is also in participants list UI state if not already
         if (_selectedAdvanceHolder != null && !_selectedParticipants.any((p) => p.id == _selectedAdvanceHolder!.id)) {
             // The multi-selector will get the correct initial list, just ensure the dropdown is set.
             // No need to add to _selectedParticipants here if it's correctly loaded above.
         }

     } else {
        // Default selection for new tour (optional)
        // _selectedAdvanceHolder = _allPeople.isNotEmpty ? _allPeople.first : null;
        // _selectedParticipants = _selectedAdvanceHolder != null ? [_selectedAdvanceHolder!] : [];
     }

     setState(() => _isDataLoading = false);
  }


  @override
  void dispose() {
    _nameController.dispose();
    _advanceAmountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime initial = isStartDate ? _startDate : (_endDate ?? _startDate.add(const Duration(days: 1))); // Suggest end date after start
    final DateTime first = isStartDate ? DateTime(2000) : _startDate; // End date cannot be before start date
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // If end date is before new start date, reset end date
          if (_endDate != null && _endDate!.isBefore(_startDate)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
       if (_selectedAdvanceHolder == null) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Please select an Advance Holder.'), backgroundColor: Colors.redAccent),
         );
         return;
       }
       if (_selectedParticipants.isEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Please select at least one Participant.'), backgroundColor: Colors.redAccent),
         );
         return;
       }
        // Ensure Advance Holder is included in participants internally before saving
       List<Person> finalParticipants = List.from(_selectedParticipants);
       if (!finalParticipants.any((p) => p.id == _selectedAdvanceHolder!.id)) {
            finalParticipants.add(_selectedAdvanceHolder!);
       }


       setState(() => _isLoading = true);

       final tourProvider = Provider.of<TourProvider>(context, listen: false);
       final participantIds = finalParticipants.map((p) => p.id!).toList();
       final advanceAmount = double.tryParse(_advanceAmountController.text) ?? 0.0;


       try {
         if (widget.isEditing) {
           // Update existing tour
           final updatedTour = widget.tourToEdit!.copy(
             name: _nameController.text.trim(),
             startDate: _startDate,
             endDate: _endDate, // Pass the potentially updated end date
             clearEndDate: _endDate == null && widget.tourToEdit!.endDate != null, // Clear only if it was previously set
             advanceAmount: advanceAmount,
             advanceHolderPersonId: _selectedAdvanceHolder!.id!,
             // Status is handled separately via Tour Detail Screen actions
           );
           await tourProvider.updateTour(updatedTour, participantIds);
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Tour Updated Successfully!'), backgroundColor: Colors.green),
           );

         } else {
           // Create new tour
           final newTour = Tour(
             name: _nameController.text.trim(),
             startDate: _startDate,
             endDate: _endDate,
             advanceAmount: advanceAmount,
             advanceHolderPersonId: _selectedAdvanceHolder!.id!,
             status: TourStatus.Created, // Default status
           );
           await tourProvider.addTour(newTour, participantIds);
            ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Tour Created Successfully!'), backgroundColor: Colors.green),
           );
         }
         // Pop only after successful operation
          if (mounted) { // Check if the widget is still in the tree
             Navigator.of(context).pop();
          }
       } catch (e) {
          print("Error saving tour: $e");
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Error saving tour: ${e.toString()}'), backgroundColor: Colors.redAccent),
          );
       } finally {
         // Check mounted again before calling setState
         if (mounted) {
           setState(() => _isLoading = false);
         }
       }
    }
  }

  // Function to add a new person (used by PersonMultiSelector callback)
  Future<Person?> _addNewPerson(String name) async {
      if (name.trim().isEmpty) return null;
      setState(() => _isLoading = true); // Show loading indicator while adding person
      final tourProvider = Provider.of<TourProvider>(context, listen: false);
      try {
         final newPerson = await tourProvider.addPerson(name.trim());
         // Update the list of all people available for selection IN THIS SCREEN
         setState(() {
             _allPeople = tourProvider.people; // Refresh local copy of all people
         });
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('${newPerson.name} added.'), backgroundColor: Colors.green),
           );
         return newPerson; // Return the created/found person to the selector
      } catch (e) {
          print("Error adding person: $e");
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Error adding person: $e'), backgroundColor: Colors.redAccent),
           );
          return null;
      } finally {
          if(mounted) {
            setState(() => _isLoading = false);
          }
      }
  }


  @override
  Widget build(BuildContext context) {
     final dateFormat = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Tour' : 'Add New Tour'),
        actions: [
          if (_isLoading || _isDataLoading) const Padding(
             padding: EdgeInsets.only(right: 16.0),
             child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))),
          if (!_isLoading && !_isDataLoading) IconButton(
            icon: const Icon(Icons.save),
            onPressed: _submitForm,
            tooltip: 'Save Tour',
          ),
        ],
      ),
      body: _isDataLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Tour Name *'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a tour name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // --- Start & End Dates ---
                    Row(
                      children: [
                         Expanded(
                           child: InkWell(
                             onTap: () => _selectDate(context, true),
                             child: InputDecorator(
                               decoration: const InputDecoration(
                                 labelText: 'Start Date *',
                                 border: OutlineInputBorder()
                               ),
                               child: Text(dateFormat.format(_startDate)),
                             ),
                           ),
                         ),
                         const SizedBox(width: 10),
                         Expanded(
                            child: InkWell(
                              onTap: () => _selectDate(context, false),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                   labelText: 'End Date (Optional)',
                                   border: const OutlineInputBorder(),
                                   suffixIcon: _endDate != null ? IconButton(
                                       icon: const Icon(Icons.clear, size: 20),
                                       onPressed: () => setState(() => _endDate = null),
                                       tooltip: 'Clear End Date',
                                   ) : null,
                                ),
                                child: Text(_endDate != null ? dateFormat.format(_endDate!) : 'Set End Date...'),
                              ),
                            ),
                         ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _advanceAmountController,
                      decoration: const InputDecoration(
                          labelText: 'Advance Amount *', prefixText: "\$"),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          // Allow 0 amount
                          _advanceAmountController.text = '0.00'; // Default to 0 if empty
                           // return 'Please enter an advance amount';
                        }
                        if (double.tryParse(value) == null || double.parse(value) < 0) {
                          return 'Please enter a valid non-negative amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // --- Advance Holder Dropdown ---
                     DropdownButtonFormField<Person>(
                      value: _selectedAdvanceHolder,
                      items: _allPeople.map((Person person) {
                        return DropdownMenuItem<Person>(
                          value: person,
                          child: Text(person.name),
                        );
                      }).toList(),
                      onChanged: (Person? newValue) {
                        setState(() {
                          _selectedAdvanceHolder = newValue;
                          // // Auto-add holder to participants is handled by the multi-selector logic if needed
                          // if (newValue != null && !_selectedParticipants.any((p) => p.id == newValue.id)) {
                          //     // We need to trigger an update in the child widget state if needed
                          //     // It might be better to just ensure they are added before saving.
                          // }
                        });
                      },
                      decoration: const InputDecoration(
                          labelText: 'Advance Holder *',
                          hintText: 'Select who holds the cash',
                          border: OutlineInputBorder()
                      ),
                      validator: (value) => value == null ? 'Please select an advance holder' : null,
                    ),
                    const SizedBox(height: 20),

                    // --- Participants Multi-Selector ---
                    Text('Participants *', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    PersonMultiSelector(
                       // Use a key to force rebuild if allPeople list changes significantly (e.g., after adding new person)
                       key: ValueKey(_allPeople.length),
                       allPeople: _allPeople,
                       initialSelectedPeople: _selectedParticipants,
                       advanceHolder: _selectedAdvanceHolder, // Pass the holder
                       onSelectionChanged: (selected) {
                          // Update local state when selector changes
                          setState(() {
                             _selectedParticipants = selected;
                          });
                       },
                       onAddPerson: _addNewPerson, // Pass function to handle adding new people
                       // Add validation feedback directly? Or rely on form submit check?
                    ),
                     if (_selectedParticipants.isEmpty) // Show helper text if nothing selected yet
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0, left: 8.0),
                        child: Text(
                          'Select at least one participant.',
                          style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                        ),
                      ),


                    const SizedBox(height: 30),
                    // Save Button is in AppBar
                  ],
                ),
              ),
            ),
    );
  }
}
```

```markdown
// FILE: lib/widgets/person_multi_selector.dart
import 'package:flutter/material.dart';
import 'package:btour/models/person.dart';
import 'package:collection/collection.dart'; // Import for firstWhereOrNull

// Simple Multi-selector using Chips and an Add button/dialog
class PersonMultiSelector extends StatefulWidget {
  final List<Person> allPeople;
  final List<Person> initialSelectedPeople;
  final Person? advanceHolder; // To ensure holder chip isn't deletable easily
  final ValueChanged<List<Person>> onSelectionChanged;
  final Future<Person?> Function(String name)? onAddPerson; // Callback to add new person

  const PersonMultiSelector({
    super.key,
    required this.allPeople,
    required this.initialSelectedPeople,
    this.advanceHolder,
    required this.onSelectionChanged,
    this.onAddPerson,
  });

  @override
  State<PersonMultiSelector> createState() => _PersonMultiSelectorState();
}

class _PersonMultiSelectorState extends State<PersonMultiSelector> {
  late List<Person> _selectedPeople;
  final TextEditingController _addPersonController = TextEditingController(); // For Add dialog
  final FocusNode _addPersonFocusNode = FocusNode(); // To focus text field

  @override
  void initState() {
    super.initState();
    // Copy initial list to allow modification, ensure uniqueness just in case
    _selectedPeople = widget.initialSelectedPeople.toSet().toList();
    _sortSelectedPeople();
  }

   // Update selected people if the initial list or advance holder changes externally
   // Use didUpdateWidget to sync state ONLY if the incoming props are different AND
   // the internal state hasn't been changed by the user in a way that conflicts.
   @override
  void didUpdateWidget(PersonMultiSelector oldWidget) {
    super.didUpdateWidget(oldWidget);

    bool initialListChanged = !const ListEquality().equals(widget.initialSelectedPeople, oldWidget.initialSelectedPeople);
    bool holderChanged = widget.advanceHolder != oldWidget.advanceHolder;

    if (initialListChanged) {
       // If the initial list from parent changed, update internal state
        setState(() {
          _selectedPeople = widget.initialSelectedPeople.toSet().toList();
           _sortSelectedPeople();
        });
    }

    // Ensure advance holder is always included if provided
    if (widget.advanceHolder != null && !_selectedPeople.any((p) => p.id == widget.advanceHolder!.id)) {
       setState(() {
          _selectedPeople.add(widget.advanceHolder!);
          _sortSelectedPeople();
          // Notify parent immediately about the addition of the holder
           widget.onSelectionChanged(_selectedPeople);
       });
    } else if (holderChanged && widget.advanceHolder == null && oldWidget.advanceHolder != null) {
       // If holder was removed externally, allow removing them (handled by normal chip delete)
       // No immediate action needed here, but the chip will become deletable.
    }
  }

  void _sortSelectedPeople() {
     _selectedPeople.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  void dispose() {
    _addPersonController.dispose();
    _addPersonFocusNode.dispose();
    super.dispose();
  }

  void _showAddPersonDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        Person? selectedPersonFromDropdown; // Person selected from dropdown
        String? errorText; // For validation in dialog

        // Filter list for dropdown: exclude already selected people
        final availablePeople = widget.allPeople
            .where((p) => !_selectedPeople.any((sp) => sp.id == p.id))
            .toList();
        availablePeople.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())); // Sort dropdown list

        return StatefulBuilder( // Use StatefulBuilder for dialog state
           builder: (context, setDialogState) {
             return AlertDialog(
                title: const Text('Add Participant'),
                contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0.0), // Adjust padding
                content: SingleChildScrollView( // Allow content to scroll if needed
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       // --- Dropdown for existing ---
                       if (availablePeople.isNotEmpty)
                         DropdownButton<Person>(
                           value: selectedPersonFromDropdown,
                           hint: const Text('Select existing person'),
                           isExpanded: true,
                           items: availablePeople.map((Person person) {
                             return DropdownMenuItem<Person>(
                               value: person,
                               child: Text(person.name),
                             );
                           }).toList(),
                           onChanged: (Person? newValue) {
                               setDialogState(() { // Update dialog state
                                 selectedPersonFromDropdown = newValue;
                                 _addPersonController.clear(); // Clear text field if dropdown used
                                 errorText = null; // Clear error on valid selection
                               });
                           },
                         ),
                       if (availablePeople.isNotEmpty && widget.onAddPerson != null)
                          const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Center(child: Text("OR")),
                          ),

                       // --- Text field for new person ---
                       if (widget.onAddPerson != null)
                          TextField(
                           controller: _addPersonController,
                           focusNode: _addPersonFocusNode, // Assign focus node
                           decoration: InputDecoration(
                             labelText: 'Add New Person Name',
                             errorText: errorText, // Show validation error
                           ),
                           textCapitalization: TextCapitalization.words,
                           onChanged: (value) {
                              // Clear dropdown selection if user starts typing a new name
                              if (value.isNotEmpty && selectedPersonFromDropdown != null) {
                                  setDialogState(() {
                                      selectedPersonFromDropdown = null;
                                      errorText = null; // Clear error
                                  });
                              } else if (value.isEmpty) {
                                  setDialogState(() { errorText = null; }); // Clear error if field cleared
                              }
                           },
                         ),
                    ],
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () {
                      _addPersonController.clear(); // Clear controller on cancel
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    child: const Text('Add'),
                    onPressed: () async {
                      final String newName = _addPersonController.text.trim();

                      // --- Validation ---
                      if (selectedPersonFromDropdown == null && newName.isEmpty) {
                         setDialogState(() { errorText = 'Please select or enter a name'; });
                         return; // Prevent closing
                      }
                      // Check if new name already exists in allPeople (case-insensitive)
                      final existingPerson = widget.allPeople.firstWhereOrNull(
                          (p) => p.name.toLowerCase() == newName.toLowerCase());

                      if (newName.isNotEmpty && existingPerson != null) {
                         // Name exists, check if they are already selected
                         if (_selectedPeople.any((p) => p.id == existingPerson.id)) {
                            setDialogState(() { errorText = '"${existingPerson.name}" is already selected'; });
                         } else {
                            // Person exists but isn't selected, add them
                             _addSelectedPerson(existingPerson);
                             _addPersonController.clear();
                             Navigator.of(context).pop(); // Close dialog
                         }
                         return; // Prevent further action
                      }
                      // --- End Validation ---


                      // --- Add Logic ---
                      if (selectedPersonFromDropdown != null) {
                          // Add selected existing person
                          _addSelectedPerson(selectedPersonFromDropdown!);
                          _addPersonController.clear();
                           Navigator.of(context).pop();
                      } else if (newName.isNotEmpty && widget.onAddPerson != null) {
                         // Try adding the new person via the callback (which handles DB interaction)
                         // Show loading within dialog? Or just close and let screen handle indicator?
                         // For simplicity, close dialog and let screen show loading.
                         Navigator.of(context).pop(); // Close dialog first
                         final addedPerson = await widget.onAddPerson!(newName);
                         if (addedPerson != null) {
                            _addSelectedPerson(addedPerson); // Add the newly created/found person to UI
                         }
                         _addPersonController.clear();
                         // Error handling for addPerson is done in the callback provider/screen
                      }
                    },
                  ),
                ],
             );
           }
        );
      },
    ).then((_) {
      // Ensure text field loses focus when dialog is closed
      _addPersonFocusNode.unfocus();
    });
  }

  void _addSelectedPerson(Person person) {
    // Add person if not already selected
    if (!_selectedPeople.any((p) => p.id == person.id)) {
      setState(() {
        _selectedPeople.add(person);
        _sortSelectedPeople(); // Sort after adding
      });
      widget.onSelectionChanged(_selectedPeople); // Notify parent
    } else {
       // Optionally show message if already added (e.g., from existing check)
        ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('${person.name} is already selected.'), duration: const Duration(seconds: 2)),
       );
    }
  }

  void _removeSelectedPerson(Person person) {
     // Prevent removing the designated advance holder
     if (widget.advanceHolder != null && person.id == widget.advanceHolder!.id) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('${person.name} is the Advance Holder and cannot be removed here.'), duration: Duration(seconds: 3)),
       );
       return;
     }
     setState(() {
       _selectedPeople.removeWhere((p) => p.id == person.id);
       // No need to re-sort on removal
     });
     widget.onSelectionChanged(_selectedPeople); // Notify parent
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 50), // Ensure minimum height
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(5.0),
      ),
      child: Wrap(
        spacing: 6.0, // Horizontal space between chips
        runSpacing: 0.0, // Vertical space between lines of chips
        crossAxisAlignment: WrapCrossAlignment.center, // Align chips vertically
        children: [
          ..._selectedPeople.map((person) {
              final bool isHolder = widget.advanceHolder != null && person.id == widget.advanceHolder!.id;
              return Chip(
                label: Text(person.name),
                // Add visual cue for advance holder? e.g., different color or icon
                backgroundColor: isHolder ? Colors.blue.shade100 : null,
                 labelStyle: TextStyle(
                    fontWeight: isHolder ? FontWeight.bold : FontWeight.normal,
                    // color: isHolder ? Colors.blue.shade900 : null,
                 ),
                deleteIconColor: isHolder ? Colors.grey.shade300 : Colors.grey.shade700, // Dim delete icon for holder
                onDeleted: isHolder ? null : () => _removeSelectedPerson(person), // Disable delete for holder
              );
          }),
          // Only show Add button if callback is provided
          if (widget.onAddPerson != null)
            InkWell( // Use InkWell for larger tap area
               onTap: _showAddPersonDialog,
               child: const Chip( // Use a chip for consistent styling
                 avatar: Icon(Icons.add_circle_outline, size: 18, color: Colors.blue),
                 label: Text('Add Person'),
                 visualDensity: VisualDensity.compact,
                 padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
               ),
               // ActionChip( // Alternative styling
               //   avatar: const Icon(Icons.add, size: 18),
               //   label: const Text('Add'),
               //   onPressed: _showAddPersonDialog,
               //   tooltip: 'Add Participant',
               //    visualDensity: VisualDensity.compact,
               // ),
            ),
        ],
      ),
    );
  }
}
```

```markdown
// FILE: lib/screens/tour_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:btour/models/person.dart'; // Need for report tab person lookup
import 'package:btour/models/tour.dart';
import 'package:btour/providers/tour_provider.dart';
import 'package:btour/screens/add_edit_expense_screen.dart';
import 'package:btour/screens/add_edit_tour_screen.dart';
import 'package:btour/widgets/expense_list_item.dart';

class TourDetailScreen extends StatelessWidget {
  const TourDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to provider changes to update the UI
    final tourProvider = Provider.of<TourProvider>(context);
    final tour = tourProvider.currentTour; // Get the currently loaded tour
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: "\$");

    // Handle loading state managed by the provider
    if (tourProvider.isLoading && tour == null) {
      // Initial loading state when navigating here
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Tour...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Handle case where tour loading finished but resulted in null (e.g., tour deleted)
    if (tour == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(
          child: Text('Tour not found or could not be loaded.'),
        ),
      );
    }

    // Calculate remaining amount based on current provider state
    final remainingAmount = tour.advanceAmount - tourProvider.currentTourTotalSpent;

    return DefaultTabController(
      length: 3, // Overview, Expenses, Report
      child: Scaffold(
        appBar: AppBar(
          title: Text(tour.name, overflow: TextOverflow.ellipsis),
          actions: [
            // Edit Tour Button - Enabled only if tour is not Ended
            IconButton(
              icon: const Icon(Icons.edit_note), // Different icon maybe?
              tooltip: 'Edit Tour Details',
              // Disable if tour is ended
              onPressed: tour.status == TourStatus.Ended
                  ? null
                  : () {
                      // Navigate to edit screen, passing the current tour object
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => AddEditTourScreen(tourToEdit: tour),
                      ));
                    },
            ),
             // Tour Status Actions (Start/End/Reopen)
            _buildStatusActionButton(context, tourProvider, tour),

             // Delete Tour Button (use with confirmation)
             IconButton(
               icon: Icon(Icons.delete_forever_outlined, color: Colors.red.shade700),
               tooltip: 'Delete Tour Permanently',
               onPressed: () => _confirmDeleteTour(context, tourProvider, tour.id!),
             ),
          ],
          bottom: const TabBar(
             labelColor: Colors.blue, // Color for selected tab text
             unselectedLabelColor: Colors.grey, // Color for unselected tab text
             indicatorColor: Colors.blue, // Color of the underline indicator
            tabs: [
              Tab(text: 'Overview', icon: Icon(Icons.info_outline)),
              Tab(text: 'Expenses', icon: Icon(Icons.receipt_long_outlined)),
              Tab(text: 'Report', icon: Icon(Icons.assessment_outlined)), // Changed icon
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // --- Overview Tab ---
            _buildOverviewTab(context, tourProvider, tour, remainingAmount, currencyFormat),

            // --- Expenses Tab ---
            _buildExpensesTab(context, tourProvider, tour),

            // --- Report Tab ---
            _buildReportTab(context, tourProvider, tour, currencyFormat),
          ],
        ),
         // Show FAB to add expenses only if tour is not ended
         floatingActionButton: tour.status == TourStatus.Ended ? null : FloatingActionButton(
            onPressed: () {
               // Ensure participants are loaded before navigating
               if (tourProvider.currentTourParticipants.isEmpty) {
                 // This shouldn't happen if fetchTourDetails worked, but as a safeguard:
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Participants not loaded. Cannot add expense.'))
                 );
                 return;
               }
               Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => AddEditExpenseScreen(tour: tour), // Pass current tour object
               ));
            },
            tooltip: 'Add New Expense',
            child: const Icon(Icons.add_shopping_cart), // Different Icon
         ),
      ),
    );
  }

  // --- Status Action Button Logic ---
  Widget _buildStatusActionButton(BuildContext context, TourProvider tourProvider, Tour tour) {
     switch (tour.status) {
       case TourStatus.Created:
         return IconButton(
           icon: const Icon(Icons.play_circle_outline, color: Colors.green),
           tooltip: 'Start Tour',
           onPressed: () async {
              // Show confirmation?
             await tourProvider.changeTourStatus(tour.id!, TourStatus.Started);
             if (context.mounted) { // Check mounted after async gap
                ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Tour Started!'), backgroundColor: Colors.green));
             }
           },
         );
       case TourStatus.Started:
          return IconButton(
             icon: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent),
             tooltip: 'End Tour',
             onPressed: () => _confirmEndTour(context, tourProvider, tour), // Use confirmation dialog
           );
       case TourStatus.Ended:
          return IconButton(
             icon: const Icon(Icons.refresh_outlined, color: Colors.orange),
             tooltip: 'Reopen Tour',
             onPressed: () async {
                // Show confirmation?
                await tourProvider.changeTourStatus(tour.id!, TourStatus.Started); // Reopen to 'Started' status
                 if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tour Reopened!'), backgroundColor: Colors.orange));
                 }
             },
           );
     }
  }

 // --- Confirmation Dialogs ---

  void _confirmEndTour(BuildContext context, TourProvider tourProvider, Tour tour) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Tour?'),
        content: const Text('Are you sure you want to mark this tour as ended? You can reopen it later if needed.'),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
             style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('End Tour'),
            onPressed: () async {
               Navigator.of(ctx).pop(); // Close dialog
               await tourProvider.changeTourStatus(tour.id!, TourStatus.Ended);
               if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Tour Ended! Final report available.'), backgroundColor: Colors.green));
               }
            },
          ),
        ],
      ),
    );
  }


  void _confirmDeleteTour(BuildContext context, TourProvider tourProvider, int tourId) {
     showDialog(
       context: context,
       builder: (ctx) => AlertDialog(
         title: const Text('Delete Tour Permanently?'),
         content: const Text(
           'WARNING: This will delete the tour and ALL associated expenses. This action cannot be undone.',
            style: TextStyle(color: Colors.redAccent),
         ),
         actions: <Widget>[
           TextButton(
             child: const Text('Cancel'),
             onPressed: () {
               Navigator.of(ctx).pop();
             },
           ),
           TextButton(
              style: TextButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
             child: const Text('DELETE PERMANENTLY'),
             onPressed: () async {
                Navigator.of(ctx).pop(); // Close dialog
                try {
                   await tourProvider.deleteTour(tourId);
                   // Navigate back to list screen after successful deletion
                   if (context.mounted) {
                     // Check if the current screen is still mounted before popping.
                      if (Navigator.canPop(context)) {
                          Navigator.of(context).pop(); // Pop detail screen
                      }
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text('Tour deleted successfully.'), backgroundColor: Colors.green));
                   }
                } catch (e) {
                    print("Error deleting tour: $e");
                    if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text('Error deleting tour: $e'), backgroundColor: Colors.redAccent),
                       );
                    }
                }
             },
           ),
         ],
       ),
     );
  }


  // --- Tab Builders ---

  Widget _buildOverviewTab(BuildContext context, TourProvider tourProvider, Tour tour, double remainingAmount, NumberFormat currencyFormat) {
    final participants = tourProvider.currentTourParticipants;
    final holder = tourProvider.currentTourAdvanceHolder;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           _buildInfoCard(
              context,
              title: 'Tour Details',
              icon: Icons.info_outline,
              children: [
                 _buildInfoRow(context, null, 'Dates:', '${tour.formattedStartDate} - ${tour.formattedEndDate}'),
                 _buildInfoRow(context, null, 'Status:', tour.statusString, chipColor: _getStatusColor(tour.status)),
                 _buildInfoRow(context, null, 'Advance Holder:', holder?.name ?? 'Loading...'),
              ],
           ),
           const SizedBox(height: 16),
           _buildInfoCard(
              context,
              title: 'Financials',
              icon: Icons.account_balance_wallet_outlined,
              children: [
                 _buildInfoRow(context, null, 'Advance:', currencyFormat.format(tour.advanceAmount), valueColor: Colors.green.shade700),
                 _buildInfoRow(context, null, 'Total Spent:', currencyFormat.format(tourProvider.currentTourTotalSpent), valueColor: Colors.red.shade700),
                 _buildInfoRow(context, null, 'Remaining:', currencyFormat.format(remainingAmount), valueColor: remainingAmount >= 0 ? Colors.blue.shade800 : Colors.orange.shade900, isBold: true),
              ]
           ),
           const SizedBox(height: 16),
           _buildInfoCard(
             context,
             title: 'Participants (${participants.length})',
             icon: Icons.people_outline,
             children: [
                if (participants.isEmpty)
                   const Text('No participants listed.')
                else
                   Padding(
                     padding: const EdgeInsets.only(top: 8.0), // Add padding above chips
                     child: Wrap(
                       spacing: 8.0,
                       runSpacing: 4.0,
                       children: participants.map((person) => Chip(
                          avatar: person.id == holder?.id ? const Icon(Icons.star, size: 16, color: Colors.orange) : null, // Mark holder
                          label: Text(person.name),
                          visualDensity: VisualDensity.compact,
                       )).toList(),
                     ),
                   ),
             ]
           ),
            // Add more overview details if needed
        ],
      ),
    );
  }

   // Helper for creating consistent info cards
   Widget _buildInfoCard(BuildContext context, {required String title, required IconData icon, required List<Widget> children}) {
      return Card(
         elevation: 1,
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
         child: Padding(
           padding: const EdgeInsets.all(12.0),
           child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Row(
                   children: [
                     Icon(icon, color: Theme.of(context).primaryColor, size: 20),
                     const SizedBox(width: 8),
                     Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                   ],
                 ),
                 const Divider(height: 16),
                 ...children,
              ],
           ),
         ),
      );
   }


  // Helper for creating consistent info rows within cards
  Widget _buildInfoRow(BuildContext context, IconData? icon, String label, String value, {Color? valueColor, Color? chipColor, bool isBold = false}) {
     Widget valueWidget = Text(
       value,
       style: Theme.of(context).textTheme.bodyLarge?.copyWith(
         color: valueColor,
         fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
       ),
       overflow: TextOverflow.ellipsis,
     );

     // Use chip for specific values like status
     if (chipColor != null) {
       valueWidget = Chip(
         label: Text(value),
         backgroundColor: chipColor,
         labelStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
         materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
         visualDensity: VisualDensity.compact,
       );
     }

     return Padding(
       padding: const EdgeInsets.symmetric(vertical: 4.0),
       child: Row(
         crossAxisAlignment: CrossAxisAlignment.start, // Align label top if value wraps
         children: [
           if(icon != null) ...[
              Icon(icon, color: Colors.grey.shade600, size: 18),
              const SizedBox(width: 8),
           ],
           SizedBox(
             width: 110, // Fixed width for label column
             child: Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey.shade700)),
           ),
           const SizedBox(width: 8),
           Expanded(child: valueWidget), // Value takes remaining space
         ],
       ),
     );
  }

  Color _getStatusColor(TourStatus status) {
     switch (status) {
        case TourStatus.Created: return Colors.grey.shade500;
        case TourStatus.Started: return Colors.blue.shade600;
        case TourStatus.Ended: return Colors.green.shade600;
     }
  }


  Widget _buildExpensesTab(BuildContext context, TourProvider tourProvider, Tour tour) {
    // Get expenses from provider (which should be up-to-date)
    final expenses = tourProvider.currentTourExpenses;

    // Check if data is loading (e.g., after adding/deleting an expense)
    if (tourProvider.isLoading) {
       return const Center(child: CircularProgressIndicator());
    }

    if (expenses.isEmpty) {
      return const Center(
        child: Padding(
           padding: EdgeInsets.all(16.0),
           child: Text(
              'No expenses added yet.\nTap the "+" button to add the first one!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
           ),
        ),
      );
    }

    return RefreshIndicator(
        onRefresh: () => tourProvider.fetchTourDetails(tour.id!), // Refresh all details on pull
        child: ListView.builder(
           padding: const EdgeInsets.only(top: 8, bottom: 80), // Padding for FAB and top space
          itemCount: expenses.length,
          itemBuilder: (context, index) {
            final expense = expenses[index];
            return ExpenseListItem(
              expense: expense,
              tourStatus: tour.status, // Pass status to enable/disable actions
              onTap: tour.status == TourStatus.Ended ? null : () { // Disable tap if ended
                  // Navigate to edit expense screen
                   Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => AddEditExpenseScreen(tour: tour, expenseToEdit: expense),
                   ));
              },
              onDelete: () => _confirmDeleteExpense(context, tourProvider, expense.id!),
            );
          },
        ),
    );
  }

  void _confirmDeleteExpense(BuildContext context, TourProvider tourProvider, int expenseId) {
     // Avoid showing dialog if context is no longer valid (e.g., screen already popped)
     if (!context.mounted) return;

     showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
           title: const Text('Delete Expense?'),
           content: const Text('Are you sure you want to delete this expense record?'),
           actions: <Widget>[
              TextButton(
                 child: const Text('Cancel'),
                 onPressed: () => Navigator.of(ctx).pop(),
              ),
              TextButton(
                 style: TextButton.styleFrom(foregroundColor: Colors.red),
                 child: const Text('Delete'),
                 onPressed: () async {
                    Navigator.of(ctx).pop(); // Close dialog first
                    try {
                       await tourProvider.deleteExpenseFromCurrentTour(expenseId);
                       if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(content: Text('Expense deleted.'), backgroundColor: Colors.green));
                       }
                    } catch (e) {
                       print("Error deleting expense: $e");
                        if (context.mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error deleting expense: $e'), backgroundColor: Colors.redAccent));
                        }
                    }
                 },
              ),
           ],
        ),
     );
   }


   Widget _buildReportTab(BuildContext context, TourProvider tourProvider, Tour tour, NumberFormat currencyFormat) {
       // Data from provider
       final paymentsByPerson = tourProvider.currentTourPaymentsByPerson; // Map<personId, amountPaid>
       final peopleMap = tourProvider.peopleMap; // Map<personId, Person> for name lookup
       final participants = tourProvider.currentTourParticipants; // Full list of participants
       final totalSpent = tourProvider.currentTourTotalSpent;
       final advance = tour.advanceAmount;
       final remaining = advance - totalSpent;

       if (tourProvider.isLoading) {
           return const Center(child: CircularProgressIndicator());
       }

       // --- Calculate Settlements (Simplified Example) ---
       // This is a basic calculation. Real settlement might be more complex (e.g., using Splitwise algorithm)
       // Calculate net balance per person: (Total Advance / #Participants) - (Total Spent / #Participants) + Individual Payments - (Average Individual Payment)
       // Simpler: How much each person is owed or owes relative to the *remaining advance*.
       // If remaining > 0, it should ideally go back to the advance holder.
       // If remaining < 0, the advance holder covered the difference initially.
       // The 'paymentsByPerson' map shows who *actually spent* cash.
       // Goal: Settle differences between what people paid and what the advance should have covered.

       Map<String, double> netBalance = {}; // Person Name -> Net Amount (Positive = Owes, Negative = Is Owed)
        final totalPaidByIndividuals = paymentsByPerson.values.fold(0.0, (sum, amount) => sum + amount);
       // If total paid != total spent, it implies some expenses were paid directly from advance cash without being recorded in payments table, or data inconsistency. Assume totalSpent is correct.

       if (participants.isNotEmpty) {
           final sharePerPerson = totalSpent / participants.length;
           for (var participant in participants) {
               final amountPaid = paymentsByPerson[participant.id] ?? 0.0;
               netBalance[participant.name] = amountPaid - sharePerPerson;
           }
       }
       // The advance holder's initial contribution needs consideration if remaining < 0.
       // For simplicity, we'll just show who paid what. Settlements would be a separate feature.


       // Create a list of report entries for display (who paid what)
       final paymentReportEntries = paymentsByPerson.entries.map((entry) {
           final personId = entry.key;
           final amountPaid = entry.value;
           final personName = peopleMap[personId]?.name ?? 'Unknown Person [$personId]';
           return MapEntry(personName, amountPaid);
       }).toList();
       // Sort by amount paid descending? Or name?
       paymentReportEntries.sort((a, b) => b.value.compareTo(a.value)); // Sort by amount paid desc


       return SingleChildScrollView(
           padding: const EdgeInsets.all(16.0),
           child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                   Text('Tour Financial Summary', style: Theme.of(context).textTheme.headlineSmall),
                   const SizedBox(height: 16),
                   _buildReportSummaryItem('Total Advance:', currencyFormat.format(advance), Colors.green.shade700),
                   _buildReportSummaryItem('Total Expenses:', currencyFormat.format(totalSpent), Colors.red.shade700),
                   _buildReportSummaryItem(
                       remaining >= 0 ? 'Remaining Balance:' : 'Overspent By:',
                       currencyFormat.format(remaining.abs()), // Show absolute value
                       remaining >= 0 ? Colors.blue.shade800 : Colors.orange.shade900,
                       isBold: true
                    ),

                   const Divider(height: 30, thickness: 1),

                   Text('Payments by Individuals', style: Theme.of(context).textTheme.headlineSmall),
                   const SizedBox(height: 8),
                   Text(
                      '(Shows who physically paid how much towards expenses during the tour. This helps in settling debts if personal cash was used.)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)
                   ),
                   const SizedBox(height: 16),

                   if (paymentReportEntries.isEmpty)
                      const Center(child: Text('No individual payments were recorded.', style: TextStyle(color: Colors.grey)))
                   else
                      Card( // Put the list in a card
                         elevation: 1,
                          child: ListView.separated(
                              shrinkWrap: true, // Important inside SingleChildScrollView
                              physics: const NeverScrollableScrollPhysics(), // Disable scrolling
                              itemCount: paymentReportEntries.length,
                              separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
                              itemBuilder: (context, index) {
                                  final entry = paymentReportEntries[index];
                                  return ListTile(
                                      dense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                      title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w500)), // Person Name
                                      trailing: Text(
                                          currencyFormat.format(entry.value), // Amount Paid
                                          style: const TextStyle(fontSize: 14),
                                      ),
                                  );
                              },
                          ),
                      ),

                    // --- Potential Future: Simplified Settlement Section ---
                    // const Divider(height: 30, thickness: 1),
                    // Text('Settlement Suggestion (Simplified)', style: Theme.of(context).textTheme.headlineSmall),
                    // const SizedBox(height: 8),
                    // Text(
                    //   '(Based on equal shares. Positive = Owes, Negative = Is Owed)',
                    //   style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)
                    // ),
                    // const SizedBox(height: 16),
                    // ...netBalance.entries.map((entry) => ListTile(
                    //      title: Text(entry.key),
                    //      trailing: Text(
                    //         currencyFormat.format(entry.value),
                    //         style: TextStyle(color: entry.value >= 0 ? Colors.red : Colors.green),
                    //      ),
                    // )),

               ],
           ),
       );
   }

    Widget _buildReportSummaryItem(String label, String value, Color valueColor, {bool isBold = false}) {
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5.0),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    Text(label, style: const TextStyle(fontSize: 16)),
                    Text(
                        value,
                        style: TextStyle(
                            fontSize: 16,
                            color: valueColor,
                            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                        ),
                    ),
                ],
            ),
        );
    }

}
```

```markdown
// FILE: lib/widgets/expense_list_item.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:btour/models/expense.dart';
import 'package:btour/models/tour.dart'; // To check tour status
import 'package:btour/providers/tour_provider.dart'; // To get category name

class ExpenseListItem extends StatelessWidget {
  final Expense expense;
  final TourStatus tourStatus; // To disable actions if tour ended
  final VoidCallback? onTap; // Nullable if disabled
  final VoidCallback onDelete;

  const ExpenseListItem({
    super.key,
    required this.expense,
    required this.tourStatus,
    this.onTap, // Make onTap nullable
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: "\$");
    // Use read to get provider without listening - safe within build method for lookups
    final tourProvider = context.read<TourProvider>();

    // Fetch category name using provider helper
    final categoryName = tourProvider.getCategoryNameById(expense.categoryId);

    final bool isTapEnabled = onTap != null; // Check if onTap callback is provided (i.e., not disabled)

    return Card(
       margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
       elevation: 1.5,
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell( // Wrap with InkWell for tap effect
         onTap: isTapEnabled ? onTap : null, // Only enable tap if callback is provided
         borderRadius: BorderRadius.circular(8), // Match card shape
         child: Padding(
           padding: const EdgeInsets.fromLTRB(16, 12, 8, 12), // Adjust padding
           child: Row( // Use Row for better alignment
            children: [
               // Left side: Category icon and details
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                      Text(
                         categoryName,
                         style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                         overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (expense.description != null && expense.description!.isNotEmpty) ...[
                         Text(
                            expense.description!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                         ),
                         const SizedBox(height: 4),
                      ],
                      Text(
                         expense.formattedDate,
                         style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600, fontSize: 11),
                      ),
                      // Optional: Show who paid (would require fetching payments data here)
                      // _buildPaymentSummary(context, tourProvider, expense.id!),
                   ],
                 ),
               ),
               const SizedBox(width: 16), // Space between details and amount/actions

               // Right side: Amount and Delete button
               Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 crossAxisAlignment: CrossAxisAlignment.end,
                 children: [
                   Text(
                     currencyFormat.format(expense.amount),
                     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal), // Changed color
                   ),
                    // Show delete only if tour is not ended
                    SizedBox(
                      height: 30, // Constrain height for consistent row height
                      child: (tourStatus != TourStatus.Ended)
                          ? IconButton(
                             icon: Icon(Icons.delete_outline, color: Colors.grey.shade500),
                             iconSize: 20,
                             tooltip: 'Delete Expense',
                             onPressed: onDelete,
                             padding: EdgeInsets.zero,
                             visualDensity: VisualDensity.compact,
                           )
                          : const SizedBox(height: 30), // Placeholder to maintain height
                    ),
                 ],
               ),
            ],
                 ),
         ),
      ),
    );
  }

  // Example of how you might display payment info asynchronously (Optional)
  // Widget _buildPaymentSummary(BuildContext context, TourProvider tourProvider, int expenseId) {
  //    return FutureBuilder<List<ExpensePayment>>(
  //       future: DatabaseHelper.instance.getExpensePayments(expenseId), // Fetch payments
  //       builder: (context, snapshot) {
  //          if (!snapshot.hasData || snapshot.data!.isEmpty) {
  //             return const SizedBox.shrink(); // No payment info
  //          }
  //          final payments = snapshot.data!;
  //          String paidByText;
  //          if (payments.length == 1) {
  //             paidByText = 'Paid by: ${tourProvider.getPersonNameById(payments.first.personId)}';
  //          } else {
  //             paidByText = 'Paid by: Multiple (${payments.length})';
  //          }
  //          return Padding(
  //            padding: const EdgeInsets.only(top: 4.0),
  //            child: Text(
  //               paidByText,
  //               style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11, fontStyle: FontStyle.italic),
  //            ),
  //          );
  //       }
  //    );
  // }

}
```

```markdown
// FILE: lib/screens/add_edit_expense_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull
import 'package:btour/models/category.dart';
import 'package:btour/models/expense.dart';
import 'package:btour/models/person.dart';
import 'package:btour/models/tour.dart';
import 'package:btour/providers/tour_provider.dart';
import 'package:btour/widgets/person_multi_selector.dart'; // Re-use for attendees
import 'package:btour/database/database_helper.dart'; // Direct DB access needed for initial load

class AddEditExpenseScreen extends StatefulWidget {
  final Tour tour; // The tour this expense belongs to
  final Expense? expenseToEdit; // Pass expense if editing

  const AddEditExpenseScreen({
    super.key,
    required this.tour,
    this.expenseToEdit,
  });

  bool get isEditing => expenseToEdit != null;

  @override
  State<AddEditExpenseScreen> createState() => _AddEditExpenseScreenState();
}

class _AddEditExpenseScreenState extends State<AddEditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  final TextEditingController _categoryController = TextEditingController(); // For adding new category dialog

  // Use separate controllers for each payment field
  Map<int, TextEditingController> _paymentControllers = {}; // personId -> Controller

  DateTime _selectedDate = DateTime.now();
  Category? _selectedCategory;
  List<Category> _availableCategories = [];
  List<Person> _tourParticipants = []; // People participating in the tour
  List<Person> _selectedAttendees = [];

  // Payment Tracking: Keep track of amounts separate from controllers for calculation
  Map<int, double> _paymentAmounts = {}; // personId -> Amount Paid

  bool _isLoading = false; // Local loading state for form submission/initial load

  @override
  void initState() {
    super.initState();

    _amountController = TextEditingController(text: widget.expenseToEdit?.amount.toStringAsFixed(2) ?? '');
    _descriptionController = TextEditingController(text: widget.expenseToEdit?.description ?? '');
    _selectedDate = widget.expenseToEdit?.date ?? DateTime.now();

    // Add listener to amount controller to potentially auto-update default payment
    _amountController.addListener(_onAmountChanged);

    // Fetch initial data (categories, participants, and existing expense details if editing)
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final tourProvider = Provider.of<TourProvider>(context, listen: false);
    final dbHelper = DatabaseHelper.instance;

    // Ensure categories and participants are loaded
    // Categories might be in provider, participants specific to tour need fetching
    try {
        if (tourProvider.categories.isEmpty) await tourProvider.fetchAllCategories();
        _availableCategories = tourProvider.categories;

        // Fetch participants directly for this tour
        _tourParticipants = await dbHelper.getTourParticipants(widget.tour.id!);

        if (widget.isEditing && widget.expenseToEdit != null) {
          final expense = widget.expenseToEdit!;
          // Pre-select category safely
          _selectedCategory = _availableCategories.firstWhereOrNull((cat) => cat.id == expense.categoryId);

          // Pre-select attendees
           final attendees = await dbHelper.getExpenseAttendees(expense.id!);
           _selectedAttendees = attendees;

          // Load existing payments
          final existingPayments = await dbHelper.getExpensePayments(expense.id!);
          _paymentAmounts = { for (var p in existingPayments) p.personId : p.amountPaid };

        } else {
          // Default for new expense:
          // No default category initially
          // Default attendees: All tour participants? Let's start empty for explicit selection.
           _selectedAttendees = []; // Start empty
           // Default payment: Advance holder pays (will be set by _initializePaymentControllers)
           _paymentAmounts = {}; // Start empty, will be populated
        }

         // Initialize controllers and amounts for ALL participants AFTER loading
        _initializePaymentControllersAndAmounts();

    } catch (e) {
        print("Error loading initial expense data: $e");
        if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.redAccent),
            );
        }
    } finally {
       if(mounted) setState(() => _isLoading = false);
    }
  }

   // Initialize/Update payment controllers and amounts map for all current tour participants
   void _initializePaymentControllersAndAmounts() {
       // Dispose old controllers first
       _paymentControllers.values.forEach((controller) => controller.dispose());
       _paymentControllers = {};

       final currentTotalAmount = double.tryParse(_amountController.text) ?? 0.0;
       bool isNewExpenseOrNoPayments = !widget.isEditing || _paymentAmounts.isEmpty;
       bool onlyZeroPaymentsExist = _paymentAmounts.isNotEmpty && _paymentAmounts.values.every((amount) => amount == 0.0);

       // Determine if we should apply the default payment (holder pays all)
       bool applyDefaultPayment = isNewExpenseOrNoPayments || onlyZeroPaymentsExist;

       for (var participant in _tourParticipants) {
           double initialAmount = 0.0;
           if (applyDefaultPayment && participant.id == widget.tour.advanceHolderPersonId) {
              initialAmount = currentTotalAmount; // Holder pays total if defaulting
           } else {
               initialAmount = _paymentAmounts[participant.id] ?? 0.0; // Use existing or 0
           }

           // Update the internal amount map
           _paymentAmounts[participant.id!] = initialAmount;

           // Create and initialize the controller
           final controller = TextEditingController(text: initialAmount.toStringAsFixed(2));
           controller.addListener(() => _onPaymentControllerChanged(participant.id!, controller.text));
           _paymentControllers[participant.id!] = controller;
       }
        // Ensure the state reflects the initialized controllers/amounts
       if(mounted) setState(() {});
   }

  // --- Listener Callbacks ---

   void _onAmountChanged() {
       // If payments haven't been manually edited (i.e., only holder has non-zero amount or all are zero),
       // update the holder's payment controller to match the new total amount.
       final currentTotalAmount = double.tryParse(_amountController.text) ?? 0.0;
       final holderId = widget.tour.advanceHolderPersonId;
       final holderController = _paymentControllers[holderId];

       // Check if only the holder has a non-zero payment amount in the internal map
       bool onlyHolderPaid = _paymentAmounts.entries.every((entry) => entry.key == holderId ? entry.value != 0 : entry.value == 0.0);
       // Or if all payments are zero
       bool allZero = _paymentAmounts.values.every((amount) => amount == 0.0);

       if (holderController != null && (onlyHolderPaid || allZero)) {
           final formattedAmount = currentTotalAmount.toStringAsFixed(2);
           // Update controller only if value is different to avoid cursor jumps/loops
           if (holderController.text != formattedAmount) {
               holderController.text = formattedAmount;
               // The controller's listener (_onPaymentControllerChanged) will update _paymentAmounts map
           }
       }
   }

  void _onPaymentControllerChanged(int personId, String textValue) {
      final amount = double.tryParse(textValue) ?? 0.0;
      // Update the internal map, not the controller text directly here
      setState(() {
         _paymentAmounts[personId] = amount;
      });
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    // Dispose all payment controllers
    _paymentControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      // Allow selection within the tour's date range if available?
      firstDate: widget.tour.startDate.subtract(const Duration(days: 30)), // Allow slightly before tour start
      lastDate: widget.tour.endDate?.add(const Duration(days: 1)) ?? DateTime.now().add(const Duration(days: 365)), // Allow future date if tour ongoing
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _showAddCategoryDialog() async {
      _categoryController.clear();
      final newCategoryName = await showDialog<String>(
          context: context,
          builder: (BuildContext context) {
              return AlertDialog(
                  title: const Text('Add New Category'),
                  content: TextField(
                      controller: _categoryController,
                      decoration: const InputDecoration(hintText: "Category Name"),
                      textCapitalization: TextCapitalization.words,
                      autofocus: true,
                  ),
                  actions: <Widget>[
                      TextButton(
                          child: const Text('Cancel'),
                          onPressed: () => Navigator.of(context).pop(),
                      ),
                      TextButton(
                          child: const Text('Add'),
                          onPressed: () {
                              if (_categoryController.text.trim().isNotEmpty) {
                                  Navigator.of(context).pop(_categoryController.text.trim());
                              } else {
                                 // Optionally show validation inside dialog
                              }
                          },
                      ),
                  ],
              );
          },
      );

      if (newCategoryName != null && mounted) {
          final tourProvider = Provider.of<TourProvider>(context, listen: false);
          setState(() => _isLoading = true); // Show loading while adding
          try {
              final newCategory = await tourProvider.addCategory(newCategoryName);
              // Refresh local list and select the new one
              setState(() {
                  _availableCategories = tourProvider.categories;
                  _selectedCategory = newCategory;
              });
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('Category "${newCategory.name}" added.'), backgroundColor: Colors.green),
               );
          } catch (e) {
               print("Error adding category: $e");
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error adding category: $e'), backgroundColor: Colors.redAccent),
              );
          } finally {
             if (mounted) setState(() => _isLoading = false);
          }
      }
  }

  // --- Form Submission ---
  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      // Additional custom validations
      if (_selectedCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select or add a Category.'), backgroundColor: Colors.redAccent),
        );
        return;
      }
       if (_selectedAttendees.isEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Please select at least one Attendee for this expense.'), backgroundColor: Colors.redAccent),
         );
         return;
       }

       final totalAmount = double.tryParse(_amountController.text) ?? 0.0;

       // Validate that payment amounts sum up to the total amount
       final totalPaid = _paymentAmounts.values.fold<double>(0.0, (sum, item) => sum + item);
       if ((totalPaid - totalAmount).abs() > 0.01) { // Allow for small floating point differences
           bool? continueSave = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                   title: const Text('Payment Mismatch'),
                   content: Text('The sum of individual payments (${NumberFormat.currency(locale: 'en_US', symbol: "\$").format(totalPaid)}) does not match the total expense amount (${NumberFormat.currency(locale: 'en_US', symbol: "\$").format(totalAmount)}). \n\nSave anyway? The total amount ($totalAmount) will be deducted from the tour advance.'),
                   actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save Anyway')),
                   ],
                ),
             );
           if (continueSave == null || !continueSave) {
              return; // User cancelled
           }
           // If continuing, proceed with saving
       }


      setState(() => _isLoading = true);
      final tourProvider = Provider.of<TourProvider>(context, listen: false);

      final expenseData = Expense(
        id: widget.expenseToEdit?.id, // Null for new expense
        tourId: widget.tour.id!,
        categoryId: _selectedCategory!.id!,
        amount: totalAmount, // Use the validated total amount
        date: _selectedDate,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      final attendeeIds = _selectedAttendees.map((p) => p.id!).toList();
      // Create ExpensePayment objects only for those who paid > 0
       final validPayments = _paymentAmounts.entries
            .where((entry) => entry.value > 0)
            .map((entry) => ExpensePayment(
                // ID is null for new payments, need to handle this in DB update logic if necessary
                // The current DB logic deletes and re-inserts payments, so null ID is fine.
                expenseId: widget.expenseToEdit?.id ?? 0, // Will be replaced by actual ID in DB layer
                personId: entry.key,
                amountPaid: entry.value,
             ))
            .toList();

      try {
        if (widget.isEditing) {
          await tourProvider.updateExpenseInCurrentTour(expenseData, attendeeIds, validPayments);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense Updated Successfully!'), backgroundColor: Colors.green),
          );
        } else {
          await tourProvider.addExpenseToCurrentTour(expenseData, attendeeIds, validPayments);
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense Added Successfully!'), backgroundColor: Colors.green),
          );
        }
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
         print("Error saving expense: $e");
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving expense: $e'), backgroundColor: Colors.redAccent),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
       // Form validation failed, show message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fix the errors in the form.'), backgroundColor: Colors.orange),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: "\$");

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Expense' : 'Add New Expense'),
         actions: [
          if (_isLoading) const Padding(
             padding: EdgeInsets.only(right: 16.0),
             child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))),
          if (!_isLoading) IconButton(
            icon: const Icon(Icons.save),
            onPressed: _submitForm,
            tooltip: 'Save Expense',
          ),
        ],
      ),
      body: _isLoading && _availableCategories.isEmpty // Show loading only on initial data fetch
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // --- Category ---
                     Row(
                       crossAxisAlignment: CrossAxisAlignment.end, // Align button nicely
                       children: [
                         Expanded(
                           child: DropdownButtonFormField<Category>(
                            value: _selectedCategory,
                            items: _availableCategories.map((Category category) {
                              return DropdownMenuItem<Category>(
                                value: category,
                                child: Text(category.name),
                              );
                            }).toList(),
                            onChanged: (Category? newValue) {
                              setState(() {
                                _selectedCategory = newValue;
                              });
                            },
                            decoration: const InputDecoration(
                                labelText: 'Category *',
                                border: OutlineInputBorder()
                            ),
                            // Validator is implicitly handled by submit check for null
                           ),
                         ),
                         const SizedBox(width: 8),
                         IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: _showAddCategoryDialog,
                            tooltip: 'Add New Category',
                         ),
                       ],
                     ),
                    const SizedBox(height: 16),

                    // --- Amount ---
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                          labelText: 'Total Amount *', prefixText: "\$"),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      // Listener handles default payment update
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an amount';
                        }
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) {
                          return 'Please enter a valid positive amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // --- Date ---
                     InkWell(
                       onTap: () => _selectDate(context),
                       child: InputDecorator(
                         decoration: const InputDecoration(
                           labelText: 'Date *',
                           border: OutlineInputBorder()
                         ),
                         child: Row( // Add icon for clarity
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(dateFormat.format(_selectedDate)),
                              const Icon(Icons.calendar_month_outlined, color: Colors.grey),
                            ],
                          ),
                       ),
                     ),
                    const SizedBox(height: 16),

                    // --- Description ---
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Description (Optional)'),
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),

                    // --- Attendees ---
                     Text('Attendees *', style: Theme.of(context).textTheme.titleMedium),
                     const SizedBox(height: 8),
                     PersonMultiSelector(
                         key: ValueKey('attendees_${_tourParticipants.length}'), // Rebuild if participants change
                         // Use tour participants as the pool
                         allPeople: _tourParticipants,
                         initialSelectedPeople: _selectedAttendees,
                         onSelectionChanged: (selected) {
                             setState(() { _selectedAttendees = selected; });
                         },
                         // Don't allow adding new people directly here
                     ),
                      if (_selectedAttendees.isEmpty) // Show helper text if nothing selected yet
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0, left: 8.0),
                          child: Text(
                            'Select who was part of this expense.',
                            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                          ),
                        ),
                     const SizedBox(height: 20),


                     // --- Payers ---
                      Text('Paid By', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                       Text(
                          '(Specify exact amounts paid by each person. Total must match expense amount.)',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)
                       ),
                      const SizedBox(height: 8),
                      if (_tourParticipants.isEmpty)
                          const Text('Load participants to specify payments.')
                      else
                          ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _tourParticipants.length,
                              itemBuilder: (context, index) {
                                  final person = _tourParticipants[index];
                                  final paymentController = _paymentControllers[person.id];

                                  // Should not happen if initialized correctly, but check just in case
                                  if (paymentController == null) return const SizedBox.shrink();

                                  return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: Row(
                                          children: [
                                              Expanded(child: Text(person.name, overflow: TextOverflow.ellipsis)),
                                              const SizedBox(width: 10),
                                              SizedBox(
                                                  width: 130, // Fixed width for amount input
                                                  child: TextFormField(
                                                      key: ValueKey('payment_${person.id}'), // Ensure state is kept
                                                      controller: paymentController, // Use the dedicated controller
                                                      decoration: const InputDecoration(
                                                          prefixText: "\$",
                                                          border: OutlineInputBorder(),
                                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                                          isDense: true,
                                                      ),
                                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                      // Listener updates internal map
                                                      // Validation for individual field
                                                      validator: (value) {
                                                          final amount = double.tryParse(value ?? '');
                                                          if (amount == null || amount < 0) {
                                                              return 'Invalid'; // Keep it short
                                                          }
                                                          return null;
                                                      },
                                                  ),
                                              ),
                                          ],
                                      ),
                                  );
                              },
                          ),

                      // Display Sum of Payments for verification
                      Padding(
                         padding: const EdgeInsets.only(top: 12.0, right: 8), // Align roughly with input boxes
                         child: Align(
                           alignment: Alignment.centerRight,
                           child: Text(
                              'Payments Sum: ${currencyFormat.format(_paymentAmounts.values.fold(0.0, (a, b) => a + b))}',
                              style: TextStyle(
                                 fontWeight: FontWeight.bold,
                                 color: ((_paymentAmounts.values.fold(0.0, (a, b) => a + b) - (double.tryParse(_amountController.text) ?? 0.0)).abs() > 0.01)
                                    ? Colors.redAccent
                                    : Colors.grey.shade700,
                              ),
                           ),
                         ),
                      ),

                    const SizedBox(height: 30),
                    // Save button already in AppBar
                  ],
                ),
              ),
            ),
    );
  }
}
```

```markdown
// FILE: create_files.js
const fs = require('fs');
const path = require('path');

const markdownFilePath = process.argv[2]; // Get Markdown file path from command line argument

if (!markdownFilePath) {
    console.error('Usage: node create_files.js <path_to_markdown_file.md>');
    process.exit(1);
}

if (!fs.existsSync(markdownFilePath)) {
    console.error(`Error: Markdown file not found at ${markdownFilePath}`);
    process.exit(1);
}

console.log(`Processing Markdown file: ${markdownFilePath}`);

try {
    const markdownContent = fs.readFileSync(markdownFilePath, 'utf-8');

    // Regex to find Dart code blocks with the file marker
    // ```dart              -> Start of block (allowing spaces after ```)
    // // FILE: (.*?)       -> File marker line, captures the path non-greedily
    // \s*?\n               -> Optional space and newline after marker
    // ([\s\S]*?)           -> Capture the actual code (including newlines) non-greedily
    // ```                  -> End of block
    const codeBlockRegex = /```(?:dart)?\s*\/\/\s*FILE:\s*(.*?)\s*?\n([\s\S]*?)```/g;


    let match;
    let filesCreated = 0;

    while ((match = codeBlockRegex.exec(markdownContent)) !== null) {
        const relativeFilePath = match[1].trim().replace(/\\/g, '/'); // Normalize path separators
        let codeContent = match[2].trim();

        // Basic validation for path
        if (!relativeFilePath || !relativeFilePath.includes('/')) {
            console.warn(`Skipping code block with potentially invalid FILE marker: // FILE: ${relativeFilePath}`);
            continue;
        }

         // Handle potential path issues (e.g., leading slash) - adjust if needed based on execution context
         const cleanedRelativePath = relativeFilePath.startsWith('/') ? relativeFilePath.substring(1) : relativeFilePath;


        // Make the path relative to the script's execution directory (process.cwd())
        const absoluteFilePath = path.resolve(process.cwd(), cleanedRelativePath);
        const directoryPath = path.dirname(absoluteFilePath);

        try {
            // Create directories recursively if they don't exist
            if (!fs.existsSync(directoryPath)) {
                fs.mkdirSync(directoryPath, { recursive: true });
                console.log(`Created directory: ${directoryPath}`);
            }

             // Ensure code content ends with a newline for cleaner files
             if (!codeContent.endsWith('\n')) {
                codeContent += '\n';
            }

            // Write the code content to the file
            fs.writeFileSync(absoluteFilePath, codeContent, 'utf-8');
            console.log(`Successfully wrote file: ${absoluteFilePath}`);
            filesCreated++;

        } catch (err) {
            console.error(`Error processing file ${cleanedRelativePath}:`, err);
        }
    }

    if (filesCreated > 0) {
         console.log(`\n✅ Successfully created ${filesCreated} files.`);
         console.log(`\n🚀 Run the following commands in your Flutter project directory ('${process.cwd()}'):`);
         console.log("   1. flutter pub get");
         console.log("   2. flutter run");
    } else {
         console.log('\n⚠️ No Flutter/Dart code blocks with valid "// FILE: path/to/file.dart" markers found.');
         console.log('   Ensure each code block starts like:');
         console.log('   ```dart');
         console.log('   // FILE: lib/path/to/your/file.dart');
         console.log('   <code>');
         console.log('   ```');
    }


} catch (err) {
    console.error('Error reading or processing Markdown file:', err);
    process.exit(1);
}
```

**Instructions:**

1.  **Save Code:** Save the entire content above into a single file named `flutter_app_code.md`.
2.  **Save Script:** Save the Node.js script (the last code block) into a file named `create_files.js` in the *root* directory of your new Flutter project (e.g., `tour_expense_app/`).
3.  **Create Flutter Project:** If you haven't already, create the project:
    ```bash
    flutter create tour_expense_app
    ```
4.  **Navigate:** Open your terminal and navigate *into* the Flutter project directory:
    ```bash
    cd tour_expense_app
    ```
5.  **Run Script:** Execute the Node.js script from within the `tour_expense_app` directory, pointing it to the Markdown file you saved (adjust the path if necessary):
    ```bash
    # If flutter_app_code.md is *outside* the project folder (e.g., one level up)
    node create_files.js ../flutter_app_code.md

    # If flutter_app_code.md is *inside* the project folder
    # node create_files.js flutter_app_code.md
    ```
6.  **Get Dependencies:** The script output reminds you, but run:
    ```bash
    flutter pub get
    ```
7.  **Run App:**
    ```bash
    flutter run
    ```

This should set up the project structure and files, allowing you to run the app. Remember to check the `pubspec.yaml` for the correct dependencies as listed in the initial requirements.