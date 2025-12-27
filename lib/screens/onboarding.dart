import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _form = GlobalKey<FormState>();
  final _major = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Major')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _major,
                decoration: const InputDecoration(
                  labelText: 'Major',
                  hintText: 'Type your major',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  if (!_form.currentState!.validate()) return;
                  await context.read<AppState>().setMajor(_major.text.trim());
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/shell');
                  }
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
