import 'package:flutter/material.dart';
import 'package:lads/model/node.dart';
import 'package:lads/ui/providers/orchestrator_provider.dart';
import 'package:lads/ui/widgets/task_list_tile.dart'; // To display running tasks

/// Displays details and actions for a selected Node.
class NodeDetailView extends StatelessWidget {
  final Node node;
  final OrchestratorProvider provider; // To call actions

  const NodeDetailView({
    super.key,
    required this.node,
    required this.provider,
  });

  // Helper function to show confirmation dialog
  Future<bool> _showConfirmationDialog(BuildContext context, String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Confirm'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false; // Return false if dialog is dismissed
  }

  // Helper function to show repurpose dialog
  Future<NodeClass?> _showRepurposeDialog(BuildContext context) async {
     return await showDialog<NodeClass>(
        context: context,
        builder: (context) {
           NodeClass selectedClass = node.nodeClass; // Default to current
           return AlertDialog(
              title: Text('Repurpose Node ${node.name}'),
              content: StatefulBuilder( // Use StatefulBuilder for dropdown
                 builder: (context, setState) {
                    return DropdownButton<NodeClass>(
                       value: selectedClass,
                       isExpanded: true,
                       items: NodeClass.values.map((NodeClass cls) {
                          return DropdownMenuItem<NodeClass>(
                             value: cls,
                             child: Text(cls.name),
                          );
                       }).toList(),
                       onChanged: (NodeClass? newValue) {
                          if (newValue != null) {
                             setState(() { // Update state within the dialog
                                selectedClass = newValue;
                             });
                          }
                       },
                    );
                 },
              ),
              actions: [
                 TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                 ),
                 TextButton(
                    child: const Text('Repurpose'),
                    onPressed: () => Navigator.of(context).pop(selectedClass),
                 ),
              ],
           );
        },
     );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // --- Action Buttons ---
    List<Widget> actionButtons = [];

    // State change actions (only show relevant ones)
    if (node.nodeState != NodeState.active) {
       actionButtons.add(ElevatedButton.icon(
          icon: const Icon(Icons.play_circle_outline),
          label: const Text('Activate'),
          onPressed: () => provider.setNodeState(node.id, NodeState.active),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
       ));
    }
    if (node.nodeState == NodeState.active) {
        actionButtons.add(ElevatedButton.icon(
           icon: const Icon(Icons.pause_circle_outline),
           label: const Text('Set Inactive'),
           onPressed: () => provider.setNodeState(node.id, NodeState.inactive),
           style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade700),
        ));
    }
     if (node.nodeState == NodeState.active || node.nodeState == NodeState.inactive) {
        actionButtons.add(ElevatedButton.icon(
           icon: const Icon(Icons.build_circle_outlined),
           label: const Text('Maintenance'),
           onPressed: () => provider.setNodeState(node.id, NodeState.maintenance),
           style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700),
        ));
     }
     if (node.nodeState != NodeState.decommissioned) {
        actionButtons.add(ElevatedButton.icon(
           icon: const Icon(Icons.power_settings_new_outlined),
           label: const Text('Decommission'),
           onPressed: () async {
              bool confirm = await _showConfirmationDialog(
                 context,
                 'Decommission Node?',
                 'Node ${node.name} (${node.id}) will wait for tasks to finish and then be decommissioned.',
              );
              if (confirm) {
                 provider.setNodeState(node.id, NodeState.decommissioned);
              }
           },
           style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
        ));
     }

    // Repurpose Button
    actionButtons.add(ElevatedButton.icon(
       icon: const Icon(Icons.recycling_outlined),
       label: const Text('Repurpose'),
       onPressed: () async {
          NodeClass? newClass = await _showRepurposeDialog(context);
          if (newClass != null && newClass != node.nodeClass) {
             provider.repurposeNode(node.id, newClass);
          }
       },
    ));


    // Remove Button (only if decommissioned)
    if (node.nodeState == NodeState.decommissioned) {
      actionButtons.add(ElevatedButton.icon(
        icon: const Icon(Icons.delete_forever_outlined),
        label: const Text('Remove Node'),
        style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error),
        onPressed: () async {
          bool confirm = await _showConfirmationDialog(
            context,
            'Remove Node?',
            'Permanently remove node ${node.name} (${node.id})? This cannot be undone.',
          );
          if (confirm) {
            provider.removeNode(node.id);
            // Note: After removal, the parent NodesScreen should update
            // and this view will disappear as _selectedNode becomes invalid.
            // Consider explicitly setting _selectedNode to null in NodesScreen
            // after a successful removal if needed.
          }
        },
      ));
    } else {
        // Add a disabled remove button or info text if not decommissioned
         actionButtons.add(const Tooltip(
             message: "Node must be decommissioned before removal",
             child: ElevatedButton(
                 onPressed: null, // Disabled
                 child: Text("Remove Node"),
             ),
         ));
    }


    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView( // Allow scrolling if content overflows
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             // --- Header ---
             Text('Node Details: ${node.name} (${node.id})', style: textTheme.headlineSmall),
             const SizedBox(height: 16),

             // --- Info Section ---
             Card(
                elevation: 2,
                child: Padding(
                   padding: const EdgeInsets.all(16.0),
                   child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         _buildDetailRow('State:', node.nodeState.name, textTheme),
                         _buildDetailRow('Class:', node.nodeClass.name, textTheme),
                         _buildDetailRow('CPU Cores:', '${node.busyCores} busy / ${node.cpuCores} total', textTheme),
                         _buildDetailRow('Available Cores:', '${node.availableCores}', textTheme),
                         const SizedBox(height: 8),
                         Divider(color: theme.dividerColor.withOpacity(0.5)),
                         const SizedBox(height: 8),
                         Text('Running Tasks (${node.tasks.length}):', style: textTheme.titleMedium),
                         const SizedBox(height: 8),
                         node.tasks.isEmpty
                            ? const Text('No tasks currently running.')
                            : ListView.builder( // Display running tasks
                                shrinkWrap: true, // Important inside SingleChildScrollView
                                physics: const NeverScrollableScrollPhysics(), // Disable inner scrolling
                                itemCount: node.tasks.length,
                                itemBuilder: (context, index) {
                                   // Use TaskListTile for consistency, marking it as running
                                   return TaskListTile(task: node.tasks[index], isRunning: true);
                                },
                             ),
                      ],
                   ),
                ),
             ),
             const SizedBox(height: 24),

             // --- Actions Section ---
             Text('Actions:', style: textTheme.titleLarge),
             const SizedBox(height: 12),
             Wrap( // Arrange buttons nicely
               spacing: 12.0, // Horizontal space between buttons
               runSpacing: 12.0, // Vertical space between lines
               children: actionButtons,
             ),
           ],
         ),
      ),
    );
  }

  // Helper widget for consistent detail row display
  Widget _buildDetailRow(String label, String value, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
