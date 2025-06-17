import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:ecom_app/colorPallete/color_pallete.dart';
import 'package:ecom_app/screens/login_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:ecom_app/main.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
class AnimatedSplashScreenWidget extends StatelessWidget{
  const AnimatedSplashScreenWidget({super.key});
  @override
  Widget build(BuildContext context){
    return Container(
      height: double.infinity,
      //decoration: BoxDecoration(image: DecorationImage(image: AssetImage('./assets/background.jpg',), fit: BoxFit.cover)),
      child: AnimatedSplashScreen(
        splash: Center(
          child: Lottie.asset('assets/Animation_123.json'),
        ),
        nextScreen: LoginPage(),
        splashIconSize: 200,
        backgroundColor: Color(121116),
        duration: 4000,
      ),
    );
  }

}
