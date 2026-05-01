import 'package:flutter/material.dart';
import 'package:noiselabyrinth_ui/state/app_scope.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _isPlaying = false;
  double _volume = 0.8;
  bool _showAdvanced = false;
  double _eqTilt = 0.0;
  double _intensity = 0.7;
  double _stereoWidth = 0.6;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final profile = store.activeProfile;

    if (profile == null) {
      return const Center(child: Text('No active profile'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          profile.config.metadata.name,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: profile.config.metadata.tags
              .map((tag) => Chip(label: Text(tag)))
              .toList(growable: false),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: FutureBuilder<List<double>>(
              future: store.buildWaveformPreview(profile),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 170,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final values = snapshot.data ?? const <double>[];
                return SizedBox(
                  height: 170,
                  child: CustomPaint(painter: _WaveformPainter(values)),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            FilledButton.icon(
              onPressed: () => setState(() => _isPlaying = !_isPlaying),
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              label: Text(_isPlaying ? 'Pause' : 'Play'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Slider(
                value: _volume,
                onChanged: (value) => setState(() => _volume = value),
              ),
            ),
            Text('${(_volume * 100).round()}%'),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
          icon: const Icon(Icons.tune),
          label: Text(_showAdvanced ? 'Hide Advanced' : 'Show Advanced'),
        ),
        if (_showAdvanced)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Master EQ Tilt: ${_eqTilt.toStringAsFixed(2)}'),
                  Slider(
                    value: _eqTilt,
                    min: -1,
                    max: 1,
                    onChanged: (value) => setState(() => _eqTilt = value),
                  ),
                  Text('Intensity: ${_intensity.toStringAsFixed(2)}'),
                  Slider(
                    value: _intensity,
                    min: 0,
                    max: 1,
                    onChanged: (value) => setState(() => _intensity = value),
                  ),
                  Text('Stereo Width: ${_stereoWidth.toStringAsFixed(2)}'),
                  Slider(
                    value: _stereoWidth,
                    min: 0,
                    max: 1,
                    onChanged: (value) => setState(() => _stereoWidth = value),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF111827);
    final guide = Paint()
      ..color = const Color(0xFF2B3C5C)
      ..strokeWidth = 1;
    final wave = Paint()
      ..color = const Color(0xFF78BFFF)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      bg,
    );

    final centerY = size.height * 0.5;
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), guide);

    if (values.isEmpty) {
      return;
    }

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = centerY - (values[i] * size.height * 0.45);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    for (var i = values.length - 1; i >= 0; i--) {
      final x = (i / (values.length - 1)) * size.width;
      final y = centerY + (values[i] * size.height * 0.45);
      path.lineTo(x, y);
    }
    path.close();

    canvas.drawPath(
      path,
      wave
        ..style = PaintingStyle.fill
        ..color = const Color(0x553A8BE0),
    );
    canvas.drawPath(
      path,
      wave
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF78BFFF),
    );
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}
