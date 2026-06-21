/// Platform running on the remote machine — drives shell commands and path hints.
enum RemotePlatform {
  linux,
  macos,
  windows;

  String get label => switch (this) {
        RemotePlatform.linux => 'Linux',
        RemotePlatform.macos => 'macOS',
        RemotePlatform.windows => 'Windows',
      };

  /// Example path shown as placeholder in the folder picker field.
  String get pathHint => switch (this) {
        RemotePlatform.linux => '/home/user/projects/myapp',
        RemotePlatform.macos => '/Users/user/projects/myapp',
        RemotePlatform.windows => r'C:\Users\user\projects\myapp',
      };

  /// Shell command to change into [path].
  /// Linux/macOS: bash/zsh `cd "$path"`.
  /// Windows: PowerShell `Set-Location "$path"` (OpenSSH on Windows defaults to PS).
  String cdCommand(String path) => switch (this) {
        RemotePlatform.linux || RemotePlatform.macos => 'cd "$path"',
        RemotePlatform.windows => 'Set-Location "$path"',
      };

  /// Deserialize from JSON string. Unknown values default to [linux] for
  /// backward compatibility with machines saved before this field existed.
  static RemotePlatform fromJson(String? value) => switch (value) {
        'macos' => RemotePlatform.macos,
        'windows' => RemotePlatform.windows,
        _ => RemotePlatform.linux,
      };

  String get _jsonValue => name; // 'linux' | 'macos' | 'windows'
}

class Machine {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final List<String> folderPaths;
  final RemotePlatform platform;

  const Machine({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    this.folderPaths = const [],
    this.platform = RemotePlatform.linux,
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
    RemotePlatform platform = RemotePlatform.linux,
  }) {
    return Machine(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      host: host,
      port: port,
      username: username,
      folderPaths: folderPaths,
      platform: platform,
    );
  }

  Machine copyWith({
    String? name,
    String? host,
    int? port,
    String? username,
    List<String>? folderPaths,
    RemotePlatform? platform,
  }) =>
      Machine(
        id: id,
        name: name ?? this.name,
        host: host ?? this.host,
        port: port ?? this.port,
        username: username ?? this.username,
        folderPaths: folderPaths ?? this.folderPaths,
        platform: platform ?? this.platform,
      );

  factory Machine.fromJson(Map<String, dynamic> json) => Machine(
        id: json['id'] as String,
        name: json['name'] as String,
        host: json['host'] as String,
        port: json['port'] as int,
        username: json['username'] as String,
        folderPaths:
            (json['folderPaths'] as List<dynamic>?)?.cast<String>() ?? const [],
        platform: RemotePlatform.fromJson(json['platform'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'username': username,
        'folderPaths': folderPaths,
        'platform': platform._jsonValue,
      };
}
