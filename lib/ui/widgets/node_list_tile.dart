import 'package:flutter/material.dart';
import 'package:lads/model/node.dart'; // Import Node model

/// A ListTile widget to display information about a single Node.
class NodeListTile extends StatelessWidget {
  final Node node;
  final bool isSelected;
  final VoidCallback onTap;

  const NodeListTile({
    super.key,
    required this.node,
    required this.isSelected,
    required this.onTap,
  });

  // Helper to get color based on node state
  Color _getStateColor(NodeState state, BuildContext context) {
    switch (state) {
      case NodeState.active:
        return Colors.green.shade400;
      case NodeState.inactive:
        return Colors.grey.shade600;
      case NodeState.maintenance:
        return Colors.orange.shade400;
      case NodeState.decommissioned:
        return Colors.red.shade400;
    }
  }

    // Helper to get icon based on node class
    IconData _getClassIcon(NodeClass nodeClass) {
      switch (nodeClass) {
        case NodeClass.compute: return Icons.computer;
        case NodeClass.database: return Icons.storage; // Using storage icon for DB
        case NodeClass.storage: return Icons.save;
        case NodeClass.network: return Icons.lan;
        case NodeClass.backup: return Icons.backup;
        case NodeClass.generic: return Icons.settings_input_component;
      }
    }

  @override
  Widget build(BuildContext context) {
    final stateColor = _getStateColor(node.nodeState, context);
    final classIcon = _getClassIcon(node.nodeClass);
    final theme = Theme.of(context);

    return ListTile(
      tileColor: isSelected ? theme.colorScheme.primary.withOpacity(0.2) : null,
      leading: CircleAvatar(
        backgroundColor: stateColor.withOpacity(0.2),
        child: Icon(classIcon, color: theme.colorScheme.onSurface),
      ),
      title: Text(
        '${node.name} (${node.id})',
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        'State: ${node.nodeState.name} | Class: ${node.nodeClass.name} | CPU: ${node.busyCores}/${node.cpuCores}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
           if (node.tasks.isNotEmpty)
             Chip(
                avatar: Icon(Icons.memory, size: 16, color: theme.colorScheme.onSecondaryContainer),
                label: Text('${node.tasks.length} Tasks'),
                backgroundColor: theme.colorScheme.secondaryContainer.withOpacity(0.7),
                labelStyle: TextStyle(color: theme.colorScheme.onSecondaryContainer, fontSize: 10),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
             ),
           const SizedBox(width: 8),
           Icon(Icons.circle, color: stateColor, size: 12), // State indicator dot
        ],
      ),
      onTap: onTap, // Trigger selection callback
    );
  }
}
