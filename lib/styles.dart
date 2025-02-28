import 'package:flutter/material.dart';

class AppStyles {
  static const TextStyle title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 16,
    color: Colors.black54,
  );

  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black26,
        blurRadius: 5,
        spreadRadius: 1,
        offset: Offset(0, 3),
      ),
    ],
  );
}
