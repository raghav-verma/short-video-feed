import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// Host side of `flutter drive`: saves what the benchmark reports to
/// benchmark_output/ (gitignored). Summaries are copied into docs/.
Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) return;
    final dir = Directory('benchmark_output')..createSync(recursive: true);
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File('${dir.path}/radius${data['preload_radius']}_$stamp.json');
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
    stdout.writeln('Saved ${file.path}');
  },
);
