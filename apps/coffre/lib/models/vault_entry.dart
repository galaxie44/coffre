import 'package:uuid/uuid.dart';

class VaultEntry {
  VaultEntry({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    this.url = '',
    this.androidPackage = '',
    this.windowsProcess = '',
    this.windowsTitleHint = '',
    this.totpSecret = '',
    this.notes = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now().toUtc(),
        updatedAt = updatedAt ?? DateTime.now().toUtc();

  factory VaultEntry.create({
    required String title,
    required String username,
    required String password,
    String url = '',
    String androidPackage = '',
    String windowsProcess = '',
    String windowsTitleHint = '',
    String totpSecret = '',
    String notes = '',
  }) {
    return VaultEntry(
      id: const Uuid().v4(),
      title: title,
      username: username,
      password: password,
      url: url,
      androidPackage: androidPackage,
      windowsProcess: windowsProcess,
      windowsTitleHint: windowsTitleHint,
      totpSecret: totpSecret,
      notes: notes,
    );
  }

  factory VaultEntry.fromJson(Map<String, dynamic> json) {
    return VaultEntry(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      url: json['url'] as String? ?? '',
      androidPackage: json['androidPackage'] as String? ?? '',
      windowsProcess: json['windowsProcess'] as String? ?? '',
      windowsTitleHint: json['windowsTitleHint'] as String? ?? '',
      totpSecret: json['totpSecret'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
    );
  }

  final String id;
  final String title;
  final String username;
  final String password;
  final String url;
  final String androidPackage;
  final String windowsProcess;
  final String windowsTitleHint;
  final String totpSecret;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get domain {
    final raw = url.trim();
    if (raw.isEmpty) return '';
    try {
      final uri = Uri.parse(raw.contains('://') ? raw : 'https://$raw');
      return uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    } catch (_) {
      return raw.toLowerCase();
    }
  }

  VaultEntry copyWith({
    String? title,
    String? username,
    String? password,
    String? url,
    String? androidPackage,
    String? windowsProcess,
    String? windowsTitleHint,
    String? totpSecret,
    String? notes,
  }) {
    return VaultEntry(
      id: id,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      url: url ?? this.url,
      androidPackage: androidPackage ?? this.androidPackage,
      windowsProcess: windowsProcess ?? this.windowsProcess,
      windowsTitleHint: windowsTitleHint ?? this.windowsTitleHint,
      totpSecret: totpSecret ?? this.totpSecret,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'username': username,
        'password': password,
        'url': url,
        'androidPackage': androidPackage,
        'windowsProcess': windowsProcess,
        'windowsTitleHint': windowsTitleHint,
        'totpSecret': totpSecret,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class VaultPayload {
  VaultPayload({
    List<VaultEntry>? entries,
    this.autoLockSeconds = 60,
  }) : entries = entries ?? [];

  factory VaultPayload.fromJson(Map<String, dynamic> json) {
    final list = (json['entries'] as List<dynamic>? ?? [])
        .map((e) => VaultEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return VaultPayload(
      entries: list,
      autoLockSeconds: json['autoLockSeconds'] as int? ?? 60,
    );
  }

  final List<VaultEntry> entries;
  final int autoLockSeconds;

  Map<String, dynamic> toJson() => {
        'entries': entries.map((e) => e.toJson()).toList(),
        'autoLockSeconds': autoLockSeconds,
      };

  VaultPayload copyWith({
    List<VaultEntry>? entries,
    int? autoLockSeconds,
  }) {
    return VaultPayload(
      entries: entries ?? this.entries,
      autoLockSeconds: autoLockSeconds ?? this.autoLockSeconds,
    );
  }
}

bool matchesWindowsApp({
  required String processName,
  required String windowTitle,
  required String entryProcess,
  required String entryTitleHint,
}) {
  final proc = processName.toLowerCase();
  final title = windowTitle.toLowerCase();
  final ep = entryProcess.trim().toLowerCase();
  final eh = entryTitleHint.trim().toLowerCase();
  if (ep.isNotEmpty) {
    final target = ep.endsWith('.exe') ? ep : '$ep.exe';
    if (proc == target || proc == ep) return true;
  }
  if (eh.isNotEmpty && title.contains(eh)) return true;
  return false;
}
