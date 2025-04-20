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
    return 'Task{name: $name, taskLength: $taskLength}';
  }
}

class Node {
  final String name;
  final String id;
  final int cpuCores;
  NodeState state = NodeState.active;
  int busyCores = 0;

  Node? parent;
  List<Node> children = [];

  NodeClass nodeClass = NodeClass.generic;
  List<Task> tasks = [];
  List<String> logs = [];

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

  int get availableCores {
    return cpuCores - busyCores;
  }

  void repurpose(NodeClass newClass, bool hierarchical) {
    nodeClass = newClass;
    if (hierarchical) {
      for (var child in children) {
        child.repurpose(newClass, hierarchical);
      }
    }
  }

  void removeTask(int taskId) {
    Task? taskToRemove;
    for (var task in tasks) {
      if (task.id == taskId) {
        taskToRemove = task;
        break;
      }
    }
    if (taskToRemove != null) {
      busyCores -= taskToRemove.cpuCores;
      if (busyCores < 0) {
        busyCores = 0; // Prevent negative busyCores
      }
      tasks.remove(taskToRemove);
    } else {
      throw ArgumentError('Task with id $taskId not found');
    }
  }

  void addTask(Task task) {
    if (busyCores + task.cpuCores > cpuCores) {
      throw ArgumentError('Not enough CPU cores available');
    }
    task.id =
        tasks.isEmpty
            ? 0
            : tasks.map((t) => t.id).fold(0, (a, b) => a > b ? a : b) + 1;
    tasks.add(task);
    busyCores += task.cpuCores;
    logs.add('Task ${task.name} added with id ${task.id}');
    Future.delayed(task.taskLength, () {
      removeTask(task.id);
      if (task.onComplete != null) {
        task.onComplete!();
      }
    });
  }

  bool canAcceptTask(Task task) {
    bool typeMatch =
        task.taskClass == nodeClass ||
        task.taskClass == NodeClass.generic ||
        nodeClass == NodeClass.generic;
    bool cpuMatch = availableCores >= task.cpuCores;
    return typeMatch && cpuMatch;
  }
}
