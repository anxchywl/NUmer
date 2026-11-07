import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

enum FirebaseEnv { production, staging }

const String appEnv = String.fromEnvironment(
  'APP_ENV',
  defaultValue: 'production',
);

FirebaseEnv firebaseEnvFrom(String value) => switch (value) {
  'production' => FirebaseEnv.production,
  'staging' => FirebaseEnv.staging,
  _ => throw StateError('unknown APP_ENV "$value", use production or staging'),
};

const String _androidApiKey = String.fromEnvironment(
  'FIREBASE_ANDROID_API_KEY',
);
const String _iosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
const String _stagingProjectId = String.fromEnvironment(
  'STAGING_FIREBASE_PROJECT_ID',
);
const String _stagingSenderId = String.fromEnvironment(
  'STAGING_FIREBASE_SENDER_ID',
);
const String _stagingStorageBucket = String.fromEnvironment(
  'STAGING_FIREBASE_STORAGE_BUCKET',
);
const String _stagingAndroidAppId = String.fromEnvironment(
  'STAGING_FIREBASE_ANDROID_APP_ID',
);
const String _stagingAndroidApiKey = String.fromEnvironment(
  'STAGING_FIREBASE_ANDROID_API_KEY',
);
const String _stagingIosAppId = String.fromEnvironment(
  'STAGING_FIREBASE_IOS_APP_ID',
);
const String _stagingIosApiKey = String.fromEnvironment(
  'STAGING_FIREBASE_IOS_API_KEY',
);
const String _stagingIosBundleId = String.fromEnvironment(
  'STAGING_FIREBASE_IOS_BUNDLE_ID',
);

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    final staging = firebaseEnvFrom(appEnv) == FirebaseEnv.staging;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return staging ? stagingAndroid : android;
      case TargetPlatform.iOS:
        return staging ? stagingIos : ios;
      case TargetPlatform.macOS:
        return staging ? stagingIos : ios;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: _androidApiKey,
    appId: '1:814724149327:android:7289f30938dca04c113a3a',
    messagingSenderId: '814724149327',
    projectId: 'numer-60744',
    storageBucket: 'numer-60744.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: _iosApiKey,
    appId: '1:814724149327:ios:537337e5516824d3113a3a',
    messagingSenderId: '814724149327',
    projectId: 'numer-60744',
    storageBucket: 'numer-60744.firebasestorage.app',
    iosBundleId: 'com.example.numerApp',
  );

  static FirebaseOptions get stagingAndroid => FirebaseOptions(
    apiKey: _required(
      'STAGING_FIREBASE_ANDROID_API_KEY',
      _stagingAndroidApiKey,
    ),
    appId: _required('STAGING_FIREBASE_ANDROID_APP_ID', _stagingAndroidAppId),
    messagingSenderId: _required(
      'STAGING_FIREBASE_SENDER_ID',
      _stagingSenderId,
    ),
    projectId: _required('STAGING_FIREBASE_PROJECT_ID', _stagingProjectId),
    storageBucket: _required(
      'STAGING_FIREBASE_STORAGE_BUCKET',
      _stagingStorageBucket,
    ),
  );

  static FirebaseOptions get stagingIos => FirebaseOptions(
    apiKey: _required('STAGING_FIREBASE_IOS_API_KEY', _stagingIosApiKey),
    appId: _required('STAGING_FIREBASE_IOS_APP_ID', _stagingIosAppId),
    messagingSenderId: _required(
      'STAGING_FIREBASE_SENDER_ID',
      _stagingSenderId,
    ),
    projectId: _required('STAGING_FIREBASE_PROJECT_ID', _stagingProjectId),
    storageBucket: _required(
      'STAGING_FIREBASE_STORAGE_BUCKET',
      _stagingStorageBucket,
    ),
    iosBundleId: _required(
      'STAGING_FIREBASE_IOS_BUNDLE_ID',
      _stagingIosBundleId,
    ),
  );

  static String _required(String name, String value) {
    if (value.isEmpty) {
      throw StateError('$name is empty, pass it with --dart-define');
    }
    return value;
  }
}
