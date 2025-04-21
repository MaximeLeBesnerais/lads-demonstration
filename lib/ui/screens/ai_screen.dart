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
  // Add a unique ID to potentially help identify specific results if needed later
  final String id = UniqueKey().toString();

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
  // Keep track of the last processed result/feedback/error to avoid duplicates in log
  AiCommandResult? _lastProcessedAiResult;
  List<String> _lastProcessedFeedback = [];
  String? _lastProcessedError;
// Track last user prompt to add it to log

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<OrchestratorProvider>();
      _apiKeyController.text = provider.apiKey ?? '';
      if (_logEntries.isEmpty) {
         _logEntries.add(AiLogEntry(type: AiLogEntryType.info, content: "AI Assistant ready. Set your API Key below and enter instructions."));
         // Trigger initial build if needed
         setState(() {});
      }
      provider.addListener(_providerListener);
      _scrollToBottom(instant: true);
    });
  }

  @override
  void dispose() {
    // Use try-read in case provider is disposed first during navigation
    try {
       Provider.of<OrchestratorProvider>(context, listen: false).removeListener(_providerListener);
    } catch (e) {
       print("Error removing listener: $e"); // Handle potential error if provider is already gone
    }
    _apiKeyController.dispose();
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _providerListener() {
    if (!mounted) return;
    final provider = context.read<OrchestratorProvider>();
    bool logChanged = false;

    // --- Add User Prompt to Log ---
    // Check if the last prompt was processed and needs logging
    // This might need refinement depending on exact desired log flow
    // Currently adding user prompt in _submitPrompt is simpler

    // --- Add AI Response / Plan / Error to Log ---
    if (provider.lastAiResult != _lastProcessedAiResult) {
       final currentResult = provider.lastAiResult;
       _lastProcessedAiResult = currentResult; // Mark as processed immediately

       if (currentResult != null) {
          // Add AI message if present
          if (currentResult.message != null && currentResult.message!.isNotEmpty) {
             _logEntries.add(AiLogEntry(type: AiLogEntryType.aiMessage, content: currentResult.message!));
             logChanged = true;
          }
          // Add command plan if present (regardless of confirmation state here, button logic handles visibility)
          if (currentResult.answerType == 'instructions' && currentResult.instructions != null && currentResult.instructions!.isNotEmpty) {
             final parsedCommands = currentResult.instructions!
                 .map((cmd) => CommandParser.parse(cmd))
                 .toList();
             _logEntries.add(AiLogEntry(type: AiLogEntryType.aiCommandPlan, content: parsedCommands));
             logChanged = true;
          }
       }
    }

    // Check for new AI errors
    if (provider.aiError != _lastProcessedError) {
       _lastProcessedError = provider.aiError;
       if (_lastProcessedError != null) {
          _logEntries.add(AiLogEntry(type: AiLogEntryType.error, content: _lastProcessedError!));
          logChanged = true;
       }
    }

    // Check for new execution feedback
    if (!listEquals(provider.executedAiCommandsFeedback, _lastProcessedFeedback)) {
       final newFeedback = provider.executedAiCommandsFeedback.skip(_lastProcessedFeedback.length).toList();
       for (final feedback in newFeedback) {
          _logEntries.add(AiLogEntry(type: AiLogEntryType.executionFeedback, content: feedback));
          logChanged = true;
       }
       _lastProcessedFeedback = List.from(provider.executedAiCommandsFeedback);
    }

    // --- Update UI ---
    if (logChanged) {
      // Use setState only if the widget is still mounted
      if (mounted) {
        setState(() {});
      }
      _scrollToBottom();
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
      // Add user prompt to log immediately
      setState(() {
         _logEntries.add(AiLogEntry(type: AiLogEntryType.user, content: text));
         _scrollToBottom();
      });
      // Clear controller *before* async call
      _promptController.clear();
      FocusScope.of(context).unfocus();
      // Call provider to process
      context.read<OrchestratorProvider>().processAiCommand(text);
    }
  }

  void _scrollToBottom({bool instant = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) { // Check mounted
         final position = _scrollController.position.maxScrollExtent;
         try {
           if (instant) {
              _scrollController.jumpTo(position);
           } else {
              _scrollController.animateTo(
                 position,
                 duration: const Duration(milliseconds: 300),
                 curve: Curves.easeOut,
              );
           }
         } catch (e) {
            print("Error scrolling: $e"); // Catch potential errors during dispose
         }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use Consumer here to react to provider changes directly in build
    return Consumer<OrchestratorProvider>(
      builder: (context, provider, child) {
        final theme = Theme.of(context);
        final bool disableInput = provider.isAiProcessing || provider.isAiConfirmationPending;

        // Find the last command plan entry to potentially show buttons
        final lastPlanEntryIndex = _logEntries.lastIndexWhere((e) => e.type == AiLogEntryType.aiCommandPlan);
        final lastPlanEntry = lastPlanEntryIndex != -1 ? _logEntries[lastPlanEntryIndex] : null;

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
                     final entry = _logEntries[index];
                     // Determine if *this* entry is the one pending confirmation
                     final bool isPendingConfirmation = provider.isAiConfirmationPending &&
                                                       entry.type == AiLogEntryType.aiCommandPlan &&
                                                       entry == lastPlanEntry; // Check if it's the last plan entry
                     return _buildLogEntryWidget(entry, theme, provider, isPendingConfirmation);
                  },
                ),
              ),
              const Divider(height: 1),

              // --- Input Area ---
              _buildInputArea(context, provider, theme, disableInput),
            ],
          ),
        );
      },
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
          Tooltip( // Add tooltip for status icon
             message: provider.isApiKeySet ? 'API Key is set' : 'API Key is not set',
             child: Icon(
                provider.isApiKeySet ? Icons.check_circle_outline : Icons.error_outline,
                color: provider.isApiKeySet ? Colors.green.shade300 : Colors.orange.shade300,
                size: 20,
             ),
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
               enabled: !disableInput,
               decoration: InputDecoration(
                 hintText: disableInput ? 'Processing...' : 'Enter your instruction...',
                 isDense: true,
                 border: const OutlineInputBorder(),
                 filled: disableInput,
                 fillColor: disableInput ? theme.disabledColor.withOpacity(0.1) : null,
               ),
               onSubmitted: disableInput ? null : (_) => _submitPrompt(),
               textInputAction: TextInputAction.send, // Show send icon on keyboard
             ),
           ),
           const SizedBox(width: 8),
           IconButton(
             icon: provider.isAiProcessing && !provider.isAiConfirmationPending
                 ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                 : const Icon(Icons.send),
             tooltip: 'Send',
             onPressed: disableInput ? null : _submitPrompt,
             style: IconButton.styleFrom(
                backgroundColor: disableInput ? theme.disabledColor : theme.colorScheme.primary,
                foregroundColor: disableInput ? theme.colorScheme.onSurface.withOpacity(0.5) : theme.colorScheme.onPrimary,
             ),
           ),
         ],
       ),
     );
   }

  // Updated to accept isPendingConfirmation flag
  Widget _buildLogEntryWidget(AiLogEntry entry, ThemeData theme, OrchestratorProvider provider, bool isPendingConfirmation) {
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
                      // Display parsed details more clearly
                      pCmd.isSupported
                         ? '• ${pCmd.action}: ${pCmd.details.entries.map((e) => "${e.key}=${e.value}").join(', ')}'
                         : '• Unsupported: ${pCmd.rawCommand}',
                      style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace', fontSize: 12)
                   ),
                ),
             // --- *** MODIFIED BUTTON LOGIC *** ---
             // Show buttons only if this specific entry needs confirmation
             if (isPendingConfirmation) ...[
                const SizedBox(height: 12),
                Row(
                   mainAxisAlignment: MainAxisAlignment.end,
                   children: [
                      TextButton.icon(
                         icon: const Icon(Icons.close, color: Colors.redAccent),
                         label: const Text('Reject', style: TextStyle(color: Colors.redAccent)),
                         onPressed: provider.rejectAiCommands, // Use provider method
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                         icon: const Icon(Icons.check),
                         label: const Text('Accept & Run'),
                         style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white, // Ensure text is visible
                         ),
                         onPressed: provider.acceptAndExecuteAiCommands, // Use provider method
                      ),
                   ],
                ),
             ]
             // --- *** END MODIFICATION *** ---
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
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: backgroundColor,
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
  // Allow empty lists to be equal
  if (a.isEmpty && b.isEmpty) return true;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
