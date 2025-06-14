import 'package:flutter/material.dart';

import '../colorPallete/color_pallete.dart';

// ignore: must_be_immutable
class AuthButton extends StatelessWidget {
  AuthButton({super.key, required this.hintText, required this.onPressed});
  String hintText;
  VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorPallete.color1, colorPallete.color2],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          fixedSize: const Size(320, 55),
          shadowColor: colorPallete.color4,
          backgroundColor: colorPallete.color4,
        ),
        child: Text(
          hintText,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
