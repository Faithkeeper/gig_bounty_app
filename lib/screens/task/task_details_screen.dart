import 'package:flutter/material.dart';
import '../../data/remote/bid_service.dart';
import '../../data/remote/task_service.dart';
import '../../models/task_model.dart';
import '../../models/bid_model.dart';
import '../../models/user_profile.dart';

class TaskDetailsScreen extends StatefulWidget {
  final TaskModel task;
  final UserProfile userProfile;

  const TaskDetailsScreen(
      {super.key, required this.task, required this.userProfile});

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  final BidService _bidService = BidService();
  final TaskService _taskService = TaskService();
  final _bidFormKey = GlobalKey<FormState>();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _completionNoteController =
      TextEditingController();

  bool get _isOwner => widget.task.posterId == widget.userProfile.uid;
  bool get _isOpen => widget.task.status == 'Open';

  String _formatDate(DateTime date) =>
      date.toLocal().toString().split(' ')[0];

  @override
  void dispose() {
    _priceController.dispose();
    _noteController.dispose();
    _completionNoteController.dispose();
    super.dispose();
  }

  void _showCompletionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Complete Task Agreement'),
        content: TextField(
          controller: _completionNoteController,
          decoration: const InputDecoration(
              labelText: 'Work Summary / Completion Note'),
          maxLines: 3,
        ),
        actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final navigator = Navigator.of(dialogContext);
            final messenger = ScaffoldMessenger.maybeOf(dialogContext);
            
            await _taskService.updateTaskStatus(
              widget.task.id,
              'Completed',
              completionNote: _completionNoteController.text.trim(),
            );

            if (!mounted) return;
            
            // Safely pop just the dialog once
            if (navigator.canPop()) {
              navigator.pop();
            }

