import 'dart:async';

// --- Enums remain the same ---
enum NodeClass { backup, compute, storage, network, database, generic }
enum NodeState { active, inactive, maintenance, decommissioned }

// --- Updated Task class ---
class Task {
  final String name;
  final int cpuCores;
  final Duration initialTaskLength; // Original total duration
  final NodeClass taskClass;
  final Function? onComplete; // Optional callback

  int id = 0; // Assigned by Node
  bool isRunning = false;

  // --- State for live duration tracking ---
  late Duration _remainingDuration;
  DateTime? _startTime;
  Timer? _timer;

  // --- Stream for UI updates ---
  // Use a broadcast stream controller so multiple listeners are possible (e.g., UI and logs)
  final StreamController<Duration> _durationController = StreamController.broadcast();
  Stream<Duration> get remainingDurationStream => _durationController.stream;
  Duration get currentRemainingDuration => _remainingDuration;

  Task(
    this.name,
    Duration taskLength, // Keep original constructor signature
    this.cpuCores, {
    this.taskClass = NodeClass.generic,
    this.onComplete,
  }) : initialTaskLength = taskLength /* Store original duration */ {
    if (cpuCores <= 0) {
      throw ArgumentError('Cpu cores must be greater than 0');
    }
    if (initialTaskLength.isNegative) {
      throw ArgumentError('Task duration must be greater than or equal to 0');
    }
    // Initialize remaining duration
    _remainingDuration = initialTaskLength;
  }

  void setId(int id) {
    this.id = id;
  }

  /// Starts the task execution timer and returns a Future that completes when the task finishes.
  Future<void> start() {
    if (isRunning) {
      // Avoid starting multiple timers for the same task
      return Future.error(StateError('Task $id ($name) is already running.'));
    }

    final taskCompletionCompleter = Completer<void>();
    _startTime = DateTime.now();
    _remainingDuration = initialTaskLength; // Reset just in case
    isRunning = true;

    // Immediately notify listeners of the starting duration
    _durationController.add(_remainingDuration);

    // Start a timer to update remaining duration periodically
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isRunning) { // Check if task was stopped externally
          timer.cancel();
          if (!taskCompletionCompleter.isCompleted) {
              taskCompletionCompleter.completeError(StateError("Task $id stopped prematurely."));
          }
          _closeStream(); // Ensure stream is closed
          return;
      }

      final elapsed = DateTime.now().difference(_startTime!);
      _remainingDuration = initialTaskLength - elapsed;

      if (_remainingDuration <= Duration.zero) {
        _remainingDuration = Duration.zero;
        _durationController.add(_remainingDuration); // Notify final zero duration
        timer.cancel(); // Stop the timer
        isRunning = false;
        _closeStream(); // Close the stream on completion

        // Signal that the task itself has finished its work
        if (!taskCompletionCompleter.isCompleted) {
            taskCompletionCompleter.complete();
        }

        // Execute the original onComplete callback if provided
        if (onComplete != null) {
          try {
            onComplete!();
          } catch (e) {
            // Log error from onComplete callback if necessary
            print('Error in onComplete for task $id ($name): $e');
          }
        }
      } else {
        // Notify listeners of the updated duration
        _durationController.add(_remainingDuration);
      }
    });

    // Return the future that signals task completion
    return taskCompletionCompleter.future;
  }

  /// Stops the task prematurely, cancels timers, and closes streams.
  void dispose() {
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
    }
    isRunning = false;
    _closeStream();
    // Consider completing the future with an error if disposed while running?
  }

  /// Helper to safely close the stream controller
  void _closeStream() {
     if (!_durationController.isClosed) {
         _durationController.close();
     }
  }


  @override
  String toString() {
    // Include remaining duration if running
    String durationString = isRunning
        ? 'remaining: ${_remainingDuration.toString().split('.').first}' // Format for readability
        : 'length: ${initialTaskLength.toString().split('.').first}';
    return 'Task{name: $name, id: $id, $durationString}';
  }
}


// --- Updated Node class ---
class Node {
  final String name;
  final String id;
  final int cpuCores;
  NodeState nodeState = NodeState.active;
  int busyCores = 0;

  Node? parent;
  List<Node> children = [];

  NodeClass nodeClass = NodeClass.generic;
  List<Task> tasks = []; // Holds the currently running tasks
  // Replace simple List<String> logs with your custom Log class instance if needed
  List<String> logs = [];

