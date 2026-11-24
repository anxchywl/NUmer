import 'package:numer_app/core/config/app_config_service.dart';
import 'package:numer_app/core/modules/module_descriptor.dart';

// order is the row order of the study and campus roots
const List<ModuleDescriptor> moduleRegistry = [];

List<ModuleDescriptor> visibleModules(
  ModuleSection section,
  AppConfigService config,
  String uid, {
  List<ModuleDescriptor> registry = moduleRegistry,
}) => [
  for (final descriptor in registry)
    if (descriptor.section == section &&
        config.isModuleVisible(descriptor.flagId, uid))
      descriptor,
];
