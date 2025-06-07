import 'package:flutter/material.dart';

Widget collapsedPanel(String text) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.black,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
      ],
    ),
    child: Center(
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}
