class LoginRequest {
  const LoginRequest({
    required this.identifier,
    required this.password,
    this.rememberMe = false,
  });

  final String identifier;
  final String password;
  final bool rememberMe;

  Map<String, dynamic> toJson() => {
    'identifier': identifier,
    'password': password,
    'remember_me': rememberMe,
  };
}
