import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

Future initFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: "AIzaSyDmnxlcnPGXUi4Sj1T7cbewRdgG9pB_4-k",
            authDomain: "carerecipients.firebaseapp.com",
            projectId: "carerecipients",
            storageBucket: "carerecipients.firebasestorage.app",
            messagingSenderId: "326485052194",
            appId: "1:326485052194:web:0ace0057b1867ca44f337b",
            measurementId: "G-80F0NVRJWD"));
  } else {
    await Firebase.initializeApp();
  }
}
