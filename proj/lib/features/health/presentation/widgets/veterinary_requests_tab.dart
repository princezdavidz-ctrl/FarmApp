import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class VeterinaryRequestsTab extends StatefulWidget {
  const VeterinaryRequestsTab({
    required this.dio,
    required this.farmId,
    required this.county,
    required this.canRequest,
    super.key,
  });

  final Dio dio;
  final String? farmId;
  final String? county;
  final bool canRequest;

  @override
  State<VeterinaryRequestsTab> createState() => _VeterinaryRequestsTabState();
}

class _VeterinaryRequestsTabState extends State<VeterinaryRequestsTab> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant VeterinaryRequestsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.farmId != widget.farmId) _load();
  }

  Future<void> _load() async {
    final farmId = widget.farmId;
    if (farmId == null) return;
    setState(() => _loading = true);
    try {
      final response = await widget.dio.get<Map<String, dynamic>>(
        '/farms/$farmId/veterinary-requests',
      );
      final data = response.data?['data'];
      if (!mounted) return;
      setState(() {
        _requests = data is List
            ? data.whereType<Map>().map(_asMap).toList()
            : [];
        _error = null;
      });
    } on DioException catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final farmId = widget.farmId;
    if (farmId == null || !widget.canRequest) return;
    final formKey = GlobalKey<FormState>();
    final animalType = TextEditingController();
    final animalName = TextEditingController();
    final issue = TextEditingController();
    final location = TextEditingController();
    final county = TextEditingController(text: widget.county);
    final latitude = TextEditingController();
    final longitude = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request veterinary help'),
        content: SizedBox(
          width: 480,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field(animalType, 'Animal type (e.g. cattle, poultry)'),
                  _field(
                    animalName,
                    'Animal or group name (optional)',
                    required: false,
                  ),
                  _field(issue, 'Describe the health issue', maxLines: 3),
                  _field(location, 'Farm location'),
                  _field(county, 'County'),
                  _field(latitude, 'Latitude (optional)', required: false),
                  _field(longitude, 'Longitude (optional)', required: false),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Approved veterinarians in your county can view and accept this request.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
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
            child: const Text('Send request'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await widget.dio.post<Map<String, dynamic>>(
          '/farms/$farmId/veterinary-requests',
          data: {
            'county': county.text.trim(),
            'animal_type': animalType.text.trim(),
            if (animalName.text.trim().isNotEmpty)
              'animal_name': animalName.text.trim(),
            'issue_description': issue.text.trim(),
            'location': location.text.trim(),
            if (latitude.text.trim().isNotEmpty &&
                longitude.text.trim().isNotEmpty) ...{
              'latitude': double.parse(latitude.text.trim()),
              'longitude': double.parse(longitude.text.trim()),
            },
          },
        );
        await _load();
      } on DioException catch (error) {
        if (mounted) setState(() => _error = _message(error));
      }
    }
    for (final controller in [
      animalType,
      animalName,
      issue,
      location,
      county,
      latitude,
      longitude,
    ]) {
      controller.dispose();
    }
  }

  Future<void> _cancel(String id) async {
    try {
      await widget.dio.post<Map<String, dynamic>>(
        '/veterinary-requests/$id/status',
        data: {'status': 'cancelled'},
      );
      await _load();
    } on DioException catch (error) {
      if (mounted) setState(() => _error = _message(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.farmId == null) {
      return const Center(
        child: Text('Select a farm to request veterinary help.'),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.medical_services_outlined),
              title: const Text('Contact a veterinarian'),
              subtitle: const Text(
                'Send a health request to approved veterinarians serving your county.',
              ),
              trailing: widget.canRequest
                  ? FilledButton(
                      onPressed: _create,
                      child: const Text('Request'),
                    )
                  : null,
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!),
              ),
            ),
          if (_requests.isEmpty && !_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No veterinary requests yet.'),
            ),
          ..._requests.map((request) {
            final id = request['id']?.toString() ?? '';
            final status = request['status']?.toString() ?? 'open';
            final vetName = request['veterinarian_name'];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.medical_services_outlined),
                title: Text('${request['animal_type']} · $status'),
                subtitle: Text(
                  '${request['issue_description']}\n${request['location']}'
                  '${vetName == null ? '' : '\nVeterinarian: $vetName'}',
                ),
                isThreeLine: true,
                trailing: status == 'open'
                    ? IconButton(
                        tooltip: 'Cancel request',
                        onPressed: () => _cancel(id),
                        icon: const Icon(Icons.cancel_outlined),
                      )
                    : null,
              ),
            );
          }),
        ],
      ),
    );
  }

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
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty)) {
          return 'Required';
        }
        if (value != null &&
            value.trim().isNotEmpty &&
            (label == 'Latitude (optional)' ||
                label == 'Longitude (optional)')) {
          final coordinate = double.tryParse(value.trim());
          final limit = label.startsWith('Latitude') ? 90 : 180;
          if (coordinate == null ||
              !coordinate.isFinite ||
              coordinate < -limit ||
              coordinate > limit) {
            return 'Enter a valid coordinate';
          }
        }
        return null;
      },
    ),
  );

  static Map<String, dynamic> _asMap(Map value) =>
      value.map((key, value) => MapEntry('$key', value));

  static String _message(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    if (data is Map && data['errors'] is Map) {
      for (final messages in (data['errors'] as Map).values) {
        if (messages is List && messages.isNotEmpty) {
          return messages.first.toString();
        }
      }
    }
    return 'Could not contact the veterinary service. Please try again.';
  }
}
