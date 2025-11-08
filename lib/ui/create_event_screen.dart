import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cst_event_management/helpers/supabase_auth_helper.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _location = TextEditingController();

  final List<String> _categories = <String>['Sports', 'Culture', 'Literature', 'Social Events'];
  String? _selectedCategory = 'Sports';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;
  File? _image;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _image = File(image.path);
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Event'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                height: 200,
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  clipBehavior: Clip.antiAlias,
                  elevation: 2,
                  child: InkWell(
                    onTap: _pickImage,
                    child: _image != null
                        ? Image.file(_image!, fit: BoxFit.cover, width: double.infinity)
                        : Container(
                            color: Theme.of(context).colorScheme.surface,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.camera_alt_outlined, size: 48, color: Colors.grey.shade500),
                                  const SizedBox(height: 12),
                                  Text('Add Event Image', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text('Tap to select from gallery', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Event Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      const Text('Event Title', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _title,
                        decoration: InputDecoration(
                          hintText: 'Enter event title',
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Description', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _description,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Describe your event...',
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _categories.map((c) {
                            final bool selected = c == _selectedCategory;
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: ChoiceChip(
                                label: Text(c),
                                selected: selected,
                                onSelected: (_) => setState(() => _selectedCategory = c),
                                selectedColor: Theme.of(context).colorScheme.primary,
                                labelStyle: TextStyle(color: selected ? Colors.white : Theme.of(context).colorScheme.primary),
                                backgroundColor: Theme.of(context).colorScheme.surface,
                                shape: StadiumBorder(side: BorderSide(color: Theme.of(context).colorScheme.primary)),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Date & Time', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Date', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: _pickDate,
                                  child: Container(
                                    height: 50,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surface,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.today_outlined, color: Colors.grey.shade500),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _selectedDate == null
                                                ? 'Select date'
                                                : _formatDate(_selectedDate!),
                                            style: TextStyle(fontSize: 16, color: _selectedDate == null ? Colors.grey.shade600 : null),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Time', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: _pickTime,
                                  child: Container(
                                    height: 50,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surface,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.access_time, color: Colors.grey.shade500),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _selectedTime == null
                                                ? 'Select time'
                                                : _selectedTime!.format(context),
                                            style: TextStyle(fontSize: 16, color: _selectedTime == null ? Colors.grey.shade600 : null),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Location', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.place_outlined, color: Colors.grey.shade500),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _location,
                                decoration: const InputDecoration(
                                  hintText: 'Enter event location',
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading) const Padding(padding: EdgeInsets.only(bottom: 16), child: CircularProgressIndicator()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: const Text('Create Event', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  String _formatDate(DateTime d) {
    return '${_month(d.month)} ${d.day}, ${d.year}';
  }

  String _month(int m) {
    const List<String> ms = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return ms[m - 1];
    }

  Future<void> _submit() async {
    if (_title.text.isEmpty ||
        _description.text.isEmpty ||
        _location.text.isEmpty ||
        _selectedCategory == null ||
        _selectedDate == null ||
        _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authHelper = await SupabaseAuthHelper.getInstance();
      final user = await authHelper.getCurrentUser();

      if (user == null) {
        throw Exception('User not authenticated');
      }

      final eventData = {
        'title': _title.text,
        'description': _description.text,
        'location': _location.text,
        'category': _selectedCategory!,
        'date': _selectedDate!.toIso8601String(),
        'time': _selectedTime!.format(context),
        'requester_id': user.id,
        'requester_name': user.name,
        'requester_email': user.email,
      };

      await authHelper.createEvent(eventData, _image);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created successfully')),
        );
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create event: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetForm() {
    _title.clear();
    _description.clear();
    _location.clear();
    setState(() {
      _selectedCategory = 'Sports';
      _selectedDate = null;
      _selectedTime = null;
      _image = null;
    });
  }
}
