class LoginResponse {
  final String userId;
  final String token;
  final String surname;
  final String name;

  LoginResponse({
    required this.userId,
    required this.token,
    required this.surname,
    required this.name,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      userId: json['user_id'].toString(),
      token: json['token'],
      surname: json['surname'],
      name: json['name'],
    );
  }
}