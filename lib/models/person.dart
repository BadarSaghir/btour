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