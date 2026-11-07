// Prints a Markdown table from the files tool/benchmark.sh writes.
//
//   dart run tool/summarize_benchmarks.dart [dir ...]   (default: benchmark_output)
//
// Each directory holds one run of each radius. Start-up samples are pooled
// across directories; memory and network columns show the per-run range.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

void main(List<String> args) {
  final dirs = args.isEmpty ? ['benchmark_output'] : args;
  final byRadius = <int, _Radius>{};

  for (final dir in dirs) {
    for (final file in Directory(dir).listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      final match = RegExp(r'^radius(\d+)_').firstMatch(name);
      if (match == null) continue;
      final r = byRadius.putIfAbsent(int.parse(match.group(1)!), _Radius.new);
      if (name.endsWith('.json')) {
        final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        for (final s in (data['startups'] as List).cast<Map<String, dynamic>>()) {
          r.startups.add(s['ms'] as int);
          if (s['preloaded'] as bool) r.preloadedCount++;
        }
        r.firstVideo.add(data['first_video_ms'] as int);
        r.maxPlayers = math.max(r.maxPlayers, data['max_live_players'] as int);
        final init = data['initialize'] as Map<String, dynamic>;
        r.initP50.add(init['p50_ms'] as int);
        r.initFailures += data['init_failures'] as int;
        final received = data['received_mb'] as num?;
        if (received != null) r.receivedMb.add(received.toDouble());
      } else if (name.endsWith('_mem.txt')) {
        final rows = file
            .readAsLinesSync()
            .skip(1)
            .map((l) => l.split(' ').map(int.tryParse).toList())
            .where((v) => v.length == 5 && v.every((x) => x != null))
            .map((v) => v.cast<int>())
            .toList();
        if (rows.isEmpty) continue;
        r.appMb.add(rows.map((v) => v[1]).reduce(math.max) / 1024);
        r.graphicsMb.add(rows.map((v) => v[2]).reduce(math.max) / 1024);
        r.codecMb.add(rows.map((v) => v[3] + v[4]).reduce(math.max) / 1024);
        r.totalMb.add(rows.map((v) => v[1] + v[3] + v[4]).reduce(math.max) / 1024);
      }
    }
  }

  stdout.writeln(
    '| Radius | Players (max) | Swipes | Ready when shown | Start-up p50 | p90 | max '
    '| Peak PSS: app | of which graphics | codec processes | app + codecs | Received |',
  );
  stdout.writeln('|---|---|---|---|---|---|---|---|---|---|---|---|');
  for (final radius in byRadius.keys.toList()..sort()) {
    final r = byRadius[radius]!;
    final s = r.startups..sort();
    int pct(double p) => s.isEmpty ? 0 : s[(p * (s.length - 1)).round()];
    stdout.writeln(
      '| $radius | ${r.maxPlayers} | ${s.length} '
      '| ${r.preloadedCount} of ${s.length} '
      '| ${pct(0.5)} ms | ${pct(0.9)} ms | ${s.isEmpty ? 0 : s.last} ms '
      '| ${_range(r.appMb)} MB | ${_range(r.graphicsMb)} MB | ${_range(r.codecMb)} MB '
      '| ${_range(r.totalMb)} MB | ${_range(r.receivedMb)} MB |',
    );
  }
  stdout.writeln();
  for (final radius in byRadius.keys.toList()..sort()) {
    final r = byRadius[radius]!;
    stdout.writeln(
      'radius $radius: first video ${r.firstVideo.join(', ')} ms; '
      'initialize p50 per run ${r.initP50.join(', ')} ms; init failures ${r.initFailures}',
    );
  }
}

String _range(List<double> values) {
  if (values.isEmpty) return '-';
  final lo = values.reduce(math.min).round();
  final hi = values.reduce(math.max).round();
  return lo == hi ? '$lo' : '$lo–$hi';
}

class _Radius {
  final List<int> startups = [];
  int preloadedCount = 0;
  final List<int> firstVideo = [];
  int maxPlayers = 0;
  final List<int> initP50 = [];
  int initFailures = 0;
  final List<double> appMb = [];
  final List<double> graphicsMb = [];
  final List<double> codecMb = [];
  final List<double> totalMb = [];
  final List<double> receivedMb = [];
}
