class Machine {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;

  const Machine({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
  });

  /// Creates a new Machine with a timestamp-based id.
  /// Password is NOT stored on Machine — it lives in flutter_secure_storage
  /// keyed by `ssh_password_<id>`.
  factory Machine.generate({
    required String name,
    required String host,
    required int port,
    required String username,
  }) {
    return Machine(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      host: host,
      port: port,
      username: username,
    );
  }

  Machine copyWith({
    String? name,
    String? host,
    int? port,
    String? username,
  }) =>
      Machine(
        id: id,
        name: name ?? this.name,
        host: host ?? this.host,
        port: port ?? this.port,
        username: username ?? this.username,
      );

  factory Machine.fromJson(Map<String, dynamic> json) => Machine(
        id: json['id'] as String,
        name: json['name'] as String,
        host: json['host'] as String,
        port: json['port'] as int,
        username: json['username'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'username': username,
      };
}
