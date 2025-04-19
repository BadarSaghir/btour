Okay, let's break this down.

First, the **Requirements Definition** based on your description:

## Requirements

1.  **Core Entities:**
    *   **Tour:** Represents a trip or event.
    *   **Person:** Represents an individual involved in tours.
    *   **Category:** Represents types of expenses (e.g., Food, Travel, Accommodation).
    *   **Expense:** Represents a specific spending instance within a tour and category.

2.  **Tour Functionality:**
    *   **Creation:** Create a new tour with a Name, Start Date, list of Participants (People), an Advance Amount, and an assigned Person responsible for the advance (Advance Holder).
    *   **Status:** Tours can have statuses: `Created`, `Started`, `Ended`.
    *   **Modification:** Ability to edit tour details (perhaps before it's ended). Ability to start/end a tour.
    *   **Participants:** Manage the list of people participating in the tour.
    *   **Display:**
        *   Active tours listed separately or clearly marked.
        *   Finished tours displayed as distinct cards showing essential summary info: Name, Date Range (From-To, if applicable), Participants list (or count), Advance Amount, Total Spent, Remaining Amount.

3.  **Person Functionality:**
    *   **Management:** Ability to add new people (globally or per tour). Names should likely be unique for easier selection.
    *   **Association:** Link people to tours as participants and as the advance holder. Link people to expenses as attendees and payers.

4.  **Category Functionality:**
    *   **Management:** Ability to define expense categories (e.g., 'Food', 'Travel'). These could be global or per tour (global seems simpler to start).
    *   **Association:** Link expenses to a specific category.

5.  **Expense Functionality:**
    *   **Creation:** Add a new expense associated with a specific `Tour`.
    *   **Details:** Each expense needs:
        *   `Category` (selected from predefined list).
        *   `Amount` (total cost of the expense).
        *   `Date` (defaults to today, but user can select a past date).
        *   `Description` (optional text).
        *   `Attendees`: Select people (from the tour participants) who benefited from or attended this specific expense event. Use autocomplete/dropdown based on previous interactions or tour participants. Allow adding a new person if necessary (should probably add them to the tour participants list too).
        *   `Payers`: Record who paid for *this specific* expense.
            *   Defaults to the Tour's Advance Holder paying the full amount.
            *   Allows specifying multiple people paying portions of the *expense amount*.
            *   **Crucially:** The *total expense amount* is always deducted from the *Tour's advance amount* for reporting purposes, regardless of who physically paid using their own cash at the time.
    *   **Modification:** Ability to edit existing expenses.

6.  **Reporting:**
    *   **Tour Summary:** For each tour (especially finished ones), calculate and display: Total Advance, Total Spent (sum of all expense amounts for the tour), Remaining Advance.
    *   **Individual Spending Report:** For a given tour, show a breakdown of how much cash each person *physically paid out* across all expenses (summing their contributions from the `Payers` section of each expense). This helps settle debts *if* people used their own money beyond the advance. *Note: The primary deduction is always from the advance pool.*

7.  **Persistence:**
    *   All data (Tours, People, Categories, Expenses, relationships) must be stored locally using `sqflite`.

8.  **User Interface (Flutter):**
    *   Simple, functional UI.
    *   List view for tours.
    *   Detail view for a selected tour (possibly using Tabs for Overview/Expenses/People/Reports).
    *   Forms for creating/editing Tours and Expenses.
    *   Use appropriate widgets for selection (Dropdowns, Autocomplete, Date Pickers, Chips).

9.  **Automation (Node.js Script):**
    *   A script that reads the Flutter code provided within Markdown code blocks.
    *   Identifies target file paths (using a convention like `// FILE: path/to/your/file.dart` on the first line of the code block).
    *   Creates necessary directories.
    *   Writes the code content into the specified files.

---

Now, let's structure the Flutter application and provide the code.

**Project Setup:**

1.  Create a new Flutter project: `flutter create tour_expense_app`
2.  Open the project in your IDE (like VS Code).
3.  Add dependencies to `pubspec.yaml`:
    ```yaml
    dependencies:
      flutter:
        sdk: flutter
      sqflite: ^2.3.0 # Check for latest version
      path: ^1.8.3   # Usually included with flutter, but good to be explicit
      intl: ^0.18.1  # For date formatting (check latest)
      provider: ^6.1.1 # Simple state management (optional but recommended)

    dev_dependencies:
      flutter_test:
        sdk: flutter
      flutter_lints: ^2.0.0 # Or newer
    ```
4.  Run `flutter pub get`.

---

**Flutter Code:**

This will be a simplified structure focusing on core functionality. Error handling, advanced UI, and more complex state management are kept minimal for clarity.

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
        id: json['id'] as int?, // Assuming 'id' is the PK column name
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
    _tours = await _dbHelper.getAllTours();
    notifyListeners();
  }

  Future<Tour> addTour(Tour tour, List<int> participantIds) async {
    _setLoading(true);
    final newTour = await _dbHelper.createTour(tour, participantIds);
    _tours.insert(0, newTour); // Add to beginning of list
    _setLoading(false);
    // No need to notifyListeners() here because _setLoading does it
    return newTour;
  }

  Future<void> updateTour(Tour tour, List<int> participantIds) async {
    _setLoading(true);
    await _dbHelper.updateTour(tour, participantIds);
    final index = _tours.indexWhere((t) => t.id == tour.id);
    if (index != -1) {
      _tours[index] = tour; // Update local list
    }
    // If this is the current tour, update its details too
    if (_currentTour?.id == tour.id) {
       await fetchTourDetails(tour.id!);
    }
    _setLoading(false);
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
      final tourIndex = _tours.indexWhere((t) => t.id == tourId);
      if (tourIndex == -1) return;

      Tour updatedTour = _tours[tourIndex].copy(
          status: newStatus,
          endDate: newStatus == TourStatus.Ended ? (endDate ?? DateTime.now()) : _tours[tourIndex].endDate,
          // Ensure end date is only set when ending, keep existing otherwise
          clearEndDate: newStatus != TourStatus.Ended && _tours[tourIndex].endDate != null
      );


      // Special case: If moving from Ended back to Started/Created, clear end date
      if (_tours[tourIndex].status == TourStatus.Ended && newStatus != TourStatus.Ended) {
         updatedTour = updatedTour.copy(clearEndDate: true);
      }


      // Fetch participants to pass to updateTour (DB method requires it)
       List<Person> participants = await _dbHelper.getTourParticipants(tourId);
       List<int> participantIds = participants.map((p) => p.id!).toList();


      await updateTour(updatedTour, participantIds); // This will handle DB and local list update + notify
  }


  // --- Current Tour Detail Methods ---
  void _clearCurrentTourDetails() {
      _currentTour = null;
      _currentTourParticipants = [];
      _currentTourAdvanceHolder = null;
      _currentTourExpenses = [];
      _currentTourTotalSpent = 0.0;
      _currentTourPaymentsByPerson = {};
      notifyListeners(); // Notify that details are cleared
  }

  Future<void> fetchTourDetails(int tourId) async {
    _setLoading(true);
    _currentTour = await _dbHelper.getTour(tourId);

    if (_currentTour != null) {
      _currentTourParticipants = await _dbHelper.getTourParticipants(tourId);
      _currentTourAdvanceHolder = await _dbHelper.getPerson(_currentTour!.advanceHolderPersonId);
      _currentTourExpenses = await _dbHelper.getExpensesForTour(tourId);
      _currentTourTotalSpent = await _dbHelper.getTotalExpensesForTour(tourId);
      _currentTourPaymentsByPerson = await _dbHelper.getPaymentsPerPersonForTour(tourId);

      // Optionally pre-load expense details (attendees, payments) here if needed frequently
      // Or load them on demand when an expense is viewed/edited
      // Example: Preload payments to display who paid on the expense list item
      // for (var i = 0; i < _currentTourExpenses.length; i++) {
      //   _currentTourExpenses[i].payments = await _dbHelper.getExpensePayments(_currentTourExpenses[i].id!);
      // }

    } else {
      _clearCurrentTourDetails(); // Clear if tour not found
    }
    _setLoading(false);
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

      // Refresh current tour data
      await fetchTourDetails(_currentTour!.id!);
      // Note: fetchTourDetails calls setLoading(false) at the end

      return newExpense; // Or potentially the version fetched in fetchTourDetails
  }

  Future<void> updateExpenseInCurrentTour(Expense expense, List<int> attendeeIds, List<ExpensePayment> payments) async {
     if (_currentTour == null || expense.id == null) {
         throw Exception("Cannot update expense without a current tour or expense ID.");
     }
     _setLoading(true);
     await _dbHelper.updateExpense(expense, attendeeIds, payments);
     // Refresh current tour data
     await fetchTourDetails(_currentTour!.id!);
     // Note: fetchTourDetails calls setLoading(false) at the end
  }

  Future<void> deleteExpenseFromCurrentTour(int expenseId) async {
     if (_currentTour == null) {
          throw Exception("No current tour selected to delete expense from.");
      }
      _setLoading(true);
      await _dbHelper.deleteExpense(expenseId);
      // Refresh current tour data
      await fetchTourDetails(_currentTour!.id!);
      // Note: fetchTourDetails calls setLoading(false) at the end
  }


  // --- Helper to get Person Name from ID ---
  String getPersonNameById(int personId) {
      return _peopleMap[personId]?.name ?? 'Unknown Person [$personId]';
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
  @override
  void initState() {
    super.initState();
    // Fetch data if not already loaded (e.g., on app start)
    // Provider should handle initial loading, but this ensures refresh if needed
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   Provider.of<TourProvider>(context, listen: false).fetchAllData();
    // });
  }

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
          if (tourProvider.isLoading && tourProvider.tours.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final activeTours = tourProvider.tours
              .where((tour) => tour.status != TourStatus.Ended)
              .toList();
          final finishedTours = tourProvider.tours
              .where((tour) => tour.status == TourStatus.Ended)
              .toList();

          if (tourProvider.tours.isEmpty) {
             return const Center(child: Text('No tours yet. Create one!'));
          }


          return RefreshIndicator(
             onRefresh: () => tourProvider.fetchAllTours(), // Refresh only tours on pull-down
             child: ListView(
                padding: const EdgeInsets.all(8.0),
                children: [
                  if (activeTours.isNotEmpty)
                     _buildSectionTitle('Active Tours (${activeTours.length})'),
                  ...activeTours.map((tour) => TourCard(
                        tour: tour,
                        onTap: () => _navigateToTourDetail(context, tour.id!),
                      )).toList(),

                  if (finishedTours.isNotEmpty) ...[
                    const SizedBox(height: 16),
                     _buildSectionTitle('Finished Tours (${finishedTours.length})'),
                    ...finishedTours.map((tour) => TourCard(
                           tour: tour,
                           onTap: () => _navigateToTourDetail(context, tour.id!),
                         )).toList(),
                  ],
                ],
              ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddEditTourScreen()),
          );
        },
        tooltip: 'Add Tour',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
     return Padding(
       padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
       child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
     );
  }


  void _navigateToTourDetail(BuildContext context, int tourId) {
     // Fetch details before navigating
     Provider.of<TourProvider>(context, listen: false).fetchTourDetails(tourId).then((_) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const TourDetailScreen()),
        );
     }).catchError((error) {
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
import 'package:btour/providers/tour_provider.dart'; // To get total spent

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
    // Use a FutureBuilder or listen to provider changes for dynamic data like totalSpent
    // For simplicity here, we'll assume total spent might be fetched elsewhere or display static info

    // Get provider but don't listen here to avoid rebuilding the whole list card constantly
    final tourProvider = Provider.of<TourProvider>(context, listen: false);
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹'); // Example INR

    return Card(
      clipBehavior: Clip.antiAlias, // Ensures inkwell ripple stays within bounds
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tour.name,
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(
                      '${tour.formattedStartDate} - ${tour.formattedEndDate}',
                      style: Theme.of(context).textTheme.bodySmall,
                   ),
                   Chip(
                      label: Text(tour.statusString),
                      backgroundColor: _getStatusColor(tour.status),
                      labelStyle: const TextStyle(color: Colors.white, fontSize: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                       materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                       visualDensity: VisualDensity.compact,
                   ),
                ],
              ),
              const SizedBox(height: 8),
               Text(
                  'Advance Holder: ${tourProvider.getPersonNameById(tour.advanceHolderPersonId)}',
                  style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                     Text(
                        'Advance: ${currencyFormat.format(tour.advanceAmount)}',
                         style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.green.shade700),
                    ),
                     // Only show Spent/Remaining for Finished tours on the card maybe?
                    if (tour.status == TourStatus.Ended)
                         FutureBuilder<double>(
                           future: tourProvider.getTotalExpensesForTour(tour.id!), // Re-fetch for accuracy on card
                           builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
                              }
                              final spent = snapshot.data ?? 0.0;
                              final remaining = tour.advanceAmount - spent;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                   Text(
                                     'Spent: ${currencyFormat.format(spent)}',
                                     style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red.shade700),
                                   ),
                                   Text(
                                     'Remaining: ${currencyFormat.format(remaining)}',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: remaining >= 0 ? Colors.blue.shade800 : Colors.orange.shade900
                                      ),
                                    ),
                                ],
                              );
                           }
                         ),
                 ],
              ),

               // Optionally show participant count
               // FutureBuilder<List<Person>>(
               //   future: tourProvider.getTourParticipants(tour.id!),
               //   builder: (context, snapshot) { ... display count ... }
               // ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(TourStatus status) {
     switch (status) {
        case TourStatus.Created: return Colors.grey;
        case TourStatus.Started: return Colors.blue;
        case TourStatus.Ended: return Colors.green;
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
import 'package:btour/widgets/person_multi_selector.dart'; // Need to create this widget

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
     setState(() => _isLoading = true);
     final tourProvider = Provider.of<TourProvider>(context, listen: false);
     // Ensure people list is up-to-date
     await tourProvider.fetchAllPeople();
     _allPeople = tourProvider.people;

     if (widget.isEditing && widget.tourToEdit != null) {
        // Pre-select advance holder
        _selectedAdvanceHolder = _allPeople.firstWhere(
          (p) => p.id == widget.tourToEdit!.advanceHolderPersonId,
          orElse: () => _allPeople.isNotEmpty ? _allPeople.first : null!, // Fallback or handle error
        );

        // Pre-select participants
        final participantIds = (await tourProvider.getTourParticipants(widget.tourToEdit!.id!))
                                .map((p) => p.id!)
                                .toList();
        _selectedParticipants = _allPeople.where((p) => participantIds.contains(p.id)).toList();

        // Ensure advance holder is also in participants list if not already
        if (_selectedAdvanceHolder != null && !_selectedParticipants.any((p) => p.id == _selectedAdvanceHolder!.id)) {
            _selectedParticipants.add(_selectedAdvanceHolder!);
        }

     } else {
        // Default selection for new tour (optional)
        // _selectedAdvanceHolder = _allPeople.isNotEmpty ? _allPeople.first : null;
        // _selectedParticipants = _selectedAdvanceHolder != null ? [_selectedAdvanceHolder!] : [];
     }

     setState(() => _isLoading = false);
  }


  @override
  void dispose() {
    _nameController.dispose();
    _advanceAmountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime initial = isStartDate ? _startDate : (_endDate ?? _startDate);
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
           const SnackBar(content: Text('Please select an Advance Holder.')),
         );
         return;
       }
       if (_selectedParticipants.isEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Please select at least one Participant.')),
         );
         return;
       }
        // Ensure Advance Holder is included in participants
       if (!_selectedParticipants.any((p) => p.id == _selectedAdvanceHolder!.id)) {
            setState(() {
                _selectedParticipants.add(_selectedAdvanceHolder!);
            });
       }


       setState(() => _isLoading = true);

       final tourProvider = Provider.of<TourProvider>(context, listen: false);
       final participantIds = _selectedParticipants.map((p) => p.id!).toList();

       try {
         if (widget.isEditing) {
           // Update existing tour
           final updatedTour = widget.tourToEdit!.copy(
             name: _nameController.text.trim(),
             startDate: _startDate,
             endDate: _endDate, // Pass the potentially updated end date
             clearEndDate: _endDate == null, // Explicitly clear if null
             advanceAmount: double.tryParse(_advanceAmountController.text) ?? 0.0,
             advanceHolderPersonId: _selectedAdvanceHolder!.id!,
             // Status is handled separately (usually not edited here)
           );
           await tourProvider.updateTour(updatedTour, participantIds);
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Tour Updated Successfully!')),
           );

         } else {
           // Create new tour
           final newTour = Tour(
             name: _nameController.text.trim(),
             startDate: _startDate,
             endDate: _endDate,
             advanceAmount: double.tryParse(_advanceAmountController.text) ?? 0.0,
             advanceHolderPersonId: _selectedAdvanceHolder!.id!,
             status: TourStatus.Created, // Default status
           );
           await tourProvider.addTour(newTour, participantIds);
            ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Tour Created Successfully!')),
           );
         }
         // Pop only after successful operation
          if (mounted) { // Check if the widget is still in the tree
             Navigator.of(context).pop();
          }
       } catch (e) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error saving tour: $e')),
         );
       } finally {
         // Check mounted again before calling setState
         if (mounted) {
           setState(() => _isLoading = false);
         }
       }
    }
  }

  // Function to add a new person (used by PersonMultiSelector)
  Future<Person?> _addNewPerson(String name) async {
      if (name.trim().isEmpty) return null;
      final tourProvider = Provider.of<TourProvider>(context, listen: false);
      try {
         final newPerson = await tourProvider.addPerson(name.trim());
         // Update the list of all people available for selection
         setState(() {
             _allPeople = tourProvider.people;
         });
         return newPerson;
      } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Error adding person: $e')),
           );
          return null;
      }
  }


  @override
  Widget build(BuildContext context) {
     final dateFormat = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Tour' : 'Add New Tour'),
        actions: [
          if (_isLoading) const Padding(
             padding: EdgeInsets.only(right: 16.0),
             child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))),
          if (!_isLoading) IconButton(
            icon: const Icon(Icons.save),
            onPressed: _submitForm,
            tooltip: 'Save Tour',
          ),
        ],
      ),
      body: _isLoading && _allPeople.isEmpty // Show loading indicator only during initial data load
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
                      decoration: const InputDecoration(labelText: 'Tour Name'),
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
                                 labelText: 'Start Date',
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
                                       icon: const Icon(Icons.clear),
                                       onPressed: () => setState(() => _endDate = null),
                                       tooltip: 'Clear End Date',
                                   ) : null,
                                ),
                                child: Text(_endDate != null ? dateFormat.format(_endDate!) : 'Ongoing'),
                              ),
                            ),
                         ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _advanceAmountController,
                      decoration: const InputDecoration(
                          labelText: 'Advance Amount', prefixText: '₹ '),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an advance amount';
                        }
                        if (double.tryParse(value) == null || double.parse(value) < 0) {
                          return 'Please enter a valid positive amount';
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
                          // Automatically add/ensure advance holder is in participant list
                           if (newValue != null && !_selectedParticipants.any((p) => p.id == newValue.id)) {
                               _selectedParticipants.add(newValue);
                           }
                        });
                      },
                      decoration: const InputDecoration(
                          labelText: 'Advance Holder',
                          border: OutlineInputBorder()
                      ),
                      validator: (value) => value == null ? 'Please select an advance holder' : null,
                    ),
                    const SizedBox(height: 20),

                    // --- Participants Multi-Selector ---
                    Text('Participants', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    PersonMultiSelector(
                       allPeople: _allPeople,
                       initialSelectedPeople: _selectedParticipants,
                       onSelectionChanged: (selected) {
                          setState(() {
                             _selectedParticipants = selected;
                             // Ensure advance holder stays selected if they were unselected here but are the holder
                              if (_selectedAdvanceHolder != null && !selected.any((p) => p.id == _selectedAdvanceHolder!.id)) {
                                 _selectedParticipants.add(_selectedAdvanceHolder!);
                              }
                          });
                       },
                       onAddPerson: _addNewPerson, // Pass function to handle adding new people
                    ),

                    const SizedBox(height: 30),
                    // Save Button (alternative placement)
                    // if (!_isLoading) Center(
                    //   child: ElevatedButton.icon(
                    //     icon: Icon(Icons.save),
                    //     label: Text(widget.isEditing ? 'Update Tour' : 'Create Tour'),
                    //     onPressed: _submitForm,
                    //     style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12)),
                    //   ),
                    // ),
                    // if (_isLoading) const Center(child: CircularProgressIndicator()),
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

// Simple Multi-selector using Chips and an Add button/dialog
class PersonMultiSelector extends StatefulWidget {
  final List<Person> allPeople;
  final List<Person> initialSelectedPeople;
  final ValueChanged<List<Person>> onSelectionChanged;
  final Future<Person?> Function(String name)? onAddPerson; // Callback to add new person

  const PersonMultiSelector({
    super.key,
    required this.allPeople,
    required this.initialSelectedPeople,
    required this.onSelectionChanged,
    this.onAddPerson,
  });

  @override
  State<PersonMultiSelector> createState() => _PersonMultiSelectorState();
}

class _PersonMultiSelectorState extends State<PersonMultiSelector> {
  late List<Person> _selectedPeople;
  final TextEditingController _addPersonController = TextEditingController(); // For Add dialog

  @override
  void initState() {
    super.initState();
    // Copy initial list to allow modification
    _selectedPeople = List.from(widget.initialSelectedPeople);
  }

   // Update selected people if the initial list changes externally
   @override
  void didUpdateWidget(PersonMultiSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if the initial list reference or content changed
    if (widget.initialSelectedPeople != oldWidget.initialSelectedPeople ||
        !listEquals(_selectedPeople, widget.initialSelectedPeople)) {

       // Only update if the external change is different from the current internal state
       // This avoids unnecessary updates if the parent rebuilds but the selection is the same
       // Or if the internal state was already updated by the user
       if (!listEquals(_selectedPeople, widget.initialSelectedPeople)) {
             _selectedPeople = List.from(widget.initialSelectedPeople);
       }

    }
  }

    // Helper to compare lists (requires import 'package:flutter/foundation.dart'; OR implement manually)
    bool listEquals<T>(List<T>? a, List<T>? b) {
        if (a == null) return b == null;
        if (b == null || a.length != b.length) return false;
        if (identical(a, b)) return true;
        for (int index = 0; index < a.length; index += 1) {
        if (a[index] != b[index]) return false;
        }
        return true;
    }


  @override
  void dispose() {
    _addPersonController.dispose();
    super.dispose();
  }

  void _showAddPersonDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        Person? selectedPerson; // Person selected from dropdown

        // Filter list for dropdown: exclude already selected people
        final availablePeople = widget.allPeople
            .where((p) => !_selectedPeople.any((sp) => sp.id == p.id))
            .toList();

        return StatefulBuilder( // Use StatefulBuilder for dialog state
           builder: (context, setDialogState) {
             return AlertDialog(
                title: const Text('Add Participant'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     DropdownButton<Person>(
                       value: selectedPerson,
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
                             selectedPerson = newValue;
                           });
                       },
                     ),
                     if (widget.onAddPerson != null) ...[ // Show 'Add New' only if callback provided
                         const SizedBox(height: 10),
                         const Text('Or add new person:'),
                         TextField(
                           controller: _addPersonController,
                           decoration: const InputDecoration(labelText: 'New Person Name'),
                           onChanged: (value) {
                              // Clear dropdown selection if user starts typing a new name
                              if (value.isNotEmpty && selectedPerson != null) {
                                  setDialogState(() {
                                      selectedPerson = null;
                                  });
                              }
                           },
                         ),
                     ]
                  ],
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

                      if (selectedPerson != null) {
                          // Add selected existing person
                          _addSelectedPerson(selectedPerson!);
                          _addPersonController.clear();
                           Navigator.of(context).pop();
                      } else if (newName.isNotEmpty && widget.onAddPerson != null) {
                         // Try adding the new person via the callback
                         final addedPerson = await widget.onAddPerson!(newName);
                         if (addedPerson != null) {
                            _addSelectedPerson(addedPerson); // Add the newly created person
                         }
                         _addPersonController.clear();
                         Navigator.of(context).pop();
                         // Error handling for addPerson is done in the callback provider/screen
                      } else if (newName.isEmpty && selectedPerson == null) {
                         // No selection and no new name entered
                          ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(content: Text('Please select or enter a name.')),
                          );
                      }
                    },
                  ),
                ],
             );
           }
        );
      },
    );
  }

  void _addSelectedPerson(Person person) {
    // Add person if not already selected
    if (!_selectedPeople.any((p) => p.id == person.id)) {
      setState(() {
        _selectedPeople.add(person);
      });
      widget.onSelectionChanged(_selectedPeople); // Notify parent
    }
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(5.0),
      ),
      child: Wrap(
        spacing: 6.0,
        runSpacing: 0.0,
        children: [
          ..._selectedPeople.map((person) => Chip(
                label: Text(person.name),
                onDeleted: () {
                  setState(() {
                    _selectedPeople.removeWhere((p) => p.id == person.id);
                  });
                  widget.onSelectionChanged(_selectedPeople); // Notify parent
                },
              )),
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
            onPressed: _showAddPersonDialog,
            tooltip: 'Add Participant',
             visualDensity: VisualDensity.compact,
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
import 'package:btour/models/tour.dart';
import 'package:btour/providers/tour_provider.dart';
import 'package:btour/screens/add_edit_expense_screen.dart'; // Create this
import 'package:btour/screens/add_edit_tour_screen.dart';
import 'package:btour/widgets/expense_list_item.dart'; // Create this

class TourDetailScreen extends StatelessWidget {
  const TourDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tourProvider = Provider.of<TourProvider>(context);
    final tour = tourProvider.currentTour;
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    if (tourProvider.isLoading && tour == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Tour...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (tour == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(
          child: Text('Tour not found or error loading details.'),
        ),
      );
    }

    // Calculate remaining amount
    final remainingAmount = tour.advanceAmount - tourProvider.currentTourTotalSpent;

    return DefaultTabController(
      length: 3, // Overview, Expenses, Report
      child: Scaffold(
        appBar: AppBar(
          title: Text(tour.name, overflow: TextOverflow.ellipsis),
          actions: [
            // Edit Tour Button
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Tour',
              onPressed: tour.status == TourStatus.Ended ? null : () { // Disable edit if ended
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => AddEditTourScreen(tourToEdit: tour),
                ));
              },
            ),
             // Tour Status Actions (Start/End/Reopen)
            _buildStatusActionButton(context, tourProvider, tour),

             // Delete Tour Button (use with caution!)
             IconButton(
               icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
               tooltip: 'Delete Tour',
               onPressed: () => _confirmDeleteTour(context, tourProvider, tour.id!),
             ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview', icon: Icon(Icons.info_outline)),
              Tab(text: 'Expenses', icon: Icon(Icons.receipt_long)),
              Tab(text: 'Report', icon: Icon(Icons.summarize)),
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
         floatingActionButton: tour.status == TourStatus.Ended ? null : FloatingActionButton( // Hide FAB if ended
            onPressed: () {
               Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => AddEditExpenseScreen(tour: tour), // Pass current tour
               ));
            },
            tooltip: 'Add Expense',
            child: const Icon(Icons.add),
         ),
      ),
    );
  }

  // --- Status Action Button Logic ---
  Widget _buildStatusActionButton(BuildContext context, TourProvider tourProvider, Tour tour) {
     switch (tour.status) {
       case TourStatus.Created:
         return IconButton(
           icon: const Icon(Icons.play_arrow),
           tooltip: 'Start Tour',
           onPressed: () async {
             await tourProvider.changeTourStatus(tour.id!, TourStatus.Started);
             ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Tour Started!')));
           },
         );
       case TourStatus.Started:
          return IconButton(
             icon: const Icon(Icons.stop),
             tooltip: 'End Tour',
             onPressed: () async {
                // Optional: Confirm before ending
                await tourProvider.changeTourStatus(tour.id!, TourStatus.Ended);
                ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Tour Ended! Final report available.')));
             },
           );
       case TourStatus.Ended:
          return IconButton(
             icon: const Icon(Icons.refresh),
             tooltip: 'Reopen Tour',
             onPressed: () async {
                // Optional: Confirm before reopening
                await tourProvider.changeTourStatus(tour.id!, TourStatus.Started); // Reopen to 'Started' status
                ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Tour Reopened!')));
             },
           );
     }
  }

  // --- Delete Confirmation ---
  void _confirmDeleteTour(BuildContext context, TourProvider tourProvider, int tourId) {
     showDialog(
       context: context,
       builder: (ctx) => AlertDialog(
         title: const Text('Are you sure?'),
         content: const Text(
           'Do you want to permanently delete this tour and all its expenses? This action cannot be undone.',
         ),
         actions: <Widget>[
           TextButton(
             child: const Text('No'),
             onPressed: () {
               Navigator.of(ctx).pop();
             },
           ),
           TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
             child: const Text('Yes, Delete'),
             onPressed: () async {
                Navigator.of(ctx).pop(); // Close dialog
                try {
                   await tourProvider.deleteTour(tourId);
                   // Navigate back to list screen after deletion
                   if (context.mounted) {
                     Navigator.of(context).pop(); // Pop detail screen
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text('Tour deleted successfully.')));
                   }
                } catch (e) {
                    if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text('Error deleting tour: $e')),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           _buildInfoRow(context, Icons.calendar_today, 'Dates', '${tour.formattedStartDate} - ${tour.formattedEndDate}'),
           const SizedBox(height: 12),
           _buildInfoRow(context, Icons.flag, 'Status', tour.statusString, chipColor: _getStatusColor(tour.status)),
           const SizedBox(height: 12),
           _buildInfoRow(context, Icons.account_circle, 'Advance Holder', tourProvider.currentTourAdvanceHolder?.name ?? 'Loading...'),
           const SizedBox(height: 12),
           _buildInfoRow(context, Icons.attach_money, 'Advance Amount', currencyFormat.format(tour.advanceAmount), valueColor: Colors.green.shade700),
           const SizedBox(height: 12),
           _buildInfoRow(context, Icons.receipt, 'Total Spent', currencyFormat.format(tourProvider.currentTourTotalSpent), valueColor: Colors.red.shade700),
           const SizedBox(height: 12),
           _buildInfoRow(context, Icons.account_balance_wallet, 'Remaining', currencyFormat.format(remainingAmount), valueColor: remainingAmount >= 0 ? Colors.blue.shade800 : Colors.orange.shade900, isBold: true),
           const Divider(height: 30),
           Text('Participants (${tourProvider.currentTourParticipants.length})', style: Theme.of(context).textTheme.titleMedium),
           const SizedBox(height: 8),
           tourProvider.currentTourParticipants.isEmpty
              ? const Text('No participants listed.')
              : Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: tourProvider.currentTourParticipants
                      .map((person) => Chip(label: Text(person.name)))
                      .toList(),
                ),
            // Add more overview details if needed
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value, {Color? valueColor, Color? chipColor, bool isBold = false}) {
     Widget valueWidget = Text(
       value,
       style: Theme.of(context).textTheme.bodyLarge?.copyWith(
         color: valueColor,
         fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
       ),
     );

     if (chipColor != null) {
       valueWidget = Chip(
         label: Text(value),
         backgroundColor: chipColor,
         labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
         materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
         visualDensity: VisualDensity.compact,
       );
     }


     return Row(
       children: [
         Icon(icon, color: Colors.grey.shade600, size: 20),
         const SizedBox(width: 12),
         Text('$label:', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey.shade700)),
         const SizedBox(width: 8),
         Expanded(child: Align(alignment: Alignment.centerLeft, child: valueWidget)),
       ],
     );
  }

  Color _getStatusColor(TourStatus status) {
     switch (status) {
        case TourStatus.Created: return Colors.grey;
        case TourStatus.Started: return Colors.blue;
        case TourStatus.Ended: return Colors.green;
     }
  }


  Widget _buildExpensesTab(BuildContext context, TourProvider tourProvider, Tour tour) {
    final expenses = tourProvider.currentTourExpenses;

    if (tourProvider.isLoading) {
       return const Center(child: CircularProgressIndicator());
    }

    if (expenses.isEmpty) {
      return const Center(
        child: Text('No expenses added for this tour yet.'),
      );
    }

    return ListView.builder(
       padding: const EdgeInsets.only(bottom: 80), // Padding for FAB
      itemCount: expenses.length,
      itemBuilder: (context, index) {
        final expense = expenses[index];
        return ExpenseListItem( // Use the dedicated widget
          expense: expense,
          tourStatus: tour.status, // Pass status to enable/disable actions
          onTap: () {
              // Navigate to edit expense screen
               Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => AddEditExpenseScreen(tour: tour, expenseToEdit: expense),
               ));
          },
          onDelete: () async {
              // Optional: Add confirmation dialog here
              try {
                  await tourProvider.deleteExpenseFromCurrentTour(expense.id!);
                   ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Expense deleted.')));
              } catch (e) {
                   ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error deleting expense: $e')));
              }
          },
        );
      },
    );
  }


   Widget _buildReportTab(BuildContext context, TourProvider tourProvider, Tour tour, NumberFormat currencyFormat) {
       final paymentsByPerson = tourProvider.currentTourPaymentsByPerson; // Map<personId, amount>
       final peopleMap = tourProvider.peopleMap; // Map<personId, Person>

       if (tourProvider.isLoading) {
           return const Center(child: CircularProgressIndicator());
       }

       // Create a list of report entries
       final reportEntries = paymentsByPerson.entries.map((entry) {
           final personId = entry.key;
           final amountPaid = entry.value;
           final personName = peopleMap[personId]?.name ?? 'Unknown Person [$personId]';
           return MapEntry(personName, amountPaid);
       }).toList();

       // Sort by name or amount if desired
       reportEntries.sort((a, b) => a.key.compareTo(b.key)); // Sort by name

       final totalSpent = tourProvider.currentTourTotalSpent;
       final advance = tour.advanceAmount;
       final remaining = advance - totalSpent;

       return SingleChildScrollView(
           padding: const EdgeInsets.all(16.0),
           child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                   Text('Tour Financial Summary', style: Theme.of(context).textTheme.titleLarge),
                   const SizedBox(height: 16),
                   _buildReportSummaryItem('Total Advance:', currencyFormat.format(advance), Colors.green.shade700),
                   _buildReportSummaryItem('Total Spent:', currencyFormat.format(totalSpent), Colors.red.shade700),
                   _buildReportSummaryItem('Remaining Balance:', currencyFormat.format(remaining), remaining >= 0 ? Colors.blue.shade800 : Colors.orange.shade900, isBold: true),

                   const Divider(height: 30),

                   Text('Payments Made By Individuals', style: Theme.of(context).textTheme.titleLarge),
                   const SizedBox(height: 8),
                   Text(
                      '(This shows who physically paid for expenses during the tour. The total spent is deducted from the advance regardless.)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)
                   ),
                   const SizedBox(height: 16),

                   if (reportEntries.isEmpty)
                      const Text('No individual payments recorded yet.')
                   else
                      ListView.separated(
                          shrinkWrap: true, // Important inside SingleChildScrollView
                          physics: const NeverScrollableScrollPhysics(), // Disable scrolling of the inner list
                          itemCount: reportEntries.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                              final entry = reportEntries[index];
                              return ListTile(
                                  dense: true,
                                  title: Text(entry.key), // Person Name
                                  trailing: Text(
                                      currencyFormat.format(entry.value), // Amount Paid
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                              );
                          },
                      ),

                   // TODO: Add more detailed reports if needed (e.g., category breakdown)
               ],
           ),
       );
   }

    Widget _buildReportSummaryItem(String label, String value, Color valueColor, {bool isBold = false}) {
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
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
import 'package:btour/providers/tour_provider.dart'; // To get category/person names

class ExpenseListItem extends StatelessWidget {
  final Expense expense;
  final TourStatus tourStatus; // To disable actions if tour ended
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const ExpenseListItem({
    super.key,
    required this.expense,
    required this.tourStatus,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final tourProvider = Provider.of<TourProvider>(context, listen: false); // Don't need to listen

    // Fetch category name - ideally, Category should be part of Expense object or fetched efficiently
    final category = tourProvider.categories.firstWhere(
       (cat) => cat.id == expense.categoryId,
       orElse: () => const Category(id: -1, name: 'Unknown') // Fallback category
    );

    // Fetch basic payment info (e.g., who paid primarily) - might require loading payments
    // This is simplified; a real app might show more payment details directly
    // String paymentInfo = "Paid by Advance Holder (default)"; // Placeholder

    return Card(
       margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(expense.description ?? 'No description'),
             const SizedBox(height: 4),
             Text('Date: ${expense.formattedDate}'),
            // Optional: Show who paid here - requires fetching payment data
             // FutureBuilder<List<ExpensePayment>>(
             //    future: DatabaseHelper.instance.getExpensePayments(expense.id!), // Example direct fetch
             //    builder: (context, snapshot) { ... }
             // ),
          ],
        ),
        trailing: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           crossAxisAlignment: CrossAxisAlignment.end,
           children: [
             Text(
               currencyFormat.format(expense.amount),
               style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.redAccent),
             ),
              // Show edit/delete only if tour is not ended
              if (tourStatus != TourStatus.Ended)
                 SizedBox(
                    height: 30, // Constrain height
                    child: IconButton(
                       icon: const Icon(Icons.delete_outline, color: Colors.grey),
                       iconSize: 20,
                       tooltip: 'Delete Expense',
                       onPressed: onDelete,
                       padding: EdgeInsets.zero,
                       visualDensity: VisualDensity.compact,
                     ),
                 ),
           ],
        ),
        onTap: onTap, // Navigate to edit screen
      ),
    );
  }
}
```

```markdown
// FILE: lib/screens/add_edit_expense_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:btour/models/category.dart';
import 'package:btour/models/expense.dart';
import 'package:btour/models/person.dart';
import 'package:btour/models/tour.dart';
import 'package:btour/providers/tour_provider.dart';
import 'package:btour/widgets/person_multi_selector.dart'; // Re-use for attendees

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
  late TextEditingController _categoryController; // For adding new category

  DateTime _selectedDate = DateTime.now();
  Category? _selectedCategory;
  List<Category> _availableCategories = [];
  List<Person> _tourParticipants = []; // People participating in the tour
  List<Person> _selectedAttendees = [];

  // --- Payment Tracking ---
  // Store payments as a list of map or dedicated objects
  // Key: Person ID, Value: Amount Paid
  List<ExpensePayment> _expensePayments = [];

  bool _isLoading = false; // Local loading state

  @override
  void initState() {
    super.initState();

    _amountController = TextEditingController(text: widget.expenseToEdit?.amount.toStringAsFixed(2) ?? '');
    _descriptionController = TextEditingController(text: widget.expenseToEdit?.description ?? '');
    _categoryController = TextEditingController(); // Init empty for adding new

    _selectedDate = widget.expenseToEdit?.date ?? DateTime.now();

    // Fetch initial data (categories, participants, and existing expense details if editing)
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final tourProvider = Provider.of<TourProvider>(context, listen: false);

    // Ensure categories and tour participants are loaded
    if (tourProvider.categories.isEmpty) await tourProvider.fetchAllCategories();
    _availableCategories = tourProvider.categories;

    // Fetch participants specifically for *this* tour
    _tourParticipants = await DatabaseHelper.instance.getTourParticipants(widget.tour.id!); // Direct DB call for simplicity here


    if (widget.isEditing && widget.expenseToEdit != null) {
      final expense = widget.expenseToEdit!;
      // Pre-select category
      _selectedCategory = _availableCategories.firstWhere(
          (cat) => cat.id == expense.categoryId,
          orElse: () => null); // Handle if category was deleted

      // Pre-select attendees
      final attendeeIds = (await DatabaseHelper.instance.getExpenseAttendees(expense.id!))
                            .map((p) => p.id!)
                            .toList();
      _selectedAttendees = _tourParticipants.where((p) => attendeeIds.contains(p.id)).toList();


      // Load existing payments
      _expensePayments = await DatabaseHelper.instance.getExpensePayments(expense.id!);
       // Ensure payments list has entries for all participants (even if 0) for the UI
       _syncPaymentsWithParticipants();


    } else {
      // Default for new expense:
      // Default category? Maybe the first one?
      // _selectedCategory = _availableCategories.isNotEmpty ? _availableCategories.first : null;

      // Default attendees? Maybe all participants?
      // _selectedAttendees = List.from(_tourParticipants);

       // Default payment: Advance holder pays the full amount (will be set when amount changes)
       _setDefaultPayment();
       _syncPaymentsWithParticipants(); // Ensure UI reflects participant list

    }


    setState(() => _isLoading = false);
  }

   // Ensure the _expensePayments list reflects the current _tourParticipants
   // Adds participants with 0 payment if not present, removes payments for non-participants
   void _syncPaymentsWithParticipants() {
       final List<ExpensePayment> syncedPayments = [];
       final currentAmount = double.tryParse(_amountController.text) ?? 0.0;

       for (var participant in _tourParticipants) {
           final existingPayment = _expensePayments.firstWhere(
               (p) => p.personId == participant.id,
               orElse: () => ExpensePayment( // Create a default 0 payment if not found
                   expenseId: widget.expenseToEdit?.id ?? 0, // Use 0 or handle differently for new expense
                   personId: participant.id!,
                   amountPaid: 0.0,
               ),
           );
           syncedPayments.add(existingPayment);
       }

        // Handle default payment for NEW expenses if no payments exist yet
       if (!widget.isEditing && syncedPayments.every((p) => p.amountPaid == 0) && currentAmount > 0) {
           final advanceHolderPaymentIndex = syncedPayments.indexWhere((p) => p.personId == widget.tour.advanceHolderPersonId);
           if (advanceHolderPaymentIndex != -1) {
               syncedPayments[advanceHolderPaymentIndex] = syncedPayments[advanceHolderPaymentIndex].copyWith(amountPaid: currentAmount);
           }
       }

       setState(() {
           _expensePayments = syncedPayments;
       });
   }


   // Set default payment to advance holder paying full amount
   void _setDefaultPayment() {
      final currentAmount = double.tryParse(_amountController.text) ?? 0.0;
      _expensePayments.clear(); // Clear existing payments

      // Create a new payment list where only the advance holder pays
      for (var participant in _tourParticipants) {
          _expensePayments.add(ExpensePayment(
              expenseId: widget.expenseToEdit?.id ?? 0, // Placeholder/actual ID
              personId: participant.id!,
              amountPaid: (participant.id == widget.tour.advanceHolderPersonId) ? currentAmount : 0.0,
          ));
      }
   }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000), // Allow past dates
      lastDate: DateTime.now().add(const Duration(days: 1)), // Allow up to tomorrow? Or just today?
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
                              }
                          },
                      ),
                  ],
              );
          },
      );

      if (newCategoryName != null) {
          final tourProvider = Provider.of<TourProvider>(context, listen: false);
          try {
              final newCategory = await tourProvider.addCategory(newCategoryName);
              setState(() {
                  _availableCategories = tourProvider.categories; // Refresh list
                  _selectedCategory = newCategory; // Select the newly added category
              });
          } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error adding category: $e')),
              );
          }
      }
  }

  // --- Payment Input Handling ---
  void _updatePayment(int personId, String value) {
     final amount = double.tryParse(value) ?? 0.0;
     final index = _expensePayments.indexWhere((p) => p.personId == personId);
     if (index != -1) {
        setState(() {
            _expensePayments[index] = _expensePayments[index].copyWith(amountPaid: amount);
        });
     }
  }

   // Distribute remaining amount equally among selected attendees
   // Or maybe just ensure total payments = total expense amount? Let's stick to tracking who paid what.
   // The total expense amount is what matters for deduction from advance.
   // We don't strictly need payments to sum up, but it's good practice for reporting.

  // --- Form Submission ---
  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select or add a Category.')),
        );
        return;
      }
       if (_selectedAttendees.isEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Please select at least one Attendee.')),
         );
         return;
       }

       // Optional: Validate that payment amounts sum up to the total amount
       final totalPaid = _expensePayments.fold<double>(0.0, (sum, item) => sum + item.amountPaid);
       final totalAmount = double.tryParse(_amountController.text) ?? 0.0;
       if ((totalPaid - totalAmount).abs() > 0.01) { // Allow for small floating point differences
          // Show a warning or error, or automatically adjust?
          // For now, let's allow it but maybe log a warning. The key is totalAmount for deduction.
          print("Warning: Sum of payments ($totalPaid) does not match expense amount ($totalAmount).");
       }


      setState(() => _isLoading = true);
      final tourProvider = Provider.of<TourProvider>(context, listen: false);

      final expenseData = Expense(
        id: widget.expenseToEdit?.id, // Null for new expense
        tourId: widget.tour.id!,
        categoryId: _selectedCategory!.id!,
        amount: totalAmount,
        date: _selectedDate,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      final attendeeIds = _selectedAttendees.map((p) => p.id!).toList();
      // Filter payments to only include those > 0? Or keep all? Let's keep all non-zero.
       final validPayments = _expensePayments.where((p) => p.amountPaid > 0).toList();


      try {
        if (widget.isEditing) {
          await tourProvider.updateExpenseInCurrentTour(expenseData, attendeeIds, validPayments);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense Updated Successfully!')),
          );
        } else {
          await tourProvider.addExpenseToCurrentTour(expenseData, attendeeIds, validPayments);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense Added Successfully!')),
          );
        }
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving expense: $e')),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final tourProvider = Provider.of<TourProvider>(context, listen: false); // For lookups

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Expense' : 'Add Expense'),
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
      body: _isLoading && _availableCategories.isEmpty // Initial load indicator
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
                       crossAxisAlignment: CrossAxisAlignment.end,
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
                                labelText: 'Category',
                                border: OutlineInputBorder()
                            ),
                            validator: (value) => value == null ? 'Please select a category' : null,
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
                          labelText: 'Amount', prefixText: '₹ '),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                       onChanged: (value) {
                          // If payments haven't been manually edited yet, update default payment
                          // Simple check: if all others are 0 and holder has previous value
                          final currentTotalAmount = double.tryParse(value) ?? 0.0;
                          final advanceHolderPayment = _expensePayments.firstWhere(
                              (p) => p.personId == widget.tour.advanceHolderPersonId,
                              orElse: () => ExpensePayment(expenseId: 0, personId: 0, amountPaid: -1) // Dummy
                          );
                          bool onlyHolderPaid = _expensePayments.where((p) => p.personId != widget.tour.advanceHolderPersonId).every((p) => p.amountPaid == 0);

                          if (advanceHolderPayment.personId != 0 && onlyHolderPaid) {
                              _updatePayment(widget.tour.advanceHolderPersonId, value);
                          }
                       },
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
                           labelText: 'Date',
                           border: OutlineInputBorder()
                         ),
                         child: Text(dateFormat.format(_selectedDate)),
                       ),
                     ),
                    const SizedBox(height: 16),

                    // --- Description ---
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Description (Optional)'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),

                    // --- Attendees ---
                     Text('Attendees', style: Theme.of(context).textTheme.titleMedium),
                     const SizedBox(height: 8),
                     PersonMultiSelector(
                         // Use tour participants as the pool of selectable people
                         allPeople: _tourParticipants,
                         initialSelectedPeople: _selectedAttendees,
                         onSelectionChanged: (selected) {
                             setState(() { _selectedAttendees = selected; });
                         },
                         // Don't allow adding new people directly here, should be managed at tour level
                         // onAddPerson: null,
                     ),
                     const SizedBox(height: 20),


                     // --- Payers ---
                      Text('Paid By', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                       Text(
                          '(Specify who paid how much for this expense. The total amount will be deducted from the tour advance.)',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)
                       ),
                      const SizedBox(height: 8),
                      if (_expensePayments.isEmpty)
                          const Text('Add participants to specify payments.')
                      else
                          ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _expensePayments.length,
                              itemBuilder: (context, index) {
                                  final payment = _expensePayments[index];
                                  final person = _tourParticipants.firstWhere((p) => p.id == payment.personId);
                                  // Need controllers for each payment field
                                  // Using initialValue is simpler for this example if list doesn't reorder
                                  return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: Row(
                                          children: [
                                              Expanded(child: Text(person.name, overflow: TextOverflow.ellipsis)),
                                              const SizedBox(width: 10),
                                              SizedBox(
                                                  width: 120, // Fixed width for amount input
                                                  child: TextFormField(
                                                      // Use key to ensure state is kept if list rebuilds carelessly
                                                      key: ValueKey('payment_${person.id}'),
                                                      initialValue: payment.amountPaid.toStringAsFixed(2),
                                                      decoration: const InputDecoration(
                                                          prefixText: '₹ ',
                                                          border: OutlineInputBorder(),
                                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                                          isDense: true,
                                                      ),
                                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                      onChanged: (value) => _updatePayment(person.id!, value),
                                                      // Basic validation within the field if needed
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

---

**Node.js Script (save as `create_files.js`):**

```javascript
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
    const codeBlockRegex = /```dart\s*\/\/\s*FILE:\s*(.*?)\s*?\n([\s\S]*?)```/g;

    let match;
    let filesCreated = 0;

    while ((match = codeBlockRegex.exec(markdownContent)) !== null) {
        const relativeFilePath = match[1].trim();
        let codeContent = match[2].trim();

        if (!relativeFilePath) {
            console.warn('Found Dart code block without a valid // FILE: marker. Skipping.');
            continue;
        }

        // Make the path relative to the script's execution directory or a specific base dir
        const absoluteFilePath = path.resolve(process.cwd(), relativeFilePath);
        const directoryPath = path.dirname(absoluteFilePath);

        try {
            // Create directories recursively if they don't exist
            if (!fs.existsSync(directoryPath)) {
                fs.mkdirSync(directoryPath, { recursive: true });
                console.log(`Created directory: ${directoryPath}`);
            }

            // Write the code content to the file
            fs.writeFileSync(absoluteFilePath, codeContent, 'utf-8');
            console.log(`Successfully wrote file: ${absoluteFilePath}`);
            filesCreated++;

        } catch (err) {
            console.error(`Error processing file ${relativeFilePath}:`, err);
        }
    }

    if (filesCreated > 0) {
         console.log(`\n✅ Successfully created ${filesCreated} files.`);
    } else {
         console.log('\n⚠️ No Flutter/Dart code blocks with valid "// FILE: path/to/file.dart" markers found.');
    }


} catch (err) {
    console.error('Error reading or processing Markdown file:', err);
    process.exit(1);
}
```

**How to Use:**

1.  **Save Code:** Save all the Flutter code blocks above into a single text file named `flutter_app.md` (or any other name). Make sure the `// FILE: lib/path/to/your/file.dart` comment is on the *first line* right after the opening ```dart fence.
2.  **Save Script:** Save the Node.js script code into a file named `create_files.js` in the *root* directory of your Flutter project (`tour_expense_app/`).
3.  **Navigate:** Open your terminal or command prompt and navigate *into* your Flutter project's root directory (`cd tour_expense_app`).
4.  **Run Script:** Execute the Node.js script, passing the Markdown file as an argument:
    ```bash
    node create_files.js ../flutter_app.md
    # Or, if flutter_app.md is in the current directory:
    # node create_files.js flutter_app.md
    ```
5.  **Verify:** The script will read `flutter_app.md`, find the code blocks, create the necessary `lib/database`, `lib/models`, `lib/providers`, `lib/screens`, `lib/widgets` directories, and place the corresponding `.dart` files inside them.
6.  **Run Flutter App:** You should now be able to run `flutter run` in your terminal from the `tour_expense_app` directory.

This provides a solid foundation. You'll likely need to refine the UI/UX, add more robust error handling, potentially implement more complex state management (like Provider properly injected or Riverpod), and add more detailed reporting features as needed.