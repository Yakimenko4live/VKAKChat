class LoginResponse {
  final String userId;
  final String token;
  final String surname;
  final String name;
  final String? patronymic;
  final String? departmentName;
  final bool isApproved;
  final String role;

  LoginResponse({
    required this.userId,
    required this.token,
    required this.surname,
    required this.name,
    this.patronymic,
    this.departmentName,
    required this.isApproved,
    required this.role,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      userId: json['user_id'].toString(),
      token: json['token'],
      surname: json['surname'],
      name: json['name'],
      patronymic: json['patronymic'],
      departmentName: json['department_name'],
      isApproved: json['is_approved'] ?? false,
      role: json['role'] ?? 'user',
    );
  }
}

class UserData {
  final String userId;
  final String surname;
  final String name;
  final String? patronymic;
  final String? departmentName;
  final String? comment;
  final bool isApproved;
  final String role;

  UserData({
    required this.userId,
    required this.surname,
    required this.name,
    this.patronymic,
    this.departmentName,
    this.comment,
    required this.isApproved,
    required this.role,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      userId: json['user_id'].toString(),
      surname: json['surname'],
      name: json['name'],
      patronymic: json['patronymic'],
      departmentName: json['department_name'],
      comment: json['comment'],
      isApproved: json['is_approved'] ?? false,
      role: json['role'] ?? 'user',
    );
  }
}

class AllUser {
  final String id;
  final String surname;
  final String name;
  final String? patronymic;
  final String departmentName;
  final String role;
  final bool isApproved;

  AllUser({
    required this.id,
    required this.surname,
    required this.name,
    this.patronymic,
    required this.departmentName,
    required this.role,
    required this.isApproved,
  });

  String get fullName {
    if (patronymic != null && patronymic!.isNotEmpty) {
      return '$surname $name $patronymic';
    }
    return '$surname $name';
  }

  factory AllUser.fromJson(Map<String, dynamic> json) {
    return AllUser(
      id: json['id'].toString(),
      surname: json['surname'],
      name: json['name'],
      patronymic: json['patronymic'],
      departmentName: json['department_name'],
      role: json['role'],
      isApproved: json['is_approved'],
    );
  }
}
