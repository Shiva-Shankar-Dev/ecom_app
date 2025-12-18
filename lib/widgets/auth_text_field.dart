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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: TextFormField(
        obscureText: hide,
        decoration: InputDecoration(
          hintText: hintText,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: ColorPallete.color1, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.red, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.red, width: 2),
          ),
        ),
        controller: controller,
        validator: validator ?? (value) {
          if (value == null || value.isEmpty) {
            return '${hintText} is required';
          }
          return null;
        },
      ),
    );
  }
}

class AuthTextFieldForPassword extends StatefulWidget {
  AuthTextFieldForPassword({
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
  State<AuthTextFieldForPassword> createState() => _AuthTextFieldForPasswordState();
}

class _AuthTextFieldForPasswordState extends State<AuthTextFieldForPassword> {
  bool isObscure = true;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: TextFormField(
        obscureText: isObscure,
        decoration: InputDecoration(
          hintText: widget.hintText,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: ColorPallete.color1, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.red, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.red, width: 2),
          ),
          suffixIcon: IconButton(
            onPressed: () {
              setState(() {
                isObscure = !isObscure;
              });
            },
            icon: Icon(
              isObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            ),
          ),
        ),
        controller: widget.controller,
        validator: widget.validator ?? (value) {
          if (value == null || value.isEmpty) {
            return 'Password is required';
          }
          if (value.length < 6) {
            return 'Password must be at least 6 characters';
          }
          return null;
        },
      ),
    );
  }
}