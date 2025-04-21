import 'package:flutter/material.dart';
import 'package:lads/model/command_result.dart'; // For AiCommandResult
import 'package:lads/ui/providers/orchestrator_provider.dart';
import 'package:lads/ui/utils/command_parser.dart'; // Import the parser
import 'package:provider/provider.dart';

// Represents different types of entries in the AI chat log
enum AiLogEntryType { user, aiMessage, aiCommandPlan, executionFeedback, error, info }

class AiLogEntry {
  final AiLogEntryType type;
  final dynamic content; // String for messages/feedback, List<ParsedCommand> for plan
  final DateTime timestamp;

  AiLogEntry({required this.type, required this.content}) : timestamp = DateTime.now();
}

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final _apiKeyController = TextEditingController();
  final _promptController = TextEditingController();
  final _scrollController = ScrollController();
  bool _obscureApiKey = true;

  // Local state to build the chat log
  final List<AiLogEntry> _logEntries = [];
  // Keep track of the last processed result/feedback/error to avoid duplicates
  AiCommandResult? _lastProcessedAiResult;
  List<String> _lastProcessedFeedback = [];
  String? _lastProcessedError;
  String? _lastUserPrompt; // Track last user prompt to add it to log

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to run after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // Check if widget is still mounted
      final provider = context.read<OrchestratorProvider>();
      _apiKeyController.text = provider.apiKey ?? '';
      // Add initial message
      if (_logEntries.isEmpty) {
         _logEntries.add(AiLogEntry(type: AiLogEntryType.info, content: "AI Assistant ready. Set your API Key below and enter instructions."));
      }
      // Add listener *after* initial state setup
      provider.addListener(_providerListener);
      _scrollToBottom(instant: true); // Scroll down initially
    });
  }

  @override
  void dispose() {
    // Remove listener when the widget is disposed
    // Use try-read in case provider is disposed first during navigation
    Provider.of<OrchestratorProvider>(context, listen: false).removeListener(_providerListener);
    _apiKeyController.dispose();
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Listener for provider changes
  void _providerListener() {
    if (!mounted) return; // Check if widget is still mounted
    final provider = context.read<OrchestratorProvider>();
    bool logChanged = false;

    // --- Add AI Response / Plan / Error to Log ---
    // Check if there's a new AI result that hasn't been logged yet
    if (provider.lastAiResult != null && provider.lastAiResult != _lastProcessedAiResult) {
       _lastProcessedAiResult = provider.lastAiResult; // Mark as processed

       // Add AI message if present
       if (_lastProcessedAiResult!.message != null && _lastProcessedAiResult!.message!.isNotEmpty) {
          _logEntries.add(AiLogEntry(type: AiLogEntryType.aiMessage, content: _lastProcessedAiResult!.message!));
          logChanged = true;
       }
       // Add command plan if present and confirmation is pending
       if (provider.isAiConfirmationPending && _lastProcessedAiResult!.instructions != null) {
          final parsedCommands = _lastProcessedAiResult!.instructions!
              .map((cmd) => CommandParser.parse(cmd))
              .toList();
          _logEntries.add(AiLogEntry(type: AiLogEntryType.aiCommandPlan, content: parsedCommands));
          logChanged = true;
       }
    }

    // Check for new AI errors
    if (provider.aiError != null && provider.aiError != _lastProcessedError) {
       _lastProcessedError = provider.aiError;
       _logEntries.add(AiLogEntry(type: AiLogEntryType.error, content: _lastProcessedError!));
       logChanged = true;
    } else if (provider.aiError == null && _lastProcessedError != null) {
        _lastProcessedError = null; // Clear error if it was resolved
    }


    // Check for new execution feedback
    // Compare lists carefully
    if (!listEquals(provider.executedAiCommandsFeedback, _lastProcessedFeedback)) {
       // Find the new feedback entries
       final newFeedback = provider.executedAiCommandsFeedback.skip(_lastProcessedFeedback.length).toList();
       for (final feedback in newFeedback) {
          _logEntries.add(AiLogEntry(type: AiLogEntryType.executionFeedback, content: feedback));
          logChanged = true;
       }
       _lastProcessedFeedback = List.from(provider.executedAiCommandsFeedback); // Update processed list
    }

    // --- Update UI ---
    if (logChanged) {
      setState(() {}); // Trigger rebuild to show new log entries
      _scrollToBottom(); // Scroll down when new logs are added
    }
  }


  void _saveApiKey() {
    final newKey = _apiKeyController.text.trim();
    context.read<OrchestratorProvider>().setApiKey(newKey).then((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newKey.isNotEmpty ? 'API Key updated.' : 'API Key cleared.'),
          backgroundColor: newKey.isNotEmpty ? Colors.green : Colors.orange,
        ),
      );
    }).catchError((err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving API Key: $err'), backgroundColor: Colors.red),
      );
    });
    FocusScope.of(context).unfocus();
  }

  void _submitPrompt() {
    final text = _promptController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
         _lastUserPrompt = text; // Store prompt to add to log
         _logEntries.add(AiLogEntry(type: AiLogEntryType.user, content: text));
         _scrollToBottom();
      });
      context.read<OrchestratorProvider>().processAiCommand(text);
      _promptController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  void _scrollToBottom({bool instant = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
         final position = _scrollController.position.maxScrollExtent;
         if (instant) {
            _scrollController.jumpTo(position);
         } else {
            _scrollController.animateTo(
               position,
               duration: const Duration(milliseconds: 300),
               curve: Curves.easeOut,
            );
         }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrchestratorProvider>();
    final theme = Theme.of(context);
    // Determine if input should be disabled
    final bool disableInput = provider.isAiProcessing || provider.isAiConfirmationPending;

    return Scaffold(
      // No AppBar here, HomeScreen manages it
      body: Column(
        children: [
          // --- API Key Section ---
          _buildApiKeySection(context, provider, theme),

          const Divider(height: 1),

          // --- Chat Log Area ---
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: _logEntries.length,
              itemBuilder: (context, index) {
                return _buildLogEntryWidget(_logEntries[index], theme, provider);
              },
            ),
          ),

          const Divider(height: 1),

          // --- Input Area ---
          _buildInputArea(context, provider, theme, disableInput),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildApiKeySection(BuildContext context, OrchestratorProvider provider, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _apiKeyController,
              obscureText: _obscureApiKey,
              decoration: InputDecoration(
                labelText: 'Gemini API Key',
                hintText: 'Enter your key here',
                isDense: true,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureApiKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                ),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
             onPressed: _saveApiKey,
             child: const Text('Save Key'),
          ),
          const SizedBox(width: 10),
          Icon(
             provider.isApiKeySet ? Icons.check_circle_outline : Icons.error_outline,
             color: provider.isApiKeySet ? Colors.green.shade300 : Colors.orange.shade300,
             size: 20,
          ),
        ],
      ),
    );
  }

   Widget _buildInputArea(BuildContext context, OrchestratorProvider provider, ThemeData theme, bool disableInput) {
     return Padding(
       padding: const EdgeInsets.all(8.0),
       child: Row(
         children: [
           Expanded(
             child: TextField(
               controller: _promptController,
               enabled: !disableInput, // Disable based on state
               decoration: InputDecoration(
                 hintText: disableInput ? 'Processing...' : 'Enter your instruction...',
                 isDense: true,
                 border: const OutlineInputBorder(),
                 filled: disableInput, // Fill background when disabled
                 fillColor: disableInput ? theme.disabledColor.withOpacity(0.1) : null,
               ),
               onSubmitted: disableInput ? null : (_) => _submitPrompt(), // Allow submit on Enter
             ),
           ),
           const SizedBox(width: 8),
           IconButton(
             icon: provider.isAiProcessing && !provider.isAiConfirmationPending
                 ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) // Loading indicator
                 : const Icon(Icons.send),
             tooltip: 'Send',
             onPressed: disableInput ? null : _submitPrompt, // Disable based on state
             style: IconButton.styleFrom(
                backgroundColor: disableInput ? null : theme.colorScheme.primary,
                foregroundColor: disableInput ? null : theme.colorScheme.onPrimary,
             ),
           ),
         ],
       ),
     );
   }

  Widget _buildLogEntryWidget(AiLogEntry entry, ThemeData theme, OrchestratorProvider provider) {
    Alignment alignment = Alignment.centerLeft;
    Color? backgroundColor;
    Widget contentWidget;

    switch (entry.type) {
      case AiLogEntryType.user:
        alignment = Alignment.centerRight;
        backgroundColor = theme.colorScheme.primaryContainer.withOpacity(0.6);
        contentWidget = Text(entry.content as String);
        break;

      case AiLogEntryType.aiMessage:
        backgroundColor = theme.colorScheme.secondaryContainer.withOpacity(0.6);
        contentWidget = Text(entry.content as String);
        break;

      case AiLogEntryType.aiCommandPlan:
        backgroundColor = theme.colorScheme.tertiaryContainer.withOpacity(0.5);
        final parsedCommands = entry.content as List<ParsedCommand>;
        contentWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text("AI suggests the following plan:", style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
             const SizedBox(height: 4),
             for (var pCmd in parsedCommands)
                Padding(
                   padding: const EdgeInsets.only(left: 8.0, top: 4),
                   child: Text(
                      pCmd.isSupported ? '• ${pCmd.action}: ${pCmd.details}' : '• Unsupported: ${pCmd.rawCommand}',
                      style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace', fontSize: 12)
                   ),
                ),
             const SizedBox(height: 12),
             // Confirmation Buttons (only shown if confirmation is pending for this plan)
             if (provider.isAiConfirmationPending && provider.lastAiResult?.instructions == parsedCommands.map((pc) => pc.rawCommand).toList())
                Row(
                   mainAxisAlignment: MainAxisAlignment.end,
                   children: [
                      TextButton.icon(
                         icon: const Icon(Icons.close, color: Colors.redAccent),
                         label: const Text('Reject', style: TextStyle(color: Colors.redAccent)),
                         onPressed: provider.rejectAiCommands,
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                         icon: const Icon(Icons.check),
                         label: const Text('Accept & Run'),
                         style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                         onPressed: provider.acceptAndExecuteAiCommands,
                      ),
                   ],
                ),
          ],
        );
        break;

      case AiLogEntryType.executionFeedback:
         backgroundColor = theme.colorScheme.surfaceVariant.withOpacity(0.4);
         contentWidget = Text(
            entry.content as String,
            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', color: theme.colorScheme.onSurfaceVariant)
         );
         break;

      case AiLogEntryType.error:
         backgroundColor = theme.colorScheme.errorContainer.withOpacity(0.6);
         contentWidget = Text(
            'Error: ${entry.content}',
            style: TextStyle(color: theme.colorScheme.onErrorContainer)
         );
         break;

       case AiLogEntryType.info:
          alignment = Alignment.center;
          backgroundColor = theme.colorScheme.secondaryContainer.withOpacity(0.3);
          contentWidget = Text(entry.content as String, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic));
          break;

    }

    // Common styling for chat bubbles
    return Align(
      alignment: alignment,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75), // Limit bubble width
        decoration: BoxDecoration(
          color: backgroundColor ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: contentWidget,
      ),
    );
  }
}

// Helper function to compare lists (needed for feedback check)
bool listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

