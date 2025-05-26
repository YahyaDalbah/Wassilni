import 'package:flutter/material.dart';

Widget buildHeader() {
  return Column(
    children: const [
      SizedBox(height: 100),
      Text(
        "Enter Your Phone Number",
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      SizedBox(height: 30),
    ],
  );
}