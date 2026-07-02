import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:numer_app/app_state.dart';
import 'package:numer_app/services/auth_service.dart';
import 'package:numer_app/widgets/profile_form.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class ProfileSetupScreen extends StatelessWidget {
  const ProfileSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    
    
    if (auth.currentUser == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            color: colorScheme.surfaceContainerHigh,
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Complete Your Profile',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ProfileForm(
                      initialName: (auth.profile?['profileName'] as String?) ??
                          (auth.profile?['displayName'] as String?) ??
                          (auth.currentUser?.displayName ?? ''),
                      initialContact: auth.profile?['profileContact'] as String?,
                      autofocusName: true,
                      primaryButtonLabel: 'Complete Setup',
                      onSubmit: (data) async {
                        final userId = auth.currentUser?.uid;
                        if (userId == null) return;
                        
                        
                        final appState = context.read<AppState>();
                        await appState.saveProfile(
                          name: data.name,
                          goal: data.goal,
                          majorText: data.major,
                          contact: data.contact,
                          avatarIndex: data.avatarIndex,
                          avatarColorValue: data.avatarColorValue,
                          uid: userId,
                        );

                        
                        final cloudData = {
                          'displayName': data.name,
                          'profileName': data.name,
                          'major': data.major,
                          'profileGoal': data.goal,
                          'profileContact': data.contact,
                          'profileComplete': true,
                          'onboardingCompleted': true,
                          'isNewUser': false,
                          'updatedAt': FieldValue.serverTimestamp(),
                        };
                        
                        
                        if (data.avatarIndex != null) {
                          cloudData['profileAvatarIndex'] = data.avatarIndex;
                          cloudData['avatarIndex'] = data.avatarIndex;
                          cloudData['profileAvatarColorValue'] = data.avatarColorValue;
                          // Ensure legacy image fields are cleared
                          cloudData['profileAvatarImageBase64'] = FieldValue.delete();
                          cloudData['avatarImageBase64'] = FieldValue.delete();
                        }

                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId)
                            .set(cloudData, SetOptions(merge: true));
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
