import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class FarmJobsSection extends StatefulWidget {
  const FarmJobsSection({
    required this.dio,
    required this.farmId,
    required this.role,
    required this.isOwner,
    super.key,
  });

  final Dio dio;
  final String? farmId;
  final String role;
  final bool isOwner;

  @override
  State<FarmJobsSection> createState() => _FarmJobsSectionState();
}

class _FarmJobsSectionState extends State<FarmJobsSection> {
  List<Map<String, dynamic>> _postings = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FarmJobsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.farmId != widget.farmId ||
        oldWidget.isOwner != widget.isOwner ||
        oldWidget.role != widget.role) {
      _load();
    }
  }

  Future<void> _load() async {
    final path = widget.isOwner
        ? '/farms/${widget.farmId}/job-postings'
        : '/farm-jobs';
    if (widget.isOwner && widget.farmId == null) return;
    setState(() => _loading = true);
    try {
      final response = await widget.dio.get<Map<String, dynamic>>(path);
      final data = response.data?['data'];
      if (!mounted) return;
      setState(() {
        _postings = data is List
            ? data.whereType<Map>().map(_map).toList()
            : [];
        _error = null;
      });
    } on DioException catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createPosting() async {
    final farmId = widget.farmId;
    if (farmId == null) return;
    final formKey = GlobalKey<FormState>();
    final title = TextEditingController();
    final description = TextEditingController();
    final location = TextEditingController();
    var role = 'farmWorker';
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Post a farm role'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(
                      value: 'farmWorker',
                      child: Text('Farm worker'),
                    ),
                    DropdownMenuItem(
                      value: 'farmManager',
                      child: Text('Farm manager'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => role = value ?? 'farmWorker'),
                ),
                _field(title, 'Job title'),
                _field(description, 'Describe the work', maxLines: 4),
                _field(location, 'Work location (optional)', required: false),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Publish'),
            ),
          ],
        ),
      ),
    );
    if (submitted == true) {
      try {
        await widget.dio.post<Map<String, dynamic>>(
          '/farms/$farmId/job-postings',
          data: {
            'role': role,
            'title': title.text.trim(),
            'description': description.text.trim(),
            if (location.text.trim().isNotEmpty)
              'location': location.text.trim(),
          },
        );
        await _load();
      } on DioException catch (error) {
        if (mounted) setState(() => _error = _message(error));
      }
    }
    title.dispose();
    description.dispose();
    location.dispose();
  }

  Future<void> _apply(Map<String, dynamic> posting) async {
    try {
      await widget.dio.post<Map<String, dynamic>>(
        '/farm-jobs/${posting['id']}/applications',
        data: const {},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your application has been sent.')),
        );
      }
      await _load();
    } on DioException catch (error) {
      if (mounted) setState(() => _error = _message(error));
    }
  }

  Future<void> _review(
    Map<String, dynamic> posting,
    Map<String, dynamic> application,
    String status,
  ) async {
    final farmId = widget.farmId;
    if (farmId == null) return;
    try {
      await widget.dio.patch<Map<String, dynamic>>(
        '/farms/$farmId/job-postings/${posting['id']}/applications/${application['id']}',
        data: {'status': status},
      );
      await _load();
    } on DioException catch (error) {
      if (mounted) setState(() => _error = _message(error));
    }
  }

  Future<void> _setStatus(Map<String, dynamic> posting, String status) async {
    final farmId = widget.farmId;
    if (farmId == null) return;
    try {
      await widget.dio.patch<Map<String, dynamic>>(
        '/farms/$farmId/job-postings/${posting['id']}',
        data: {'status': status},
      );
      await _load();
    } on DioException catch (error) {
      if (mounted) setState(() => _error = _message(error));
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Farm opportunities',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              if (widget.isOwner)
                FilledButton.tonalIcon(
                  onPressed: _createPosting,
                  icon: const Icon(Icons.add),
                  label: const Text('Post a role'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.isOwner
                ? 'List farm worker or farm manager openings. Accepting an applicant adds them to this farm.'
                : 'Open roles for your account type. Accepted applications join the farm.',
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_postings.isEmpty && !_loading)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('No job postings available.'),
            ),
          ..._postings.map((posting) {
            final applications = (posting['applications'] as List? ?? const [])
                .whereType<Map>()
                .map(_map)
                .toList();
            return ExpansionTile(
              leading: const Icon(Icons.work_outline),
              title: Text(posting['title']?.toString() ?? 'Farm role'),
              subtitle: Text(
                '${posting['farm_name'] ?? 'This farm'} · ${posting['role']} · ${posting['location'] ?? posting['farm_location'] ?? 'Location not set'}',
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(posting['description']?.toString() ?? ''),
                      const SizedBox(height: 8),
                      if (widget.isOwner) ...[
                        if (posting['status'] == 'open')
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _setStatus(posting, 'closed'),
                              child: const Text('Close listing'),
                            ),
                          ),
                        if (applications.isEmpty)
                          const Text('No applications yet.'),
                        ...applications.map(
                          (application) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              application['name']?.toString() ?? 'Applicant',
                            ),
                            subtitle: Text(
                              '${application['phone'] ?? application['email'] ?? ''} · ${application['status']}',
                            ),
                            trailing: application['status'] == 'pending'
                                ? Wrap(
                                    children: [
                                      IconButton(
                                        tooltip: 'Accept and add to farm',
                                        onPressed: () => _review(
                                          posting,
                                          application,
                                          'accepted',
                                        ),
                                        icon: const Icon(Icons.check),
                                      ),
                                      IconButton(
                                        tooltip: 'Reject application',
                                        onPressed: () => _review(
                                          posting,
                                          application,
                                          'rejected',
                                        ),
                                        icon: const Icon(Icons.close),
                                      ),
                                    ],
                                  )
                                : null,
                          ),
                        ),
                      ] else if (posting['status'] == 'open')
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.tonal(
                            onPressed: () => _apply(posting),
                            child: const Text('Apply'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = true,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (value) => value == null || value.trim().isEmpty ? 'Required' : null
          : null,
    ),
  );

  static Map<String, dynamic> _map(Map value) =>
      value.map((key, value) => MapEntry('$key', value));

  static String _message(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Could not load farm opportunities. Please try again.';
  }
}
