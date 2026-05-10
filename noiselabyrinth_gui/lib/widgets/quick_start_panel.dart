import 'package:flutter/material.dart';

class QuickStartPanel extends StatelessWidget {
  const QuickStartPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: 340,
        child: Center(
          child: Text('Quick start', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
        ),
      ),
    );
  }
}