            if (messenger != null) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Task marked as Completed!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('Confirm Completion'),
        ),
],
      ),
    );
  }

  bool _isSubmitting = false;

  void _submitBid() async {
    if (_bidFormKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.maybeOf(context);
      try {
        final bidId = DateTime.now().millisecondsSinceEpoch.toString();
        final newBid = BidModel(
          id: bidId,
          taskId: widget.task.id,
          providerId: widget.userProfile.uid,
          providerName: widget.userProfile.fullName,
          proposedPrice: double.parse(_priceController.text.trim()),
          proposalNote: _noteController.text.trim(),
          providerRating: widget.userProfile.rating,
        );

        await _bidService.submitBid(newBid);
        if (!mounted) return;
        if (navigator.mounted) {
          navigator.pop();
        }
        if (messenger != null) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Bid submitted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        if (messenger != null) {
          messenger.showSnackBar(
            SnackBar(
                content: Text('Error submitting bid: $e'),
                backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _rejectBid(BidModel bid) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await _bidService.rejectBid(bid.id);
      if (mounted && messenger != null && messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Bid rejected.')),
        );
      }
    } catch (error) {
      if (mounted && messenger != null && messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error rejecting bid: $error')),
        );
      }
    }
  }

  Future<void> _acceptBid(BidModel bid) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await _bidService.acceptBid(bid, widget.task.id);
      if (mounted && messenger != null && messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Bid accepted! Task is now In Progress.'),
          ),
        );
      }
    } catch (error) {
      if (mounted && messenger != null && messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error accepting bid: $error')),
        );
      }
    }
  }

  void _showBidDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit an Offer'),
        content: Form(
          key: _bidFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _priceController,
                decoration:
                    const InputDecoration(labelText: 'Proposed Price (ZAR)'),
                keyboardType: TextInputType.number,
                validator: (val) => double.tryParse(val ?? '') == null
                    ? 'Enter valid price'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                decoration:
                    const InputDecoration(labelText: 'Pitch / Proposal Note'),
                maxLines: 3,
                validator: (val) => val!.isEmpty ? 'Enter pitch note' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          _isSubmitting
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: _submitBid, child: const Text('Submit Bid')),
        ],
      ),
    );
  }

  Future<void> _showEditTaskDialog(BuildContext context, TaskModel task) async {
    final titleController = TextEditingController(text: task.title);
    final descriptionController = TextEditingController(text: task.description);
    final budgetController =
        TextEditingController(text: task.budget.toString());
    final locationController = TextEditingController(text: task.location);
    DateTime? selectedDeadline = task.deadline;
    final formKey = GlobalKey<FormState>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);

    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Task'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Task Title'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a task title'
                        : null,
                  ),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a description'
                        : null,
                  ),
                  TextFormField(
                    controller: budgetController,
                    decoration:
                        const InputDecoration(labelText: 'Budget (ZAR)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      final budget = double.tryParse(value?.trim() ?? '');
                      return budget == null || budget <= 0
                          ? 'Enter a valid budget'
                          : null;
                    },
                  ),
                  TextFormField(
                    controller: locationController,
                    decoration:
                        const InputDecoration(labelText: 'Location / Ward'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a location'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          selectedDeadline == null
                              ? 'Deadline: Not set'
                              : 'Deadline: ${_formatDate(selectedDeadline!)}',
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final firstDate = DateTime.now();
                          final lastDate =
                              firstDate.add(const Duration(days: 365));
                          final currentDeadline = selectedDeadline;
                          final initialDate = currentDeadline == null ||
                                  currentDeadline.isBefore(firstDate)
                              ? firstDate
                              : currentDeadline.isAfter(lastDate)
                                  ? lastDate
                                  : currentDeadline;
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: initialDate,
                            firstDate: firstDate,
                            lastDate: lastDate,
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDeadline = picked);
                          }
                        },
                        child: Text(
                          selectedDeadline == null ? 'Set Date' : 'Change Date',
                        ),
                      ),
                      if (selectedDeadline != null)
                        IconButton(
                          tooltip: 'Clear deadline',
                          onPressed: () =>
                              setDialogState(() => selectedDeadline = null),
                          icon: const Icon(Icons.clear),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() != true) return;
                try {
                  await _taskService.updateTaskDetails(
                    taskId: task.id,
                    title: titleController.text.trim(),
                    description: descriptionController.text.trim(),
                    budget: double.parse(budgetController.text.trim()),
                    location: locationController.text.trim(),
                    deadline: selectedDeadline,
                  );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                } catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('Error updating task: $error')),
                    );
                  }
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );

    if (updated == true && mounted) {
      if (navigator.mounted) navigator.pop(true);
      messenger?.showSnackBar(
        const SnackBar(content: Text('Task updated successfully.')),
      );
    }
  }

  Future<void> _cancelTask() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Task?'),
        content: const Text(
          'This will permanently remove the task and its bids.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Task'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel Task'),
          ),
        ],
      ),
    );
    if (shouldCancel != true || !mounted) return;

    try {
      await _taskService.deleteTask(widget.task.id);
      if (!mounted) return;
      if (navigator.mounted) navigator.pop();
      messenger?.showSnackBar(
        const SnackBar(content: Text('Task cancelled and removed.')),
      );
    } catch (error) {
      if (mounted && messenger != null && messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error cancelling task: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCustomer = widget.userProfile.role == 'Customer';

    return Scaffold(
      appBar: AppBar(title: Text(widget.task.title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.task.title,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Category: ${widget.task.category} • Location: ${widget.task.location}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              'Deadline: ${widget.task.deadline == null ? 'Not set' : _formatDate(widget.task.deadline!)}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text('Budget: R${widget.task.budget.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 18,
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(widget.task.description),
            // Lifecycle Status Banner & Action
            if (widget.task.status == 'In Progress') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Status: In Progress\nAssigned Contractor active',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ElevatedButton(
                      onPressed: () => _showCompletionDialog(context),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green),
                      child: const Text('Mark Complete'),
                    ),
                  ],
                ),
              ),
            ] else if (widget.task.status == 'Completed') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Task Successfully Completed!',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    if (widget.task.completionNote != null) ...[
                      const SizedBox(height: 4),
                      Text('Summary: ${widget.task.completionNote}'),
                    ],
                  ],
                ),
              ),
            ],
            if (_isOwner && _isOpen) ...[
              const Divider(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      label: const Text('Edit Task'),
                      onPressed: () =>
                          _showEditTaskDialog(context, widget.task),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      label: const Text('Cancel Task'),
                      onPressed: _cancelTask,
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 32),
            const Text('Competing Bids / Offers',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<BidModel>>(
                stream: _bidService.getBidsForTask(widget.task.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                        child: Text('No bids submitted for this task yet.'));
                  }

                  final bids = snapshot.data!;
                  return ListView.builder(
                    itemCount: bids.length,
                    itemBuilder: (context, index) {
                      final bid = bids[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                              '${bid.providerName} (R${bid.proposedPrice.toStringAsFixed(2)})'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Pitch: ${bid.proposalNote}'),
                              const SizedBox(height: 4),
                            ],
                          ),
                          trailing:
                              _isOwner && _isOpen && bid.status == 'Pending'
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Reject bid',
                                          onPressed: () => _rejectBid(bid),
                                          icon: const Icon(
                                            Icons.close,
                                            color: Colors.red,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Accept bid',
                                          onPressed: () => _acceptBid(bid),
                                          icon: const Icon(
                                            Icons.check,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Chip(
                                      label: Text(bid.status,
                                          style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white)),
                                      backgroundColor: bid.status == 'Accepted'
                                          ? Colors.green
                                          : bid.status == 'Rejected'
                                              ? Colors.red
                                              : Colors.orange,
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
      ),
      floatingActionButton: !isCustomer && widget.task.status == 'Open'
          ? FloatingActionButton.extended(
              onPressed: () => _showBidDialog(context),
              icon: const Icon(Icons.gavel),
              label: const Text('Place Bid'),
            )
          : null,
    );
  }
}
