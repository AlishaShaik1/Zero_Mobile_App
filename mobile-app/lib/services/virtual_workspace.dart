import 'dart:io';
import 'package:path/path.dart' as p;

class PathTraversalException implements Exception {
  final String path;
  PathTraversalException(this.path);

  @override
  String toString() =>
      'PathTraversalException: Attempted to escape workspace root with path "$path"';
}

class VirtualWorkspace {
  final Directory root;

  VirtualWorkspace(this.root);

  Future<void> init() async {
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
  }

  File resolve(String relativePath) {
    // Prevent absolute paths from escaping
    if (p.isAbsolute(relativePath)) {
      throw PathTraversalException(relativePath);
    }

    final target = File(p.normalize(p.join(root.path, relativePath)));

    // Ensure the resolved path is within the root directory
    if (!p.isWithin(root.path, target.path)) {
      throw PathTraversalException(relativePath);
    }

    return target;
  }

  Future<void> writeFile(String path, String content) async {
    final f = resolve(path);
    await f.parent.create(recursive: true);
    await f.writeAsString(content);
  }

  Future<String> readFile(String path) async {
    final f = resolve(path);
    if (!await f.exists()) {
      throw FileSystemException('File not found', path);
    }
    return await f.readAsString();
  }

  Future<List<String>> listFiles() async {
    if (!await root.exists()) {
      return [];
    }

    final files = <String>[];
    await for (final entity in root.list(recursive: true)) {
      if (entity is File) {
        files.add(p.relative(entity.path, from: root.path));
      }
    }
    return files;
  }
}
