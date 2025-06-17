import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:ecom_app/animated_splash_screen_widget.dart';
import 'package:ecom_app/screens/otp_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screens/login_page.dart';
import 'screens/signup_page.dart';
import 'screens/home_page.dart';
import 'screens/mobile_login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Check if any Firebase app is already initialized
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: "AIzaSyBb_1jJnMQy2qAebBpDnojunskioxt7omg",
          appId: "1:720739834245:android:258b055c58eb166c02ccec",
          messagingSenderId: "720739834245",
          projectId: "ecom-app-af213",
        ),
      );
    }
  } catch (e) {
    print("🔥 Firebase already initialized or failed: $e");
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark),
      initialRoute: '/',
      routes: {
        '/': (context) => AnimatedSplashScreenWidget(),
        '/login': (context) => LoginPage(),
        '/signup': (context) => SignUpPage(),
        '/home': (context) => HomePage(),
        '/mobile': (context) => MobileLoginPage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/otp') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => OtpPage(
              phone: args['phone'],
              verificationId: args['verificationId'],
            ),
          );
        }
        return null;
      },
    );
  }
}
