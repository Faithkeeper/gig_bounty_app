import 'package:flutter/material.dart';
import '../../data/remote/task_service.dart';
import '../../models/task_model.dart';
import '../../models/user_profile.dart';
import '../task/create_task_screen.dart';
import '../../data/remote/auth_service.dart';
import '../task/task_details_screen.dart';
import '../profile/profile_screen.dart';
import '../task/task_history_screen.dart';

class TaskBoardScreen extends StatefulWidget {
  final UserProfile userProfile;
  const TaskBoardScreen({super.key, required this.userProfile});

  @override
  State<TaskBoardScreen> createState() => _TaskBoardScreenState();
}

class _TaskBoardScreenState extends State<TaskBoardScreen> {
  final TaskService _taskService = TaskService();
  late final Stream<List<TaskModel>> _tasksStream;
  String _selectedFilter = 'All';
  final List<String> _filterCategories = [
    'All',
    'General',
    'Plumbing',
    'Tutoring',
    'IT Support',
    'Cleaning'
  ];

  @override
  void initState() {
    super.initState();
    _tasksStream = _taskService.getTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GigBounty Board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'View Profile',
            onPressed: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ProfileScreen(userProfile: widget.userProfile),
                ),
              );
              if (updated == true && mounted) {
                setState(() {});
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Task History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      TaskHistoryScreen(userProfile: widget.userProfile),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Category filter chips
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              itemCount: _filterCategories.length,
              itemBuilder: (context, index) {
                final cat = _filterCategories[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: _selectedFilter == cat,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedFilter = cat);
                      }
                    },
                  ),
                );
              },
            ),
          ),
          // Live Task Stream from Firestore
          Expanded(
            child: StreamBuilder<List<TaskModel>>(
              stream: _tasksStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text('No community tasks available right now.'));
                }

                final tasks = snapshot.data!.where((task) {
                  return _selectedFilter == 'All' ||
                      task.category == _selectedFilter;
                }).toList();

                if (tasks.isEmpty) {
                  return const Center(
                      child: Text('No tasks found for this category.'));
                }

                return ListView.builder(
                  itemCount: tasks.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        onTap: () {
                          // Navigate to Task Details & Bidding screen when clicked!
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TaskDetailsScreen(
                                task: task,
                                userProfile: widget.userProfile,
                              ),
                            ),
                          );
                        },
                        title: Text(task.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('${task.category} • ${task.location}'),
                            const SizedBox(height: 4),
                            Text('Budget: R${task.budget.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: Colors.deepOrange,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        trailing: Chip(
                          label: Text(task.status,
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.white)),
                          backgroundColor: task.status == 'Open'
                              ? Colors.green
                              : Colors.grey,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: widget.userProfile.role == 'Customer'
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateTaskScreen(
                      userId: widget.userProfile.uid,
                      userName: widget.userProfile.fullName,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Post Task'),
            )
          : null,
    );
  }
}
