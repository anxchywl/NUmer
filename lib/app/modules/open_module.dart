import 'package:flutter/material.dart';

import 'package:numer_app/core/modules/module_descriptor.dart';

Future<void> openModule(BuildContext context, ModuleDescriptor descriptor) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      settings: RouteSettings(name: '/module/${descriptor.id}'),
      builder: descriptor.builder,
    ),
  );
}
