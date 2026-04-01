class LoginRequest {
  final String identifier;
  final String password;

  LoginRequest({required this.identifier, required this.password});

  Map<String, dynamic> toJson() => {
    'identifier': identifier,
    'password': password,
  };
}

class LoginResponse {
  final String token;
  final String userId;
  final String surname;
  final String name;

  LoginResponse({
    required this.token,
    required this.userId,
    required this.surname,
    required this.name,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'],
      userId: json['user_id'],
      surname: json['surname'],
      name: json['name'],
    );
  }
}
