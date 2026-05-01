import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _sampleRate = 44100;
  int _bitRate = 192;
  double _cpuPreference = 0.6;
  bool _darkMode = true;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text(
          'Settings',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        _SectionCard(
          title: 'Audio Defaults',
          children: <Widget>[
            DropdownButtonFormField<int>(
              initialValue: _sampleRate,
              items: const <int>[22050, 44100, 48000]
                  .map(
                    (rate) => DropdownMenuItem<int>(
                      value: rate,
                      child: Text('$rate Hz'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) =>
                  setState(() => _sampleRate = value ?? _sampleRate),
              decoration: const InputDecoration(labelText: 'Sample Rate'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              initialValue: _bitRate,
              items: const <int>[96, 128, 192, 256, 320]
                  .map(
                    (rate) => DropdownMenuItem<int>(
                      value: rate,
                      child: Text('$rate kbps'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) =>
                  setState(() => _bitRate = value ?? _bitRate),
              decoration: const InputDecoration(labelText: 'Bitrate'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Performance',
          children: <Widget>[
            Text('CPU vs Quality: ${(_cpuPreference * 100).round()}% quality'),
            Slider(
              value: _cpuPreference,
              onChanged: (value) => setState(() => _cpuPreference = value),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Appearance',
          children: <Widget>[
            SwitchListTile(
              value: _darkMode,
              onChanged: (value) => setState(() => _darkMode = value),
              title: const Text('Dark Mode (Default)'),
              subtitle: const Text(
                'Persistence wiring is ready for future app preferences.',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
