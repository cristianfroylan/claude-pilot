class Machine {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final List<String> folderPaths;

  const Machine({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    this.folderPaths = const [],
  });

  /// Creates a new Machine with a timestamp-based id.
  /// Password is NOT stored on Machine — it lives in flutter_secure_storage
  /// keyed by `ssh_password_<id>`.
  factory Machine.generate({
    required String name,
    required String host,
    required int port,
    required String username,
    List<String> folderPaths = const [],
  }) {
    return Machine(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      host: host,
      port: port,
      username: username,
      folderPaths: folderPaths,
    );
  }

  Machine copyWith({
    String? name,
    String? host,
    int? port,
    String? username,
    List<String>? folderPaths,
  }) =>
      Machine(
        id: id,
        name: name ?? this.name,
        host: host ?? this.host,
        port: port ?? this.port,
        username: username ?? this.username,
        folderPaths: folderPaths ?? this.folderPaths,
      );

  factory Machine.fromJson(Map<String, dynamic> json) => Machine(
        id: json['id'] as String,
        name: json['name'] as String,
        host: json['host'] as String,
        port: json['port'] as int,
        username: json['username'] as String,
        folderPaths: (json['folderPaths'] as List<dynamic>?)?.cast<String>() ?? const [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'username': username,
        'folderPaths': folderPaths,
      };
}
