import 'package:flutter/material.dart';

import 'activity_heatmap.dart';
import 'todays_habits.dart';

class HabitsPane extends StatelessWidget {
  const HabitsPane({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          ActivityHeatmap(),
          SizedBox(height: 24),
          Divider(),
          SizedBox(height: 8),
          TodaysHabits(),
        ],
      ),
    );
  }
}
