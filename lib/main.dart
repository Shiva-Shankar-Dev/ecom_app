import 'package:ecom_app/screens/otp_page.dart';
import 'package:ecom_app/secrets/app_secrets.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_page.dart';
import 'screens/signup_page.dart';
import 'screens/home_page.dart';
import 'screens/mobile_login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ignore: unused_local_variable
  final supabase = await Supabase.initialize(
    url: AppSecrets.supabaseUrl,
    anonKey: AppSecrets.supabaseApi,
  );
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
        '/': (context) => LoginPage(),
        '/signup': (context) => SignUpPage(),
        '/home': (context) => HomePage(),
        '/mobile': (context) => MobileLoginPage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/otp') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => OtpPage(phone: args['phone']),
          );
        }
        return null;
      },
    );
  }
}
