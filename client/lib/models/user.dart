class User {
  final String? id;
  final String surname;
  final String name;
  final String? patronymic;
  final String? departmentId;
  final String? departmentName;
  final String? comment;
  final bool isApproved;
  final String? publicKey;

  User({
    this.id,
    required this.surname,
    required this.name,
    this.patronymic,
    this.departmentId,
    this.departmentName,
    this.comment,
    this.isApproved = false,
    this.publicKey,
  });

  Map<String, dynamic> toJson() => {
    'surname': surname,
    'name': name,
    'patronymic': patronymic,
    'department_id': departmentId,
    'comment': comment,
    'public_key': publicKey,
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
      publicKey: json['public_key'],
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
  final String? publicKey;

  UserSearchResult({
    required this.id,
    required this.surname,
    required this.name,
    this.patronymic,
    required this.departmentId,
    required this.departmentName,
    this.comment,
    this.publicKey,
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
      publicKey: json['public_key'],
    );
  }
}
