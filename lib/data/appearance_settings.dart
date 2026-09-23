import 'package:flutter/material.dart';

@immutable
class AppearanceSettings {
  const AppearanceSettings({
    this.themeMode = ThemeMode.system,
    this.useSystemFont = true,
    this.popupOpacity = 1,
  });
  final ThemeMode themeMode;
  final bool useSystemFont;
  final double popupOpacity;

  AppearanceSettings copyWith({
    ThemeMode? themeMode,
    bool? useSystemFont,
    double? popupOpacity,
  }) => AppearanceSettings(
    themeMode: themeMode ?? this.themeMode,
    useSystemFont: useSystemFont ?? this.useSystemFont,
    popupOpacity: popupOpacity ?? this.popupOpacity,
  );

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode.name,
    'useSystemFont': useSystemFont,
    'popupOpacity': popupOpacity,
  };
  factory AppearanceSettings.fromJson(Map<String, dynamic> json) =>
      AppearanceSettings(
        popupOpacity:
            json['popupOpacity'] is num &&
                (json['popupOpacity'] as num).isFinite
            ? (json['popupOpacity'] as num).toDouble().clamp(0.0, 1.0)
            : 1,
        themeMode: ThemeMode.values.firstWhere(
          (v) => v.name == json['themeMode'],
          orElse: () => ThemeMode.system,
        ),
        useSystemFont: json['useSystemFont'] is bool
            ? json['useSystemFont'] as bool
            : true,
      );

  @override
  bool operator ==(Object other) =>
      other is AppearanceSettings &&
      other.themeMode == themeMode &&
      other.useSystemFont == useSystemFont &&
      other.popupOpacity == popupOpacity;
  @override
  int get hashCode => Object.hash(themeMode, useSystemFont, popupOpacity);
}
