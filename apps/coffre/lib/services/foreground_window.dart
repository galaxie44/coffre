import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';

class ForegroundWindowInfo {
  const ForegroundWindowInfo({
    required this.processName,
    required this.windowTitle,
    required this.hwnd,
  });

  final String processName;
  final String windowTitle;
  final int hwnd;

  static const empty = ForegroundWindowInfo(
    processName: '',
    windowTitle: '',
    hwnd: 0,
  );

  ForegroundWindowInfo copyWith({
    String? processName,
    String? windowTitle,
    int? hwnd,
  }) {
    return ForegroundWindowInfo(
      processName: processName ?? this.processName,
      windowTitle: windowTitle ?? this.windowTitle,
      hwnd: hwnd ?? this.hwnd,
    );
  }
}

class ForegroundWindow {
  static final _processCache = <int, String>{};

  /// Rapide : hwnd + titre seulement (hotkey Ctrl+Shift+Espace).
  static ForegroundWindowInfo captureQuick() {
    if (!Platform.isWindows) return ForegroundWindowInfo.empty;
    final hwnd = GetForegroundWindow();
    if (hwnd == 0) return ForegroundWindowInfo.empty;

    final length = GetWindowTextLength(hwnd);
    var title = '';
    if (length > 0) {
      final buffer = wsalloc(length + 1);
      GetWindowText(hwnd, buffer, length + 1);
      title = buffer.toDartString();
      free(buffer);
    }

    return ForegroundWindowInfo(
      processName: '',
      windowTitle: title,
      hwnd: hwnd,
    );
  }

  /// Complet (plus lent) — avec nom de processus.
  static ForegroundWindowInfo current() {
    final quick = captureQuick();
    if (quick.hwnd == 0) return quick;
    final pid = calloc<DWORD>();
    GetWindowThreadProcessId(quick.hwnd, pid);
    final processName = _processName(pid.value);
    free(pid);
    return quick.copyWith(processName: processName);
  }

  /// Complète le nom de processus en arrière-plan.
  static ForegroundWindowInfo enrich(ForegroundWindowInfo info) {
    if (info.hwnd == 0 || info.processName.isNotEmpty) return info;
    final pid = calloc<DWORD>();
    GetWindowThreadProcessId(info.hwnd, pid);
    final processName = _processName(pid.value);
    free(pid);
    return info.copyWith(processName: processName);
  }

  static void restore(int hwnd) {
    if (!Platform.isWindows || hwnd == 0) return;
    SetForegroundWindow(hwnd);
  }

  static String _processName(int processId) {
    if (processId <= 0) return '';
    final cached = _processCache[processId];
    if (cached != null) return cached;

    final handle = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, processId);
    if (handle == 0) return '';
    final buffer = wsalloc(MAX_PATH);
    final ok = GetModuleFileNameEx(handle, 0, buffer, MAX_PATH);
    var name = '';
    if (ok > 0) {
      name = p.basename(buffer.toDartString()).toLowerCase();
    }
    free(buffer);
    CloseHandle(handle);
    if (name.isNotEmpty) _processCache[processId] = name;
    return name;
  }
}
