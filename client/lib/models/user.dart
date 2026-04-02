class User {
  final String? id;
  final String surname;
  final String name;
  final String? patronymic;
  final String? departmentId;
  final String? departmentName;
  final String? comment;
  final bool isApproved;
  
  User({
    this.id,
    required this.surname,
    required this.name,
    this.patronymic,
    this.departmentId,
    this.departmentName,
    this.comment,
    this.isApproved = false,
  });
  
  Map<String, dynamic> toJson() => {
    'surname': surname,
    'name': name,
    'patronymic': patronymic,
    'department_id': departmentId,
    'comment': comment,
  };
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString(),
      surname: json['surname'] ?? '',
      name: json['name'] ?? '',
      patronymic: json['patronymic'],
      departmentId: json['department_id']?.toString(),
      departmentName: json['department_name'],
      comment: json['comment'],
      isApproved: json['is_approved'] ?? false,
    );
  }
}

class UserSearchResult {
  final String id;
  final String surname;
  final String name;
  final String? patronymic;
  final String departmentId;
  final String departmentName;
  final String? comment;

  UserSearchResult({
    required this.id,
    required this.surname,
    required this.name,
    this.patronymic,
    required this.departmentId,
    required this.departmentName,
    this.comment,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: json['id'].toString(),
      surname: json['surname'],
      name: json['name'],
      patronymic: json['patronymic'],
      departmentId: json['department_id'].toString(),
      departmentName: json['department_name'],
      comment: json['comment'],
    );
  }
}