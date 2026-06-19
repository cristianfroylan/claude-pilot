import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E8BC3),
          brightness: Brightness.dark,
        ),
      );

  // TerminalTheme for xterm.dart — matches colorScheme.surface (~#0F1117)
  static const terminalTheme = TerminalTheme(
    cursor: Color(0xFF4BA3C7),
    selection: Color(0xFF4BA3C7),
    foreground: Color(0xFFCDD6F4),
    background: Color(0xFF0F1117),
    black: Color(0xFF1E2030),
    red: Color(0xFFFF757F),
    green: Color(0xFF66BB6A),
    yellow: Color(0xFFFFCB6B),
    blue: Color(0xFF82AAFF),
    magenta: Color(0xFFC792EA),
    cyan: Color(0xFF89DCEB),
    white: Color(0xFFCDD6F4),
    brightBlack: Color(0xFF444A73),
    brightRed: Color(0xFFFF757F),
    brightGreen: Color(0xFF66BB6A),
    brightYellow: Color(0xFFFFCB6B),
    brightBlue: Color(0xFF82AAFF),
    brightMagenta: Color(0xFFC792EA),
    brightCyan: Color(0xFF89DCEB),
    brightWhite: Color(0xFFFFFFFF),
    searchHitBackground: Color(0xFF4BA3C7),
    searchHitBackgroundCurrent: Color(0xFF4BA3C7),
    searchHitForeground: Color(0xFF0F1117),
  );
}
