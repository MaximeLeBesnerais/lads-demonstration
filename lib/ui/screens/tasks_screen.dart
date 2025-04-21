import 'package:flutter/material.dart';
import 'package:lads/model/node.dart'; // For Task model
import 'package:lads/ui/providers/orchestrator_provider.dart';
import 'package:lads/ui/widgets/add_task_dialog.dart';
import 'package:lads/ui/widgets/task_list_tile.dart';
import 'package:provider/provider.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  void _showAddTaskDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const AddTaskDialog();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrchestratorProvider>();
    final queuedTasks = provider.tasksQueue;

    // Get running tasks by iterating through nodes
    final List<Task> runningTasks = [];
    for (var node in provider.nodes) {
      runningTasks.addAll(node.tasks);
    }

    return Scaffold(
       appBar: AppBar(
         title: const Text('Tasks Management'),
         actions: [
           // Button to process the queue
           if (queuedTasks.isNotEmpty)
              Padding(
                 padding: const EdgeInsets.only(right: 8.0),
                 child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow_outlined),
                    label: Text('Process Queue (${queuedTasks.length})'),
                    onPressed: () {
                       provider.processTasks();
                       ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Task processing triggered.'), duration: Duration(seconds: 2)),
                       );
                    },
                    style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.green.shade700,
                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                 ),
              ),
           // Button to add a new task
           Padding(
             padding: const EdgeInsets.only(right: 16.0),
             child: ElevatedButton.icon(
               icon: const Icon(Icons.add_task_outlined),
               label: const Text('Add Task'),
               onPressed: () => _showAddTaskDialog(context),
               style: ElevatedButton.styleFrom(
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
               ),
             ),
           ),
         ],
         backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
           alpha: 0.9,
         ),
         elevation: 1,
       ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Queued Tasks Section ---
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
              child: Text(
                'Task Queue (${queuedTasks.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              flex: 1, // Adjust flex factor as needed
              child: queuedTasks.isEmpty
                  ? const Center(child: Text('Task queue is empty.'))
                  : ListView.builder(
                      itemCount: queuedTasks.length,
                      itemBuilder: (context, index) {
                        // Use TaskListTile, marking as not running
                        return TaskListTile(task: queuedTasks[index], isRunning: false);
                      },
                    ),
            ),
            const Divider(height: 20, thickness: 1),

            // --- Running Tasks Section ---
             Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
              child: Text(
                'Running Tasks (${runningTasks.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              flex: 2, // Give more space to running tasks potentially
              child: runningTasks.isEmpty
                  ? const Center(child: Text('No tasks currently running.'))
                  : ListView.builder(
                      itemCount: runningTasks.length,
                      itemBuilder: (context, index) {
                         // Use TaskListTile, marking as running
                         return TaskListTile(task: runningTasks[index], isRunning: true);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
