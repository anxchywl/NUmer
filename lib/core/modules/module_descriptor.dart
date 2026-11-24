import 'package:flutter/widgets.dart';
import 'package:numer_ui/numer_ui.dart';

import 'package:numer_app/l10n/app_localizations.dart';

enum ModuleSection { study, campus }

@immutable
class ModuleDescriptor {
  const ModuleDescriptor({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.section,
    required this.flagId,
    required this.builder,
  });

  final String id;
  final String Function(AppLocalizations l10n) title;
  final String Function(AppLocalizations l10n) subtitle;
  final IconData icon;
  final ModuleSection section;
  final String flagId;
  final NumerModuleScaffold Function(BuildContext context) builder;
}