  // Still needed for setState waiting logic
  // Maps Task ID to the Future returned by task.start()
  final Map<int, Future<void>> taskCompletionFutures = {};

  Node(
    this.name,
    this.id,
    this.cpuCores, {
    this.nodeClass = NodeClass.generic,
  }) {
    if (cpuCores <= 0) {
      throw ArgumentError('Cpu cores must be greater than 0');
    }
  }

  // --- State Management (setState, _waitForTasks) remains largely the same ---
  // It now relies on the futures stored in _taskCompletionFutures which come from task.start()

  List<Future<void>> get _activeTaskFutures =>
      taskCompletionFutures.values.toList(); // Get futures directly from map values

  Future<List<String>> setState(NodeState newState) async {
    List<String> transitionLogs = [];
    // Your custom Log class would be used here instead of transitionLogs.add(...)
    if (nodeState == newState) {
      transitionLogs.add('Node $name is already in state $newState.');
      return transitionLogs;
    }

    Future<bool> waitForTasks(String targetStateDescription) async {
      transitionLogs.add(
          'Node $name preparing for $targetStateDescription. Waiting for ${taskCompletionFutures.length} tasks to complete...');
      try {
        List<Future<void>> futuresToWaitFor = _activeTaskFutures;
        if (futuresToWaitFor.isNotEmpty) {
          // Use Future.wait - it handles errors within the futures gracefully
           await Future.wait(futuresToWaitFor);
           // If Future.wait completes without throwing, all tasks finished (successfully or with handled errors)
        }
        // Check map/list consistency after waiting
        if (tasks.isEmpty && taskCompletionFutures.isEmpty) {
          transitionLogs.add('All tasks completed on node $name.');
          return true;
        } else {
          // This might indicate tasks were added *during* the wait, or a logic error
          transitionLogs.add(
              'Node $name could not transition to $targetStateDescription. Tasks still present after waiting (tasks: ${tasks.length}, futures: ${taskCompletionFutures.length}).');
          return false;
        }
      } catch (e) {
        // Catch errors from Future.wait itself (e.g., if one of the task futures completed with an unhandled error)
        transitionLogs.add(
            'Error waiting for tasks on node $name for $targetStateDescription: $e. State transition aborted.');
        return false;
      }
    }

    // Switch statement for state transitions remains the same, using _waitForTasks
    switch (newState) {
      case NodeState.active:
        if (nodeState == NodeState.inactive) {
          nodeState = NodeState.active;
          transitionLogs.add('Node $name is now active.');
        } else {
          transitionLogs.add(
              'Node $name cannot be activated from state $nodeState.');
        }
        break;

      case NodeState.inactive:
        if (nodeState == NodeState.active) {
          bool tasksFinished = await waitForTasks("standby (inactive)");
          if (tasksFinished) {
            nodeState = NodeState.inactive;
            transitionLogs.add('Node $name is now in standby (inactive).');
          }
        } else {
          transitionLogs.add(
              'Node $name cannot be put into standby from state $nodeState.');
        }
        break;

      case NodeState.maintenance:
        if (nodeState == NodeState.active || nodeState == NodeState.inactive) {
          bool tasksFinished = await waitForTasks("maintenance");
          if (tasksFinished) {
            nodeState = NodeState.maintenance;
            transitionLogs.add('Node $name is now in maintenance.');
          }
        } else {
          transitionLogs.add(
              'Node $name cannot be put into maintenance from state $nodeState.');
        }
        break;

      case NodeState.decommissioned:
        bool tasksFinished = await waitForTasks("decommissioning");
        if (tasksFinished) {
          nodeState = NodeState.decommissioned;
          transitionLogs.add('Node $name is now decommissioned.');
          // Clean up any remaining task resources explicitly
          for (var task in List<Task>.from(tasks)) { // Iterate over a copy
             removeTaskInternal(task.id, triggeredByDecommission: true);
          }
          // Ensure lists/maps are clear
          tasks.clear();
          taskCompletionFutures.clear();
          busyCores = 0;
        }
        break;
    }
    // Add logs to your custom log class instance here
    logs.addAll(transitionLogs);
    return transitionLogs;
  }


  int get availableCores {
    return cpuCores - busyCores;
  }

