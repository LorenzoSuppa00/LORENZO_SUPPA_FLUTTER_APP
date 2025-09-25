class User {
  final int id;
  String name;
  String email;

  User({
    required this.id,
    required this.name,
    required this.email,
  });

  // Converti un User in JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
    };
  }

  // Crea un User da JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
    );
  }
}
