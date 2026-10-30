import 'package:flutter/material.dart';
import '../../data/remote/task_service.dart';
import '../../models/task_model.dart';

class CreateTaskScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const CreateTaskScreen(
      {super.key, required this.userId, required this.userName});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final TaskService _taskService = TaskService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  String _selectedCategory = 'General';
  DateTime? _selectedDeadline;

  bool _isLoading = false;

  final List<String> _categories = [
    'General',
    'Plumbing',
    'Tutoring',
    'IT Support',
    'Cleaning'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _budgetController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 3)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, now.month, now.day),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDeadline = picked);
    }
  }

  void _publishTask() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isLoading = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final taskId = DateTime.now().millisecondsSinceEpoch.toString();
      final newTask = TaskModel(
        id: taskId,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        category: _selectedCategory,
        budget: double.parse(_budgetController.text.trim()),
        location: _locationController.text.trim(),
        posterId: widget.userId,
        posterName: widget.userName,
        createdAt: DateTime.now(),
        deadline: _selectedDeadline,
      );

      await _taskService.createTask(newTask);
      if (mounted && navigator.mounted) {
        navigator.pop();
      }
    } catch (e) {
      if (mounted && messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error publishing task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Publish New Micro-Task')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Task Title'),
                validator: (val) =>
                    val!.isEmpty ? 'Please enter a task title' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories
                    .map(
                        (cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _budgetController,
                decoration: const InputDecoration(labelText: 'Budget (ZAR)'),
                keyboardType: TextInputType.number,
                validator: (val) => double.tryParse(val ?? '') == null
                    ? 'Enter a valid numeric budget'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Location / Ward'),
                validator: (val) =>
                    val!.isEmpty ? 'Please enter a location' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(
                  _selectedDeadline == null
                      ? 'Select Deadline Date'
                      : 'Deadline: ${_selectedDeadline!.toLocal().toString().split(' ')[0]}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDeadline,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration:
                    const InputDecoration(labelText: 'Task Description'),
                maxLines: 4,
                validator: (val) =>
                    val!.isEmpty ? 'Please enter a description' : null,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _publishTask,
                      child: const Text('Publish Task'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
