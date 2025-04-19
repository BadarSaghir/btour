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