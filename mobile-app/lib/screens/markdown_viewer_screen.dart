import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class MarkdownViewerScreen extends StatelessWidget {
  final String filePath;

  const MarkdownViewerScreen({super.key, required this.filePath});

  @override
  Widget build(BuildContext context) {
    String content = 'Loading...';
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        content = file.readAsStringSync();
      } else {
        content = '# Error\nFile not found: $filePath';
      }
    } catch (e) {
      content = '# Error\nCould not read file: $e';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deep Search Report'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Markdown(data: content, selectable: true),
    );
  }
}
