import 'package:flutter/material.dart';
import 'package:lads/model/node.dart'; // Import Node model
import 'package:lads/ui/providers/orchestrator_provider.dart';
import 'package:lads/ui/widgets/add_node_dialog.dart';
import 'package:lads/ui/widgets/node_list_tile.dart';
import 'package:lads/ui/screens/node_detail_view.dart'; // Import detail view
import 'package:provider/provider.dart';

class NodesScreen extends StatefulWidget {
  const NodesScreen({super.key});

  @override
  State<NodesScreen> createState() => _NodesScreenState();
}

class _NodesScreenState extends State<NodesScreen> {
  Node? _selectedNode; // Track the selected node for the detail view

  void _selectNode(Node node) {
    setState(() {
      _selectedNode = node;
    });
  }

  void _showAddNodeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Dialog is defined in add_node_dialog.dart
        return const AddNodeDialog();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the provider for changes in the node list
    final provider = context.watch<OrchestratorProvider>();
    final nodes = provider.nodes;
    final screenWidth = MediaQuery.of(context).size.width;
    // Determine if we have enough space for a two-pane layout
    final bool showTwoPanes = screenWidth > 800; // Adjust breakpoint as needed

    Widget nodeListWidget = ListView.builder(
      itemCount: nodes.length,
      itemBuilder: (context, index) {
        final node = nodes[index];
        return NodeListTile(
          node: node,
          isSelected: _selectedNode?.id == node.id,
          onTap: () => _selectNode(node),
        );
      },
    );

    Widget detailWidget;
    if (_selectedNode != null) {
       // Pass the selected node and the provider to the detail view
       detailWidget = NodeDetailView(node: _selectedNode!, provider: provider);
    } else {
       detailWidget = Center(
          child: Text(
             'Select a node to see details',
             style: Theme.of(context).textTheme.titleMedium,
          )
       );
    }


    return Scaffold(
      // Use a AppBar for the title and add node button
      appBar: AppBar(
         title: const Text('Nodes Management'),
         actions: [
           Padding(
             padding: const EdgeInsets.only(right: 16.0),
             child: ElevatedButton.icon(
               icon: const Icon(Icons.add_circle_outline),
               label: const Text('Add Node'),
               onPressed: _showAddNodeDialog,
               style: ElevatedButton.styleFrom(
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
               ),
             ),
           ),
         ],
         backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
         elevation: 1,
      ),
      body: showTwoPanes
          ? Row( // Two-pane layout for wider screens
              children: [
                SizedBox(
                  width: 350, // Fixed width for the list pane
                  child: nodeListWidget,
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                   child: detailWidget,
                ),
              ],
            )
          : nodeListWidget, // Single pane layout for narrower screens (details would navigate)
            // Note: For single pane, tapping a node should navigate to a separate detail screen.
            // This implementation currently only shows detail view in two-pane mode.
            // A full implementation would use Navigator.push for the single-pane case.
    );
  }
}
