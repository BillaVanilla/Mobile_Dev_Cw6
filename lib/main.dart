import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const TaskListScreen(),
    );
  }
}

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({Key? key}) : super(key: key);

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TextEditingController _taskController = TextEditingController();
  final CollectionReference tasksCollection = FirebaseFirestore.instance.collection('tasks');

  // Add new task to Firebase
  Future<void> _addTask(String taskName) async {
    if (taskName.isEmpty) return;
    await tasksCollection.add({
      'name': taskName,
      'completed': false,
      'subtasks': [],
    });
    _taskController.clear();
  }

  // Update task completion status
  Future<void> _toggleTaskCompletion(DocumentSnapshot task) async {
    await tasksCollection.doc(task.id).update({'completed': !task['completed']});
  }

  // Delete task
  Future<void> _deleteTask(DocumentSnapshot task) async {
    await tasksCollection.doc(task.id).delete();
  }

  // Add a subtask to an existing task
  Future<void> _addSubtask(DocumentSnapshot task, String subtaskName, String time) async {
    List subtasks = task['subtasks'];
    subtasks.add({'name': subtaskName, 'time': time});
    await tasksCollection.doc(task.id).update({'subtasks': subtasks});
  }

  // Show dialog to add a new subtask with a specific time
  void _showAddSubtaskDialog(DocumentSnapshot task) {
    final TextEditingController _subtaskController = TextEditingController();
    final TextEditingController _timeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Subtask'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _subtaskController,
              decoration: const InputDecoration(labelText: 'Subtask name'),
            ),
            TextField(
              controller: _timeController,
              decoration: const InputDecoration(labelText: 'Time (e.g., 9am - 10am)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _addSubtask(task, _subtaskController.text, _timeController.text);
              Navigator.of(context).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: const InputDecoration(
                      labelText: 'Enter task name',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addTask(_taskController.text),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: tasksCollection.snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView(
                  children: snapshot.data!.docs.map((task) {
                    return TaskTile(
                      task: task,
                      onDelete: () => _deleteTask(task),
                      onToggleComplete: () => _toggleTaskCompletion(task),
                      onAddSubtask: () => _showAddSubtaskDialog(task),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TaskTile extends StatelessWidget {
  final DocumentSnapshot task;
  final VoidCallback onDelete;
  final VoidCallback onToggleComplete;
  final VoidCallback onAddSubtask;

  const TaskTile({
    Key? key,
    required this.task,
    required this.onDelete,
    required this.onToggleComplete,
    required this.onAddSubtask,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      child: ExpansionTile(
        leading: Checkbox(
          value: task['completed'],
          onChanged: (bool? value) => onToggleComplete(),
        ),
        title: Text(
          task['name'],
          style: TextStyle(
            decoration: task['completed'] ? TextDecoration.lineThrough : null,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: onDelete,
        ),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 16.0),
                child: Text('Subtasks:', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Column(
                children: (task['subtasks'] as List).map<Widget>((subtask) {
                  return ListTile(
                    title: Text(subtask['name']),
                    subtitle: Text(subtask['time']),
                  );
                }).toList(),
              ),
              TextButton.icon(
                onPressed: onAddSubtask,
                icon: const Icon(Icons.add),
                label: const Text('Add Subtask'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
