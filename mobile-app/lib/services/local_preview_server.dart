import 'dart:io';
// shelf.dart not needed directly — shelf_io and shelf_static are sufficient
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

class LocalPreviewServer {
  HttpServer? _server;
  int? port;

  Future<Uri> start(String projectDir) async {
    final handler = createStaticHandler(
      projectDir,
      defaultDocument: 'index.html',
    );

    // Bind to ephemeral port on loopback
    _server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, 0);
    port = _server!.port;

    return Uri.parse('http://localhost:$port/');
  }

  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      port = null;
    }
  }
}
