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

class UserInfo {
  final String id;
  final String surname;
  final String name;
  final String? patronymic;
  final String? comment;

  UserInfo({
    required this.id,
    required this.surname,
    required this.name,
    this.patronymic,
    this.comment,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id'].toString(),
      surname: json['surname'],
      name: json['name'],
      patronymic: json['patronymic'],
      comment: json['comment'],
    );
  }

  String get fullName {
    if (patronymic != null && patronymic!.isNotEmpty) {
      return '$surname $name $patronymic';
    }
    return '$surname $name';
  }
}

class DepartmentWithUsers {
  final String id;
  final String name;
  final int level;
  final String? parentId;
  final List<UserInfo> users;

  DepartmentWithUsers({
    required this.id,
    required this.name,
    required this.level,
    this.parentId,
    required this.users,
  });

  factory DepartmentWithUsers.fromJson(Map<String, dynamic> json) {
    return DepartmentWithUsers(
      id: json['id'].toString(),
      name: json['name'],
      level: json['level'],
      parentId: json['parent_id']?.toString(),
      users: (json['users'] as List)
          .map((u) => UserInfo.fromJson(u))
          .toList(),
    );
  }
}

class DepartmentNode {
  final String id;
  final String name;
  final int level;
  final List<UserInfo> users;
  final List<DepartmentNode> children;

  DepartmentNode({
    required this.id,
    required this.name,
    required this.level,
    required this.users,
    required this.children,
  });

  factory DepartmentNode.fromJson(Map<String, dynamic> json) {
    return DepartmentNode(
      id: json['id'].toString(),
      name: json['name'],
      level: json['level'],
      users: (json['users'] as List)
          .map((u) => UserInfo.fromJson(u))
          .toList(),
      children: (json['children'] as List)
          .map((c) => DepartmentNode.fromJson(c))
          .toList(),
    );
  }
}