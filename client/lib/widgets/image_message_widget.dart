import 'package:flutter/material.dart';
import 'dart:typed_data';

class ImageMessageWidget extends StatelessWidget {
  final Uint8List imageData;
  final bool isMe;

  const ImageMessageWidget({
    super.key,
    required this.imageData,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Colors.black87,
            child: InteractiveViewer(
              child: Image.memory(imageData, fit: BoxFit.contain),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isMe ? Colors.green : Colors.grey[800],
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            imageData,
            width: 200,
            height: 150,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