  // repurpose remains the same
  void repurpose(NodeClass newClass, bool hierarchical) {
    if (nodeState == NodeState.decommissioned) {
      logs.add('Node $name is decommissioned and cannot be repurposed.');
      return;
    }
    nodeClass = newClass;
    logs.add('Node $name repurposed to $newClass.');
    if (hierarchical) {
      for (var child in children) {
        child.repurpose(newClass, hierarchical);
      }
    }
  }

  /// Internal method to clean up task state within the Node.
  void removeTaskInternal(int taskId, {bool triggeredByDecommission = false}) {
    Task? taskToRemove;
    int taskIndex = -1;
    for (int i = 0; i < tasks.length; i++) {
      if (tasks[i].id == taskId) {
        taskToRemove = tasks[i];
        taskIndex = i;
        break;
      }
    }

    // Remove the completion future regardless of whether the task is found in the list
    // (it might have completed just before a decommission call)
    taskCompletionFutures.remove(taskId);

    if (taskToRemove != null) {
      // Call dispose on the task to clean up its timer/stream
      taskToRemove.dispose();

      // Update node state only if not triggered by decommissioning (which clears busyCores later)
      if (!triggeredByDecommission) {
          busyCores -= taskToRemove.cpuCores;
          if (busyCores < 0) {
            busyCores = 0;
          }
      }
      tasks.removeAt(taskIndex); // Remove from list
      logs.add(
          'Task ${taskToRemove.name} (ID: $taskId) finished/removed from node $name.');
    } else {
      // Log if task wasn't found but cleanup was triggered
      logs.add(
          'Warning: Cleanup triggered for task ID $taskId on node $name, but task was not found in the active list (may have already finished).');
    }
  }

  /// Adds a task, starts its internal timer, and sets up cleanup.
  void addTask(Task task) {
    // --- Initial checks remain the same ---
    if (nodeState != NodeState.active) {
      logs.add(
          'Node $name is not active (state: $nodeState), cannot accept task ${task.name}.');
      throw StateError(
          'Node $name is not active, cannot accept new tasks.');
    }
    if (busyCores + task.cpuCores > cpuCores) {
      logs.add(
          'Node $name does not have enough CPU cores ($availableCores available) for task ${task.name} (${task.cpuCores} required).');
      throw ArgumentError(
          'Not enough CPU cores available on node $name.');
    }

    // --- ID Generation remains the same ---
    int nextId = 0;
    if (tasks.isNotEmpty) {
      nextId = tasks.map((t) => t.id).fold(0, (maxId, id) => id > maxId ? id : maxId) + 1;
    }
     if (taskCompletionFutures.isNotEmpty) {
       int maxFutureId = taskCompletionFutures.keys.fold(0, (maxId, id) => id > maxId ? id : maxId);
       if (maxFutureId >= nextId) {
         nextId = maxFutureId + 1;
       }
     }
     if (tasks.isEmpty && taskCompletionFutures.isEmpty) {
       nextId = 1; // Start IDs at 1
     }
    task.setId(nextId);

    // --- Start the task and manage its completion ---
    try {
        tasks.add(task); // Add task to list first
        busyCores += task.cpuCores;
        logs.add(
            'Task ${task.name} (ID: ${task.id}) added to node $name. Starting execution...');

        // Start the task's internal timer and get its completion future
        Future<void> taskCompletionFuture = task.start();

        // Store the future so setState can wait for it
        taskCompletionFutures[task.id] = taskCompletionFuture;

        // Set up cleanup logic to run *after* the task completes (successfully or not)
        taskCompletionFuture.whenComplete(() {
            // This block runs whether task.start()'s future completes successfully or with an error
            removeTaskInternal(task.id);
        });

    } catch (e) {
        // Handle potential errors from task.start() itself
        logs.add('Error starting task ${task.name} (ID: ${task.id}): $e');
        // Clean up if starting failed
        tasks.remove(task); // Remove from list if added
        busyCores -= task.cpuCores; // Revert core count
        if (busyCores < 0) busyCores = 0;
        taskCompletionFutures.remove(task.id); // Remove future if added
    }
  }

  // canAcceptTask remains the same
  bool canAcceptTask(Task task) {
    if (nodeState != NodeState.active) {
      return false;
    }
    bool typeMatch =
        task.taskClass == nodeClass ||
        task.taskClass == NodeClass.generic ||
        nodeClass == NodeClass.generic;
    bool cpuMatch = availableCores >= task.cpuCores;
    return typeMatch && cpuMatch;
  }
}
