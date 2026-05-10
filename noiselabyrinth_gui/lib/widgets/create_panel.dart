import 'package:flutter/material.dart';

class CreatePanel extends StatelessWidget {
  const CreatePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: 340,
        child: Center(
          child: Text(
            'Create / Advanced',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      ),
    );
  }
}
