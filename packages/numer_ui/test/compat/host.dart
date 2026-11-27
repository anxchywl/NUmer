import 'package:flutter/material.dart';
import 'package:numer_ui/compat.dart';

const seed = Color.fromARGB(255, 68, 138, 255);

Widget host(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: NumerTheme.build(seed: seed, brightness: brightness),
    home: Scaffold(body: Center(child: child)),
  );
}
