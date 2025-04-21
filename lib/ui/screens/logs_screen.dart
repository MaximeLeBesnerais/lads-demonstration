import 'package:flutter/material.dart';
import 'package:lads/ui/providers/orchestrator_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // For Clipboard

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
   final ScrollController _scrollController = ScrollController();

   @override
   void dispose() {
      _scrollController.dispose();
      super.dispose();
   }

   // Function to scroll to the bottom
   void _scrollToBottom() {
      // Use addPostFrameCallback to ensure the list view has rendered
      WidgetsBinding.instance.addPostFrameCallback((_) {
         if (_scrollController.hasClients) {
            _scrollController.animateTo(
               _scrollController.position.maxScrollExtent,
               duration: const Duration(milliseconds: 300),
               curve: Curves.easeOut,
            );
         }
      });
   }

   // Function to copy logs to clipboard
   void _copyLogsToClipboard(List<String> logs) {
      final logText = logs.join('\n');
      Clipboard.setData(ClipboardData(text: logText)).then((_) {
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logs copied to clipboard!')),
         );
      });
   }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrchestratorProvider>();
    final logs = provider.logs;

    // Scroll to bottom whenever logs change
    // Note: This might become inefficient with very large log lists.
    // Consider only scrolling if the user was already near the bottom.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());


    return Scaffold(
       appBar: AppBar(
         title: const Text('Orchestrator Logs'),
         actions: [
            if (logs.isNotEmpty)
               IconButton(
                  icon: const Icon(Icons.copy_all_outlined),
                  tooltip: 'Copy Logs',
                  onPressed: () => _copyLogsToClipboard(logs),
               ),
            if (logs.isNotEmpty)
               Padding(
                 padding: const EdgeInsets.only(right: 8.0),
                 child: TextButton.icon(
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('Clear Logs'),
                    style: TextButton.styleFrom(foregroundColor: Colors.orange.shade300),
                    onPressed: () {
                       // Optional: Add confirmation dialog
                       provider.clearLogs();
                       ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Logs cleared.')),
                       );
                    },
                 ),
               ),
         ],
         backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
         elevation: 1,
       ),
      body: logs.isEmpty
          ? const Center(child: Text('No logs available.'))
          : Padding(
             padding: const EdgeInsets.all(8.0),
             child: Scrollbar( // Add scrollbar for desktop/web
                thumbVisibility: true,
                controller: _scrollController,
                child: ListView.builder(
                   controller: _scrollController,
                   itemCount: logs.length,
                   itemBuilder: (context, index) {
                     final logEntry = logs[index];
                     // Basic log styling
                     return Padding(
                       padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 4.0),
                       child: Text(
                         logEntry,
                         style: const TextStyle(
                           fontFamily: 'monospace', // Use monospace for logs
                           fontSize: 12,
                         ),
                       ),
                     );
                   },
                 ),
             ),
          ),
    );
  }
}
