import 'package:flutter/material.dart';
import 'package:noiselabyrinth_ui/features/editor/editor_screen.dart';
import 'package:noiselabyrinth_ui/state/app_scope.dart';
import 'package:noiselabyrinth_ui/state/profile_store.dart';

class WizardScreen extends StatefulWidget {
  const WizardScreen({super.key});

  @override
  State<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends State<WizardScreen> {
  int _currentStep = 0;

  String _goal = 'Sleep';
  String _preference = 'Soft';
  String _complexity = 'Static';
  String _environment = 'None';
  double _lowFrequencyBias = 0.5;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Wizard Generator')),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 4) {
            setState(() => _currentStep += 1);
            return;
          }

          store.createFromWizard(
            WizardDraft(
              goal: _goal,
              preference: _preference,
              complexity: _complexity,
              environment: _environment,
              lowFrequencyBias: _lowFrequencyBias,
            ),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => const EditorScreen()),
          );
        },
        onStepCancel: _currentStep == 0
            ? null
            : () => setState(() => _currentStep -= 1),
        controlsBuilder: (context, details) {
          final isLast = _currentStep == 4;
          return Row(
            children: <Widget>[
              FilledButton(
                onPressed: details.onStepContinue,
                child: Text(isLast ? 'Generate Profile' : 'Continue'),
              ),
              const SizedBox(width: 8),
              if (_currentStep > 0)
                TextButton(
                  onPressed: details.onStepCancel,
                  child: const Text('Back'),
                ),
            ],
          );
        },
        steps: <Step>[
          Step(
            title: const Text('Goal'),
            content: _SegmentedChoice(
              values: const <String>[
                'Sleep',
                'Focus',
                'Relaxation',
                'Anxiety Reduction',
              ],
              selected: _goal,
              onSelected: (value) => setState(() => _goal = value),
            ),
          ),
          Step(
            title: const Text('Sound Preference'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SegmentedChoice(
                  values: const <String>['Soft', 'Dense', 'Dynamic'],
                  selected: _preference,
                  onSelected: (value) => setState(() => _preference = value),
                ),
                const SizedBox(height: 12),
                Text(
                  'Low-frequency bias: ${(_lowFrequencyBias * 100).round()}%',
                ),
                Slider(
                  value: _lowFrequencyBias,
                  onChanged: (value) =>
                      setState(() => _lowFrequencyBias = value),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Complexity'),
            content: _SegmentedChoice(
              values: const <String>[
                'Static',
                'Slight Variation',
                'Dynamic Environment',
              ],
              selected: _complexity,
              onSelected: (value) => setState(() => _complexity = value),
            ),
          ),
          Step(
            title: const Text('Environment Flavor'),
            content: _SegmentedChoice(
              values: const <String>[
                'None',
                'Rain',
                'Wind',
                'Cave',
                'Abstract',
              ],
              selected: _environment,
              onSelected: (value) => setState(() => _environment = value),
            ),
          ),
          Step(
            title: const Text('Generate'),
            content: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Goal: $_goal'),
                    Text('Preference: $_preference'),
                    Text('Complexity: $_complexity'),
                    Text('Environment: $_environment'),
                    Text(
                      'Low-frequency bias: ${(_lowFrequencyBias * 100).round()}%',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select Generate Profile to create and open your result in the shared editor.',
                      style: TextStyle(color: Colors.blueGrey.shade100),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedChoice extends StatelessWidget {
  const _SegmentedChoice({
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values
          .map(
            (value) => ChoiceChip(
              selected: selected == value,
              label: Text(value),
              onSelected: (_) => onSelected(value),
            ),
          )
          .toList(growable: false),
    );
  }
}
