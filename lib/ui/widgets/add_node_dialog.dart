import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For input formatters
import 'package:lads/model/node.dart'; // Import NodeClass enum
import 'package:lads/ui/providers/orchestrator_provider.dart';
import 'package:provider/provider.dart';

/// A dialog widget for adding a new Node.
class AddNodeDialog extends StatefulWidget {
  const AddNodeDialog({super.key});

  @override
  State<AddNodeDialog> createState() => _AddNodeDialogState();
}

class _AddNodeDialogState extends State<AddNodeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _coresController = TextEditingController();
  NodeClass _selectedClass = NodeClass.generic; // Default class

  @override
  void dispose() {
    _nameController.dispose();
    _coresController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text;
      final cores = int.tryParse(_coresController.text);

      if (cores != null && cores > 0) {
        // Use the provider to add the node
        try {
          context.read<OrchestratorProvider>().addNode(name, cores, _selectedClass);
          Navigator.of(context).pop(); // Close dialog on success
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Node "$name" added successfully.'), backgroundColor: Colors.green),
          );
        } catch (e) {
           Navigator.of(context).pop(); // Close dialog
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Error adding node: $e'), backgroundColor: Colors.red),
           );
        }
      } else {
        // Should be caught by validator, but as a fallback
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Invalid number of cores.'), backgroundColor: Colors.orange),
         );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Node'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView( // Prevent overflow if keyboard appears
          child: Column(
            mainAxisSize: MainAxisSize.min, // Take minimum space
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Node Name',
                  hintText: 'e.g., WebServer-01',
                  icon: Icon(Icons.label_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a node name';
                  }
                  // Optional: Add check for existing names via provider if needed
                  // final existing = context.read<OrchestratorProvider>().findNodeByName(value.trim());
                  // if (existing != null) return 'Node name already exists';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _coresController,
                decoration: const InputDecoration(
                  labelText: 'CPU Cores',
                  hintText: 'e.g., 4',
                  icon: Icon(Icons.memory_outlined),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly // Allow only numbers
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
                  labelText: 'Node Class',
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
          onPressed: _submit,
          child: const Text('Add Node'),
        ),
      ],
    );
  }
}
