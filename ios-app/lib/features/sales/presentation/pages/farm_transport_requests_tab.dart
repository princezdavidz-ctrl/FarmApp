import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class FarmTransportRequestsTab extends StatefulWidget {
  const FarmTransportRequestsTab({
    required this.dio,
    required this.farmId,
    required this.canRequest,
    this.farmLocation,
    this.latitude,
    this.longitude,
    super.key,
  });

  final Dio dio;
  final String? farmId;
  final bool canRequest;
  final String? farmLocation;
  final double? latitude;
  final double? longitude;

  @override
  State<FarmTransportRequestsTab> createState() =>
      _FarmTransportRequestsTabState();
}

class _FarmTransportRequestsTabState extends State<FarmTransportRequestsTab> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void didUpdateWidget(covariant FarmTransportRequestsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.farmId != widget.farmId) _loadRequests();
  }

  Future<void> _loadRequests() async {
    final farmId = widget.farmId;
    if (farmId == null) return;
    setState(() => _loading = true);
    try {
      final response = await widget.dio.get<Map<String, dynamic>>(
        '/farms/$farmId/transport-requests',
      );
      final rows = response.data?['data'];
      if (!mounted) return;
      setState(() {
        _requests = rows is List
            ? rows.whereType<Map>().map(_asMap).toList()
            : [];
        _error = null;
      });
    } on DioException catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createRequest() async {
    final farmId = widget.farmId;
    if (farmId == null || !widget.canRequest) return;
    final formKey = GlobalKey<FormState>();
    final vehicle = TextEditingController();
    final pickupAddress = TextEditingController(text: widget.farmLocation);
    final pickupLat = TextEditingController(
      text: widget.latitude?.toString() ?? '',
    );
    final pickupLng = TextEditingController(
      text: widget.longitude?.toString() ?? '',
    );
    final destinationAddress = TextEditingController();
    final destinationLat = TextEditingController();
    final destinationLng = TextEditingController();
    final load = TextEditingController();
    var serviceType = 'herd';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Request transport'),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: serviceType,
                      decoration: const InputDecoration(labelText: 'Service'),
                      items: const [
                        DropdownMenuItem(
                          value: 'herd',
                          child: Text('Livestock'),
                        ),
                        DropdownMenuItem(
                          value: 'supplies',
                          child: Text('Supplies'),
                        ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => serviceType = value ?? 'herd'),
                    ),
                    _field(vehicle, 'Required vehicle type'),
                    _field(pickupAddress, 'Pickup address'),
                    Row(
                      children: [
                        Expanded(child: _field(pickupLat, 'Pickup latitude')),
                        const SizedBox(width: 8),
                        Expanded(child: _field(pickupLng, 'Pickup longitude')),
                      ],
                    ),
                    _field(destinationAddress, 'Destination address'),
                    Row(
                      children: [
                        Expanded(
                          child: _field(destinationLat, 'Destination latitude'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _field(
                            destinationLng,
                            'Destination longitude',
                          ),
                        ),
                      ],
                    ),
                    _field(load, 'Load details (optional)', required: false),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'A matching online driver within 25 km can accept this request.',
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
              child: const Text('Find a driver'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) {
      for (final controller in [
        vehicle,
        pickupAddress,
        pickupLat,
        pickupLng,
        destinationAddress,
        destinationLat,
        destinationLng,
        load,
      ]) {
        controller.dispose();
      }
      return;
    }

    try {
      await widget.dio.post<Map<String, dynamic>>(
        '/farms/$farmId/transport-requests',
        data: {
          'service_type': serviceType,
          'vehicle_type': vehicle.text.trim(),
          'pickup_address': pickupAddress.text.trim(),
          'pickup_latitude': double.parse(pickupLat.text.trim()),
          'pickup_longitude': double.parse(pickupLng.text.trim()),
          'destination_address': destinationAddress.text.trim(),
          'destination_latitude': double.parse(destinationLat.text.trim()),
          'destination_longitude': double.parse(destinationLng.text.trim()),
          if (load.text.trim().isNotEmpty) 'load_description': load.text.trim(),
          'radius_km': 25,
        },
      );
      await _loadRequests();
    } on DioException catch (error) {
      if (mounted) {
        setState(() => _error = _message(error));
      }
    } on FormatException {
      if (mounted)
        setState(
          () => _error = 'Enter valid pickup and destination coordinates.',
        );
    } finally {
      for (final controller in [
        vehicle,
        pickupAddress,
        pickupLat,
        pickupLng,
        destinationAddress,
        destinationLat,
        destinationLng,
        load,
      ]) {
        controller.dispose();
      }
    }
  }

  Future<void> _cancelRequest(String id) async {
    try {
      await widget.dio.post<Map<String, dynamic>>(
        '/transport-requests/$id/status',
        data: {'status': 'cancelled'},
      );
      await _loadRequests();
    } on DioException catch (error) {
      if (mounted) setState(() => _error = _message(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.farmId == null) {
      return const Center(child: Text('Select a farm to request transport.'));
    }
    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.local_shipping_outlined),
              title: const Text('Find nearby transport'),
              subtitle: const Text(
                'Requests are matched by service, exact vehicle type, distance, and current driver availability.',
              ),
              trailing: widget.canRequest
                  ? FilledButton(
                      onPressed: _createRequest,
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
              child: Text('No transport requests yet.'),
            ),
          ..._requests.map((request) {
            final id = request['id']?.toString() ?? '';
            final status = request['status']?.toString() ?? 'open';
            return Card(
              child: ListTile(
                leading: const Icon(Icons.local_shipping),
                title: Text(
                  '${request['vehicle_type']} · ${request['service_type']}',
                ),
                subtitle: Text(
                  '${request['pickup_address']} → ${request['destination_address']}\nStatus: $status',
                ),
                isThreeLine: true,
                trailing: status == 'open'
                    ? IconButton(
                        tooltip: 'Cancel request',
                        onPressed: () => _cancelRequest(id),
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
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (value) => value == null || value.trim().isEmpty ? 'Required' : null
          : null,
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
    return 'Could not contact the transport service. Please try again.';
  }
}
