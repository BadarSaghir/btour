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