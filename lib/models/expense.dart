import 'package:intl/intl.dart';
import 'package:btour/models/person.dart'; // Import Person for payments

class ExpenseFields {
  static final List<String> values = [
    id,
    tourId,
    categoryId,
    amount,
    date,
    description,
  ];

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
    this.payments, // Optional init
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
  }) => Expense(
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
