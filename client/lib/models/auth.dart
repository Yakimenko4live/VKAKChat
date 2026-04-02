class LoginResponse {
  final String userId;
  final String token;
  final String surname;
  final String name;
  final String? patronymic;
  final String? departmentName;
  final bool isApproved;

  LoginResponse({
    required this.userId,
    required this.token,
    required this.surname,
    required this.name,
    this.patronymic,
    this.departmentName,
    required this.isApproved,
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

  UserData({
    required this.userId,
    required this.surname,
    required this.name,
    this.patronymic,
    this.departmentName,
    this.comment,
    required this.isApproved,
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
    );
  }
}