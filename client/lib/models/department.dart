class Department {
  final String id;
  final String name;
  final int level;
  final String? parentId;
  
  Department({
    required this.id,
    required this.name,
    required this.level,
    this.parentId,
  });
  
  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['id'].toString(),
      name: json['name'],
      level: json['level'],
      parentId: json['parent_id']?.toString(),
    );
  }
}