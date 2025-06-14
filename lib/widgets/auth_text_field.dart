import 'package:ecom_app/colorPallete/color_pallete.dart';
import 'package:flutter/material.dart';

// ignore: must_be_immutable
class AuthTextField extends StatelessWidget {
  AuthTextField({
    super.key,
    required this.hintText,
    required this.controller,
    this.hide = false,
    this.validator,
  });
  final String? Function(String?)? validator;
  String hintText;
  bool hide;
  TextEditingController controller;
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: TextFormField(
          obscureText: hide,
          decoration: InputDecoration(
            hintText: hintText,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(width: 3),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colorPallete.color1, width: 3),
            ),
          ),
          controller: controller,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'please enter your mobile number';
            }
            return null;
          },
        ),
      ),
    );
  }
}
