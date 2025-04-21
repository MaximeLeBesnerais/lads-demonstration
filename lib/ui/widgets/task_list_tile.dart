import 'package:flutter/material.dart';
import 'package:lads/model/node.dart'; // For Task model and enums

/// A ListTile widget to display information about a single Task.
/// Handles displaying remaining duration for running tasks via StreamBuilder.
class TaskListTile extends StatelessWidget {
  final Task task;
  final bool isRunning; // Differentiates between queued and running tasks

  const TaskListTile({
    super.key,
    required this.task,
    required this.isRunning,
  });

  // Helper to format duration string (e.g., 01:15 or 55s)
  String _formatDuration(Duration duration) {
    if (duration.isNegative) return "0s"; // Handle edge case
    if (duration.inHours > 0) {
      return duration.toString().split('.').first; // HH:MM:SS
    } else if (duration.inMinutes > 0) {
      String twoDigits(int n) => n.toString().padLeft(2, "0");
      String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
      String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
      return "$twoDigitMinutes:$twoDigitSeconds"; // MM:SS
    } else {
      return "${duration.inSeconds}s"; // SSs
    }
  }

  // Helper to get icon based on task class
  IconData _getClassIcon(NodeClass taskClass) {
    switch (taskClass) {
      case NodeClass.compute: return Icons.computer;
      case NodeClass.database: return Icons.storage;
      case NodeClass.storage: return Icons.save;
      case NodeClass.network: return Icons.lan;
      case NodeClass.backup: return Icons.backup;
      case NodeClass.generic: return Icons.settings_input_component;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final classIcon = _getClassIcon(task.taskClass);

    Widget durationWidget;
    if (isRunning) {
      // Use StreamBuilder to listen for duration updates
      durationWidget = StreamBuilder<Duration>(
        stream: task.remainingDurationStream,
        // Provide initial data to avoid null flicker
        initialData: task.currentRemainingDuration,
        builder: (context, snapshot) {
          final remaining = snapshot.data ?? task.currentRemainingDuration;
          final progress = (task.initialTaskLength.inMilliseconds > 0)
              ? 1.0 - (remaining.inMilliseconds / task.initialTaskLength.inMilliseconds)
              : 1.0; // Avoid division by zero

          return Column(
             mainAxisSize: MainAxisSize.min,
             crossAxisAlignment: CrossAxisAlignment.end,
             children: [
                Text(
                   'Remaining: ${_formatDuration(remaining)}',
                   style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 4),
                SizedBox(
                   width: 80, // Fixed width for the progress bar
                   child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0), // Ensure value is between 0 and 1
                      backgroundColor: theme.colorScheme.surfaceVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                      minHeight: 6,
                   ),
                ),
             ],
          );
        },
      );
    } else {
      // For queued tasks, show initial duration
      durationWidget = Text(
        'Duration: ${_formatDuration(task.initialTaskLength)}',
         style: theme.textTheme.bodySmall,
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: isRunning ? 2 : 1,
      child: ListTile(
        leading: CircleAvatar(
          // Use different background/icon style for running vs queued
          backgroundColor: isRunning ? theme.colorScheme.primaryContainer : theme.colorScheme.secondaryContainer,
          child: Icon(
             isRunning ? Icons.directions_run : classIcon,
             color: isRunning ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSecondaryContainer,
             size: 20,
          ),
        ),
        title: Text(
          task.name + (isRunning ? ' (ID: ${task.id})' : ''), // Show ID only if running
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Class: ${task.taskClass.name} | Cores: ${task.cpuCores}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: durationWidget,
        dense: true, // Make the tile more compact
      ),
    );
  }
}
