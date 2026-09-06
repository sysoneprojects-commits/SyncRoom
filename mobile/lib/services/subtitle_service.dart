import 'dart:convert';
import 'package:file_picker/file_picker.dart';

class SubtitleCue {
  final Duration start;
  final Duration end;
  final String text;

  const SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
  });
}

class SubtitleTrack {
  final String name;
  final List<SubtitleCue> cues;

  const SubtitleTrack({
    required this.name,
    required this.cues,
  });

  String textAt(Duration position) {
    for (final cue in cues) {
      if (position >= cue.start && position <= cue.end) {
        return cue.text;
      }
    }
    return '';
  }
}

class SubtitleService {
  Future<SubtitleTrack?> pickSrt() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['srt'],
    );

    if (file == null) return null;

    final raw = utf8.decode(
      await file.readAsBytes(),
      allowMalformed: true,
    );

    return SubtitleTrack(
      name: file.name,
      cues: parseSrt(raw),
    );
  }

  List<SubtitleCue> parseSrt(String raw) {
    final normalized = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    if (normalized.isEmpty) return const [];

    final blocks = normalized.split(RegExp(r'\n\s*\n'));
    final cues = <SubtitleCue>[];
    final timing = RegExp(
      r'(\d{2}:\d{2}:\d{2}[,.]\d{3})\s*-->\s*(\d{2}:\d{2}:\d{2}[,.]\d{3})',
    );

    for (final block in blocks) {
      final lines = block
          .split('\n')
          .where((e) => e.trim().isNotEmpty)
          .toList();

      if (lines.length < 2) continue;

      final timingIndex = lines.indexWhere(
        (line) => timing.hasMatch(line),
      );

      if (timingIndex < 0) continue;

      final match = timing.firstMatch(lines[timingIndex]);
      if (match == null) continue;

      final text = lines
          .skip(timingIndex + 1)
          .join('\n')
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .trim();

      if (text.isEmpty) continue;

      cues.add(
        SubtitleCue(
          start: _duration(match.group(1)!),
          end: _duration(match.group(2)!),
          text: text,
        ),
      );
    }

    cues.sort((a, b) => a.start.compareTo(b.start));
    return cues;
  }

  Duration _duration(String input) {
    final value = input.replaceAll(',', '.');
    final parts = value.split(':');
    final sec = parts[2].split('.');

    return Duration(
      hours: int.parse(parts[0]),
      minutes: int.parse(parts[1]),
      seconds: int.parse(sec[0]),
      milliseconds: int.parse(sec[1]),
    );
  }
}
