import 'dart:async';

enum NodeClass { backup, compute, storage, network, database, generic }
enum NodeState { active, inactive, maintenance, decommissioned }

class Task {
  String name;
  int id = 0;
  int cpuCores;
  Duration taskLength;
  NodeClass taskClass = NodeClass.generic;
  Function? onComplete;

  Task(
    this.name,
    this.taskLength,
    this.cpuCores, {
    this.taskClass = NodeClass.generic,
    this.onComplete,
  }) {
    if (cpuCores <= 0) {
      throw ArgumentError('Cpu cores must be greater than 0');
    }
    if (taskLength.isNegative) {
      throw ArgumentError('Task duration must be greater than or equal to 0');
    }
  }

  void setId(int id) {
    this.id = id;
  }

  @override
  String toString() {
    return 'Task{name: $name, id: $id, taskLength: $taskLength}';
  }
}

class Node {
  final String name;
  final String id;
  final int cpuCores;
  NodeState nodeState = NodeState.active;
  int busyCores = 0;

  Node? parent;
  List<Node> children = [];

  NodeClass nodeClass = NodeClass.generic;
  List<Task> tasks = [];
  List<String> logs = [];

  final Map<int, Completer<void>> _taskCompleters = {};

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

  List<Future<void>> get _activeTaskFutures =>
      _taskCompleters.values.map((completer) => completer.future).toList();

  Future<List<String>> setState(NodeState newState) async {
    List<String> transitionLogs = [];

    if (nodeState == newState) {
      transitionLogs.add('Node $name is already in state $newState.');
      return transitionLogs;
    }

    Future<bool> _waitForTasks(String targetStateDescription) async {
      transitionLogs.add(
          'Node $name preparing for $targetStateDescription. Waiting for ${_taskCompleters.length} tasks to complete...');
      try {
        List<Future<void>> futuresToWaitFor = _activeTaskFutures;
        if (futuresToWaitFor.isNotEmpty) {
          await Future.wait(futuresToWaitFor);
        }
        if (tasks.isEmpty && _taskCompleters.isEmpty) {
          transitionLogs.add('All tasks completed on node $name.');
          return true;
        } else {
          transitionLogs.add(
              'Node $name could not transition to $targetStateDescription. Tasks still present after waiting (tasks: ${tasks.length}, completers: ${_taskCompleters.length}). Possible logic error.');
          return false;
        }
      } catch (e) {
        transitionLogs.add(
            'Error waiting for tasks on node $name for $targetStateDescription: $e. State transition aborted.');
        return false;
      }
    }

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
          bool tasksFinished = await _waitForTasks("standby (inactive)");
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
          bool tasksFinished = await _waitForTasks("maintenance");
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
        bool tasksFinished = await _waitForTasks("decommissioning");
        if (tasksFinished) {
          nodeState = NodeState.decommissioned;
          transitionLogs.add('Node $name is now decommissioned.');
          tasks.clear();
          _taskCompleters.clear();
          busyCores = 0;
        }
        break;
    }
    logs.addAll(transitionLogs);
    return transitionLogs;
  }

  int get availableCores {
    return cpuCores - busyCores;
  }

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

  void _removeTaskInternal(int taskId) {
    Task? taskToRemove;
    int taskIndex = -1;
    for (int i = 0; i < tasks.length; i++) {
      if (tasks[i].id == taskId) {
        taskToRemove = tasks[i];
        taskIndex = i;
        break;
      }
    }

    if (taskToRemove != null) {
      busyCores -= taskToRemove.cpuCores;
      if (busyCores < 0) {
        busyCores = 0;
      }
      tasks.removeAt(taskIndex);
      if (_taskCompleters.containsKey(taskId)) {
        _taskCompleters.remove(taskId);
      }
      logs.add(
          'Task ${taskToRemove.name} (ID: $taskId) completed and removed from node $name.');
    } else {
      logs.add(
          'Warning: Attempted to remove task with id $taskId from node $name, but it was not found in the task list.');
      if (_taskCompleters.containsKey(taskId)) {
        _taskCompleters.remove(taskId);
      }
    }
  }

  void addTask(Task task) {
    if (nodeState != NodeState.active) {
      logs.add(
          'Node $name is not active (state: $nodeState), cannot accept task ${task.name}.');
      throw StateError(
          'Node $name is not active, cannot accept new tasks.');
    }
    if (busyCores + task.cpuCores > cpuCores) {
      logs.add(
          'Node $name does not have enough CPU cores (${availableCores} available) for task ${task.name} (${task.cpuCores} required).');
      throw ArgumentError(
          'Not enough CPU cores available on node $name.');
    }

    int nextId = 0;
    if (tasks.isNotEmpty) {
      nextId = tasks.map((t) => t.id).reduce((a, b) => a > b ? a : b) + 1;
    }
    if (_taskCompleters.isNotEmpty) {
      int maxCompleterId =
          _taskCompleters.keys.reduce((a, b) => a > b ? a : b);
      if (maxCompleterId >= nextId) {
        nextId = maxCompleterId + 1;
      }
    } else if (tasks.isEmpty) {
      nextId = 1;
    }
    task.setId(nextId);

    final completer = Completer<void>();
    _taskCompleters[task.id] = completer;

    tasks.add(task);
    busyCores += task.cpuCores;
    logs.add(
        'Task ${task.name} (ID: ${task.id}) added to node $name. Execution started.');

    Future.delayed(task.taskLength).then((_) {
      if (nodeState != NodeState.decommissioned) {
        _removeTaskInternal(task.id);
        if (task.onComplete != null) {
          try {
            task.onComplete!();
          } catch (e) {
            logs.add(
                'Error executing onComplete callback for task ${task.name} (ID: ${task.id}): $e');
          }
        }
      } else {
        logs.add(
            'Node $name was decommissioned. Task ${task.name} (ID: ${task.id}) completion skipped.');
        _taskCompleters.remove(task.id);
      }

      if (_taskCompleters.containsKey(task.id)) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    }).catchError((error) {
      logs.add(
          'Error during simulated execution or cleanup for task ${task.name} (ID: ${task.id}): $error');
      _removeTaskInternal(task.id);
      if (_taskCompleters.containsKey(task.id)) {
        if (!completer.isCompleted) {
          _taskCompleters[task.id]?.completeError(error);
          _taskCompleters.remove(task.id);
        }
      }
    });
  }

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
