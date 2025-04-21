import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For input formatters
import 'package:lads/model/node.dart'; // Import NodeClass enum and Task
import 'package:lads/ui/providers/orchestrator_provider.dart';
import 'package:provider/provider.dart';

/// A dialog widget for adding a new Task to the queue.
class AddTaskDialog extends StatefulWidget {
  const AddTaskDialog({super.key});

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _durationController = TextEditingController();
  final _coresController = TextEditingController();
  NodeClass _selectedClass = NodeClass.generic; // Default class

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _coresController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text;
      final duration = int.tryParse(_durationController.text);
      final cores = int.tryParse(_coresController.text);

      if (duration != null && duration >= 0 && cores != null && cores > 0) {
        // Use the provider to add the task
        try {
           context.read<OrchestratorProvider>().addTask(name, duration, cores, _selectedClass);
           Navigator.of(context).pop(); // Close dialog on success
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Task "$name" added to queue.'), backgroundColor: Colors.green),
           );
        } catch (e) {
           Navigator.of(context).pop(); // Close dialog
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Error adding task: $e'), backgroundColor: Colors.red),
           );
        }

      } else {
        // Should be caught by validators
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Invalid duration or cores.'), backgroundColor: Colors.orange),
         );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Task to Queue'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Task Name',
                  hintText: 'e.g., DatabaseBackup',
                  icon: Icon(Icons.label_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a task name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _durationController,
                decoration: const InputDecoration(
                  labelText: 'Task Duration (seconds)',
                  hintText: 'e.g., 60',
                  icon: Icon(Icons.timer_outlined),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter duration';
                  }
                  final duration = int.tryParse(value);
                  if (duration == null || duration < 0) {
                    return 'Duration must be 0 or positive';
                  }
                  return null;
                },
              ),
               const SizedBox(height: 16),
              TextFormField(
                controller: _coresController,
                decoration: const InputDecoration(
                  labelText: 'CPU Cores Required',
                  hintText: 'e.g., 2',
                  icon: Icon(Icons.memory_outlined),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter CPU cores';
                  }
                  final cores = int.tryParse(value);
                  if (cores == null || cores <= 0) {
                    return 'Cores must be a positive number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<NodeClass>(
                value: _selectedClass,
                decoration: const InputDecoration(
                  labelText: 'Task Class',
                  icon: Icon(Icons.category_outlined),
                ),
                items: NodeClass.values.map((NodeClass value) {
                  return DropdownMenuItem<NodeClass>(
                    value: value,
                    child: Text(value.name),
                  );
                }).toList(),
                onChanged: (NodeClass? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedClass = newValue;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        ElevatedButton(
          child: const Text('Add Task'),
          onPressed: _submit,
        ),
      ],
    );
  }
}
