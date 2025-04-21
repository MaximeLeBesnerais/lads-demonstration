import 'package:flutter/material.dart';
import 'package:lads/ui/screens/ai_screen.dart';
import 'package:lads/ui/screens/logs_screen.dart';
import 'package:lads/ui/screens/nodes_screen.dart';
import 'package:lads/ui/screens/tasks_screen.dart';
// Placeholder screen widgets (to be created)
// import 'nodes_screen.dart';
// import 'tasks_screen.dart';
// import 'logs_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0; // To track the selected view

  // Placeholder widgets for the different views
  static final List<Widget> _widgetOptions = <Widget>[
    NodesScreen(),
    TasksScreen(),
    LogsScreen(),
    AiScreen()
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use LayoutBuilder to potentially adapt layout based on width
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine if we should use a rail (wider screens) or bottom nav (narrower)
        // For now, we'll always use the NavigationRail as requested for wide screens.

        return Scaffold(
          body: Row(
            children: <Widget>[
              // --- Navigation Rail ---
              NavigationRail(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onItemTapped,
                labelType:
                    NavigationRailLabelType
                        .selected, // Show labels only when selected
                // Use themed background color
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.9,
                ),
                indicatorColor: Theme.of(context).colorScheme.primaryContainer,
                elevation: 4, // Add some shadow
                leading: const Padding(
                  // Optional: Add a logo or title at the top
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Icon(Icons.hub_outlined, size: 30), // Example Icon
                ),
                destinations: const <NavigationRailDestination>[
                  NavigationRailDestination(
                    icon: Icon(Icons.dns_outlined),
                    selectedIcon: Icon(Icons.dns),
                    label: Text('Nodes'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.list_alt_outlined),
                    selectedIcon: Icon(Icons.list_alt),
                    label: Text('Tasks'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.terminal_outlined),
                    selectedIcon: Icon(Icons.terminal),
                    label: Text('Logs'),
                  ),
                  // Add AI Destination if needed
                  NavigationRailDestination(
                    icon: Icon(Icons.auto_awesome_outlined),
                    selectedIcon: Icon(Icons.auto_awesome),
                    label: Text('AI'),
                  ),
                ],
              ),
              const VerticalDivider(thickness: 1, width: 1), // Separator
              // --- Main Content Area ---
              Expanded(
                child: Center(
                  // Display the selected screen's content
                  child: _widgetOptions.elementAt(_selectedIndex),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
