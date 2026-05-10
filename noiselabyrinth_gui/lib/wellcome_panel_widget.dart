import 'package:flutter/material.dart';

class WelcomePanelWidget extends StatelessWidget {
  const WelcomePanelWidget({required this.onStart, super.key});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        final horizontalPadding = isWide ? 24.0 : 16.0;
        final titleStyle = isWide
            ? Theme.of(context).textTheme.headlineMedium
            : Theme.of(context).textTheme.headlineSmall;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Card(
              child: Padding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome', style: titleStyle),
                    const SizedBox(height: 10),
                    Text(
                      'This home widget appears on first launch. Select any footer icon to open the main panels.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: onStart,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Open Main Panels'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
