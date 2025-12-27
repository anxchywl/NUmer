import 'package:flutter/material.dart';

@immutable
class ProfileAvatarOption {
  const ProfileAvatarOption({
    required this.icon,
    required this.background,
  });

  final IconData icon;
  final Color background;
}

const List<ProfileAvatarOption> profileAvatarOptions = [
  ProfileAvatarOption(icon: Icons.school_rounded, background: Color(0xFFEF4444)),
  ProfileAvatarOption(icon: Icons.person_rounded, background: Color(0xFF6366F1)),
  ProfileAvatarOption(icon: Icons.auto_graph_rounded, background: Color(0xFF22C55E)),
  ProfileAvatarOption(icon: Icons.science_rounded, background: Color(0xFFF97316)),
  ProfileAvatarOption(icon: Icons.brush_rounded, background: Color(0xFFEC4899)),
  ProfileAvatarOption(icon: Icons.rocket_launch_rounded, background: Color(0xFF0EA5E9)),
  ProfileAvatarOption(icon: Icons.psychology_rounded, background: Color(0xFF8B5CF6)),
];

ProfileAvatarOption? profileAvatarOptionFor(int? index) {
  if (index == null) return null;
  if (index < 0 || index >= profileAvatarOptions.length) return null;
  return profileAvatarOptions[index];
}

Color profileAvatarForeground(ProfileAvatarOption option) {
  final brightness = ThemeData.estimateBrightnessForColor(option.background);
  return brightness == Brightness.dark ? Colors.white : Colors.black87;
}
