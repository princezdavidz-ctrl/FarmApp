import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'api.dart';

void main() => runApp(const PigWorldDriversApp());

enum DriverPage { welcome, register, pending, login, otp, plans, payment, home }

class DriverController extends ChangeNotifier {
  DriverController() : api = DriverApi();

  static const _storage = FlutterSecureStorage();
  static const _accessKey = 'driver_access_token';
  static const _refreshKey = 'driver_refresh_token';
  static const _applicationKey = 'driver_application_reference';

  final DriverApi api;
  DriverPage page = DriverPage.welcome;
  Map<String, dynamic> driver = {};
  List<Map<String, dynamic>> plans = [];
  List<Map<String, dynamic>> transportRequests = [];
  Map<String, dynamic>? activeTransportRequest;
  String? reference;
  String? challengeId;
  String? otpDestination;
  String? paymentId;
  bool busy = false;
  String? error;
  StreamSubscription<Position>? _locationSubscription;
  Timer? _locationHeartbeat;
  Timer? _requestPollingTimer;
  bool _refreshingLocation = false;
  bool _refreshingRequests = false;

  LatLng get position {
    final lat = double.tryParse(driver['latitude']?.toString() ?? '');
    final lng = double.tryParse(driver['longitude']?.toString() ?? '');
    if (lat == null || lng == null) return const LatLng(-1.286389, 36.817223);
    return LatLng(lat, lng);
  }

  bool get isAvailable => driver['available'] == true;

  Future<void> initialize() async {
    final token = await _storage.read(key: _accessKey);
    final refreshToken = await _storage.read(key: _refreshKey);
    if (token != null || refreshToken != null) {
      api.setAccessToken(token);
      try {
        await _loadProfile();
        notifyListeners();
        return;
      } catch (profileError) {
        if (refreshToken != null) {
          try {
            final refreshed = await api.refresh(refreshToken);
            final newAccess = refreshed['access_token']?.toString();
            final newRefresh = refreshed['refresh_token']?.toString();
            if (newAccess == null ||
                newAccess.isEmpty ||
                newRefresh == null ||
                newRefresh.isEmpty) {
              throw const FormatException(
                'The server could not refresh your sign-in.',
              );
            }
            api.setAccessToken(newAccess);
            await _storage.write(key: _accessKey, value: newAccess);
            await _storage.write(key: _refreshKey, value: newRefresh);
            await _loadProfile();
            notifyListeners();
            return;
          } catch (refreshError) {
            error = refreshError.toString().replaceFirst('Exception: ', '');
          }
        } else {
          error = profileError.toString().replaceFirst('Exception: ', '');
        }
        api.setAccessToken(null);
        await _storage.delete(key: _accessKey);
        await _storage.delete(key: _refreshKey);
        page = DriverPage.login;
        notifyListeners();
        return;
      }
    }
    reference = await _storage.read(key: _applicationKey);
    if (reference != null) {
      page = DriverPage.pending;
      notifyListeners();
      await checkApproval();
    } else {
      notifyListeners();
    }
  }

  void openPage(DriverPage next) {
    error = null;
    page = next;
    notifyListeners();
  }

  Future<void> submitApplication(Map<String, dynamic> data) async {
    await _run(() async {
      final result = await api.apply(data);
      reference = _map(result['application'])['reference']?.toString();
      if (reference == null || reference!.isEmpty) {
        throw const FormatException(
          'The server did not return an application reference.',
        );
      }
      await _storage.write(key: _applicationKey, value: reference);
      page = DriverPage.pending;
    });
  }

  Future<void> checkApproval() async {
    final savedReference = reference;
    if (savedReference == null || savedReference.isEmpty) return;
    await _run(() async {
      final application = _map(
        (await api.applicationStatus(savedReference))['application'],
      );
      switch (application['status']) {
        case 'approved':
          await _storage.delete(key: _applicationKey);
          page = DriverPage.login;
          error = 'Your driver application is approved. Sign in to continue.';
        case 'rejected':
          error =
              application['review_note']?.toString() ??
              'Your application was not approved. Please contact support.';
        case 'pending':
          error = null;
        default:
          throw const FormatException(
            'The server returned an unknown application status.',
          );
      }
    });
  }

  Future<void> beginLogin(String identifier, String password) async {
    await _run(() async {
      final result = await api.login(identifier.trim(), password);
      if (result['otp_required'] != true || result['challenge_id'] is! String) {
        throw const FormatException(
          'The server did not return a sign-in verification challenge.',
        );
      }
      challengeId = result['challenge_id'] as String;
      otpDestination = result['destination']?.toString();
      page = DriverPage.otp;
    });
  }

  Future<void> verifyOtp(String code) async {
    final challenge = challengeId;
    if (challenge == null) return;
    await _run(() async {
      final result = await api.verifyOtp(challenge, code.trim());
      final access = result['access_token']?.toString();
      final refresh = result['refresh_token']?.toString();
      if (access == null ||
          access.isEmpty ||
          refresh == null ||
          refresh.isEmpty) {
        throw const FormatException(
          'The server did not return valid sign-in tokens.',
        );
      }
      api.setAccessToken(access);
      await _storage.write(key: _accessKey, value: access);
      await _storage.write(key: _refreshKey, value: refresh);
      await _loadProfile();
    });
  }

  Future<void> loadPlans() async {
    await _run(() async {
      await _loadProfile();
      if (driver['status'] != 'approved') {
        throw const FormatException(
          'Your driver account must be approved before subscribing.',
        );
      }
      plans = await api.plans();
      if (plans.isEmpty) {
        throw const FormatException(
          'No driver subscription plans are available. Please contact support.',
        );
      }
      page = DriverPage.plans;
    });
  }

  Future<void> startPayment(String plan, String phone) async {
    await _run(() async {
      final response = await api.requestPayment(plan, phone);
      paymentId = _map(response['payment'])['id']?.toString();
      if (paymentId == null || paymentId!.isEmpty) {
        throw const FormatException(
          'The server did not return a payment reference.',
        );
      }
      page = DriverPage.payment;
    });
  }

  Future<void> checkPayment() async {
    final id = paymentId;
    if (id == null) return;
    await _run(() async {
      final payment = _map((await api.payment(id))['payment']);
      if (payment['status'] == 'paid') {
        await _loadProfile();
        if (!hasActiveSubscription) {
          throw const FormatException(
            'Payment was received but account activation is still pending.',
          );
        }
        page = DriverPage.home;
      } else if (payment['status'] == 'failed') {
        throw FormatException(
          payment['result_description']?.toString() ??
              'M-Pesa did not complete this payment. You can try again.',
        );
      }
    });
  }

  Future<void> toggleAvailability() async {
    await _run(() async {
      final available = !isAvailable;
      if (!available) await _stopLocationUpdates();
      Position? current;
      if (available) current = await _currentPosition();
      final location = current == null
          ? position
          : LatLng(current.latitude, current.longitude);
      final response = await api.updateLocation(
        latitude: location.latitude,
        longitude: location.longitude,
        available: available,
      );
      driver = {...driver, ..._map(response['driver'])};
      if (available) {
        _startLocationUpdates();
        _startRequestPolling();
      } else {
        _requestPollingTimer?.cancel();
        _requestPollingTimer = null;
        await refreshTransportRequests();
      }
    });
  }

  Future<void> refreshTransportRequests() async {
    if (_refreshingRequests || page != DriverPage.home) return;
    _refreshingRequests = true;
    try {
      final response = await api.transportRequests();
      transportRequests = _list(response['data']);
      final active = response['active_request'];
      activeTransportRequest = active is Map ? _map(active) : null;
      notifyListeners();
    } catch (exception) {
      error = exception.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    } finally {
      _refreshingRequests = false;
    }
  }

  Future<void> acceptTransportRequest(String id) async {
    await _run(() async {
      final response = await api.acceptTransportRequest(id);
      activeTransportRequest = _map(response['data']);
      transportRequests = transportRequests
          .where((request) => request['id']?.toString() != id)
          .toList();
    });
  }

  Future<void> completeTransportRequest() async {
    final request = activeTransportRequest;
    if (request == null) return;
    await _run(() async {
      await api.updateTransportRequestStatus(
        request['id'].toString(),
        'completed',
      );
      activeTransportRequest = null;
      await refreshTransportRequests();
    });
  }

  void _startRequestPolling() {
    _requestPollingTimer?.cancel();
    unawaited(refreshTransportRequests());
    if (isAvailable) {
      _requestPollingTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => unawaited(refreshTransportRequests()),
      );
    }
  }

  void _startLocationUpdates() {
    unawaited(_locationSubscription?.cancel());
    _locationHeartbeat?.cancel();
    _locationHeartbeat = Timer.periodic(
      const Duration(minutes: 5),
      (_) => unawaited(_refreshOnlineLocation()),
    );
    _locationSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 50,
          ),
        ).listen(
          (position) async {
            try {
              final response = await api.updateLocation(
                latitude: position.latitude,
                longitude: position.longitude,
                available: true,
              );
              driver = {...driver, ..._map(response['driver'])};
              notifyListeners();
            } catch (exception) {
              error = exception.toString().replaceFirst('Exception: ', '');
              notifyListeners();
            }
          },
          onError: (Object exception) {
            error = 'Location updates stopped: $exception';
            notifyListeners();
          },
        );
  }

  Future<void> _refreshOnlineLocation() async {
    if (_refreshingLocation || !isAvailable) return;
    _refreshingLocation = true;
    try {
      final current = await _currentPosition();
      final response = await api.updateLocation(
        latitude: current.latitude,
        longitude: current.longitude,
        available: true,
      );
      driver = {...driver, ..._map(response['driver'])};
      notifyListeners();
    } catch (exception) {
      error = exception.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    } finally {
      _refreshingLocation = false;
    }
  }

  Future<void> _stopLocationUpdates() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    _locationHeartbeat?.cancel();
    _locationHeartbeat = null;
  }

  Future<Position> _currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const FormatException('Turn on location services to go online.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const FormatException(
        'Allow location access to appear on the driver map.',
      );
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  Future<void> logout() async {
    await _run(() async {
      try {
        await _stopLocationUpdates();
        if (isAvailable && hasActiveSubscription) {
          await api.updateLocation(
            latitude: position.latitude,
            longitude: position.longitude,
            available: false,
          );
        }
        await api.logout();
      } finally {
        api.setAccessToken(null);
        await _stopLocationUpdates();
        await _storage.delete(key: _accessKey);
        await _storage.delete(key: _refreshKey);
        driver = {};
        page = DriverPage.login;
      }
    });
  }

  bool get hasActiveSubscription {
    final expiry = DateTime.tryParse(
      driver['subscription_expires_at']?.toString() ?? '',
    );
    return expiry != null && expiry.isAfter(DateTime.now());
  }

  Future<void> _loadProfile() async {
    driver = _map((await api.profile())['driver']);
    switch (driver['status']) {
      case 'pending':
        reference = driver['reference']?.toString();
        if (reference != null) {
          await _storage.write(key: _applicationKey, value: reference);
        }
        page = DriverPage.pending;
      case 'rejected':
        page = DriverPage.pending;
      case 'approved':
        await _storage.delete(key: _applicationKey);
        if (hasActiveSubscription) {
          page = DriverPage.home;
          if (isAvailable) _startLocationUpdates();
          _startRequestPolling();
        } else {
          plans = await api.plans();
          page = DriverPage.plans;
          if (plans.isEmpty) {
            throw const FormatException(
              'No driver subscription plans are available. Please contact support.',
            );
          }
        }
      default:
        throw const FormatException(
          'The server returned an unknown driver account status.',
        );
    }
  }

  @override
  void dispose() {
    unawaited(_locationSubscription?.cancel());
    _locationHeartbeat?.cancel();
    _requestPollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } on FormatException catch (exception) {
      error = exception.message;
    } catch (exception) {
      error = exception.toString().replaceFirst('Exception: ', '');
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is! Map) return <String, dynamic>{};
    return value.map((key, value) => MapEntry('$key', value));
  }

  static List<Map<String, dynamic>> _list(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value.whereType<Map>().map(_map).toList();
  }
}

class PigWorldDriversApp extends StatefulWidget {
  const PigWorldDriversApp({super.key});

  @override
  State<PigWorldDriversApp> createState() => _PigWorldDriversAppState();
}

class _PigWorldDriversAppState extends State<PigWorldDriversApp> {
  late final DriverController controller;

  @override
  void initState() {
    super.initState();
    controller = DriverController();
    unawaited(controller.initialize());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => MaterialApp(
      title: 'Driver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _brand),
        scaffoldBackgroundColor: const Color(0xFFF5F8F5),
      ),
      home: _buildPage(),
    ),
  );

  Widget _buildPage() {
    final page = switch (controller.page) {
      DriverPage.welcome => WelcomePage(controller: controller),
      DriverPage.register => RegistrationPage(controller: controller),
      DriverPage.pending => PendingPage(controller: controller),
      DriverPage.login => LoginPage(controller: controller),
      DriverPage.otp => OtpPage(controller: controller),
      DriverPage.plans => PlansPage(controller: controller),
      DriverPage.payment => PaymentPage(controller: controller),
      DriverPage.home => HomePage(controller: controller),
    };
    return Stack(
      children: [
        page,
        if (controller.busy)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x44000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        if (controller.error case final message?)
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: Material(
              color: const Color(0xFF9F312C),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

const _brand = Color(0xFF2D648A);
const _ink = Color(0xFF18231C);
const _muted = Color(0xFF66746A);

class WelcomePage extends StatelessWidget {
  const WelcomePage({required this.controller, super.key});
  final DriverController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.local_shipping,
                  size: 150,
                  color: _brand,
                  semanticLabel: 'Driver',
                ),
                const SizedBox(height: 24),
                const Text(
                  'Driver',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Transport livestock and animal supplies safely across your community.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, height: 1.5),
                ),
                const SizedBox(height: 32),
                _PrimaryButton(
                  label: 'Register as a driver',
                  onPressed: () => controller.openPage(DriverPage.register),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    controller.openPage(DriverPage.login);
                  },
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({required this.controller, super.key});
  final DriverController controller;

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final form = GlobalKey<FormState>();
  final fields = List.generate(9, (_) => TextEditingController());
  final services = <String>{'herd'};
  bool hidePassword = true;

  @override
  void dispose() {
    for (final field in fields) {
      field.dispose();
    }
    _capacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _FormScaffold(
    title: 'Driver registration',
    subtitle: 'Tell us about you, your vehicle, and what you can transport.',
    child: Form(
      key: form,
      child: Column(
        children: [
          _Input(fields[0], 'Full name'),
          _Input(
            fields[1],
            'Email address',
            keyboard: TextInputType.emailAddress,
          ),
          _Input(fields[2], 'Phone number', keyboard: TextInputType.phone),
          _Input(
            fields[3],
            'Password',
            obscure: hidePassword,
            suffix: IconButton(
              onPressed: () => setState(() => hidePassword = !hidePassword),
              icon: Icon(
                hidePassword ? Icons.visibility : Icons.visibility_off,
              ),
            ),
          ),
          _Input(fields[4], 'Confirm password', obscure: true),
          _Input(fields[5], 'Driver licence number'),
          _Input(fields[6], 'County'),
          _Input(fields[7], 'Vehicle type (e.g. pickup, lorry)'),
          _Input(fields[8], 'Vehicle registration number'),
          _Input(_capacity, 'Animal capacity / load details'),
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Transport services',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Herd / livestock transport'),
            value: services.contains('herd'),
            onChanged: (value) => setState(() {
              if (value == true) {
                services.add('herd');
              } else {
                services.remove('herd');
              }
            }),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Animal supplies transport'),
            value: services.contains('supplies'),
            onChanged: (value) => setState(() {
              if (value == true) {
                services.add('supplies');
              } else {
                services.remove('supplies');
              }
            }),
          ),
          const SizedBox(height: 12),
          _PrimaryButton(
            label: 'Submit for verification',
            onPressed: () {
              if (services.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Choose at least one transport service.'),
                  ),
                );
                return;
              }
              if (!form.currentState!.validate()) return;
              if (fields[3].text != fields[4].text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match.')),
                );
                return;
              }
              widget.controller.submitApplication({
                'name': fields[0].text.trim(),
                'email': fields[1].text.trim(),
                'phone': fields[2].text.trim(),
                'password': fields[3].text,
                'password_confirmation': fields[4].text,
                'driver_license_number': fields[5].text.trim(),
                'county': fields[6].text.trim(),
                'vehicle_type': fields[7].text.trim(),
                'vehicle_registration_number': fields[8].text.trim(),
                'capacity_description': _capacity.text.trim(),
                'service_types': services.toList(),
              });
            },
          ),
        ],
      ),
    ),
  );

  final _capacity = TextEditingController();
}

class PendingPage extends StatelessWidget {
  const PendingPage({required this.controller, super.key});
  final DriverController controller;

  @override
  Widget build(BuildContext context) => _StatusScaffold(
    icon: Icons.fact_check_outlined,
    title: 'Application under review',
    message:
        'Our team will verify your driver licence and vehicle details. You can check for an update here.',
    button: 'Check approval status',
    onPressed: controller.checkApproval,
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({required this.controller, super.key});
  final DriverController controller;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final identifier = TextEditingController();
  final password = TextEditingController();

  @override
  void dispose() {
    identifier.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _FormScaffold(
    title: 'Welcome back',
    subtitle: 'Sign in to open your driver map.',
    child: Column(
      children: [
        _Input(identifier, 'Email or phone'),
        _Input(password, 'Password', obscure: true),
        _PrimaryButton(
          label: 'Continue',
          onPressed: () =>
              widget.controller.beginLogin(identifier.text, password.text),
        ),
      ],
    ),
  );
}

class OtpPage extends StatefulWidget {
  const OtpPage({required this.controller, super.key});
  final DriverController controller;

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final code = TextEditingController();

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _FormScaffold(
    title: 'Verify your sign-in',
    subtitle:
        'Enter the one-time code sent to ${widget.controller.otpDestination ?? 'your contact'}.',
    child: Column(
      children: [
        _Input(code, 'Verification code', keyboard: TextInputType.number),
        _PrimaryButton(
          label: 'Verify and sign in',
          onPressed: () => widget.controller.verifyOtp(code.text),
        ),
      ],
    ),
  );
}

class PlansPage extends StatefulWidget {
  const PlansPage({required this.controller, super.key});
  final DriverController controller;

  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  final phone = TextEditingController();
  String? selected;

  @override
  void dispose() {
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _FormScaffold(
    title: 'Activate your driver account',
    subtitle:
        'Choose a plan. Your location becomes visible to customers after payment is confirmed.',
    child: Column(
      children: [
        ...widget.controller.plans.map((plan) {
          final code = plan['code'].toString();
          return Card(
            child: ListTile(
              onTap: () => setState(() => selected = code),
              title: Text(plan['name']?.toString() ?? code),
              subtitle: Text(
                '${plan['currency'] ?? 'KES'} ${plan['amount']} · ${plan['duration_days']} days',
              ),
              trailing: Icon(
                selected == code
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: selected == code ? _brand : _muted,
              ),
            ),
          );
        }),
        _Input(phone, 'M-Pesa phone number', keyboard: TextInputType.phone),
        _PrimaryButton(
          label: 'Pay with M-Pesa',
          onPressed: selected == null
              ? null
              : () => widget.controller.startPayment(selected!, phone.text),
        ),
      ],
    ),
  );
}

class PaymentPage extends StatelessWidget {
  const PaymentPage({required this.controller, super.key});
  final DriverController controller;

  @override
  Widget build(BuildContext context) => _StatusScaffold(
    icon: Icons.phone_android_outlined,
    title: 'M-Pesa request sent',
    message:
        'Complete the payment on your phone, then check the status. Your account activates after the backend confirms payment.',
    button: 'Check payment status',
    onPressed: controller.checkPayment,
  );
}

class HomePage extends StatefulWidget {
  const HomePage({required this.controller, super.key});
  final DriverController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MapController _mapController = MapController();
  LatLng? _lastPosition;

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = widget.controller.position;
    if (_lastPosition != current) {
      _lastPosition = current;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(current, 13);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final point = controller.position;
    final services = (controller.driver['service_types'] as List? ?? const [])
        .map(
          (service) => service.toString() == 'herd'
              ? 'Herd transport'
              : 'Animal supplies',
        )
        .join(' · ');
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: point,
              initialZoom: 13,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.drivers',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: point,
                    width: 58,
                    height: 58,
                    child: Container(
                      decoration: BoxDecoration(
                        color: controller.isAvailable
                            ? _brand
                            : Colors.blueGrey,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 8),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_shipping,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.local_shipping_outlined, color: _brand),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              controller.driver['name']?.toString() ??
                                  'Driver map',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              services.isEmpty
                                  ? 'Transport services'
                                  : services,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Profile',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProfilePage(controller: controller),
                      ),
                    ),
                    icon: const Icon(Icons.person_outline),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: Card(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          controller.isAvailable
                              ? Icons.radar
                              : Icons.location_disabled_outlined,
                          color: controller.isAvailable ? _brand : _muted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            controller.isAvailable
                                ? 'You are visible on the driver map'
                                : 'You are offline',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Switch(
                          value: controller.isAvailable,
                          activeThumbColor: _brand,
                          onChanged: (_) => controller.toggleAvailability(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      controller.isAvailable
                          ? 'Nearby requests for your vehicle appear here while you are online.'
                          : 'Go online to receive nearby transport requests.',
                      style: const TextStyle(color: _muted, height: 1.4),
                    ),
                    if (controller.activeTransportRequest case final active?)
                      _TransportRequestCard(
                        request: active,
                        active: true,
                        onComplete: controller.completeTransportRequest,
                      )
                    else if (controller.transportRequests.isNotEmpty)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 190),
                        child: ListView(
                          shrinkWrap: true,
                          children: controller.transportRequests
                              .map(
                                (request) => _TransportRequestCard(
                                  request: request,
                                  onAccept: () =>
                                      controller.acceptTransportRequest(
                                        request['id'].toString(),
                                      ),
                                ),
                              )
                              .toList(),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          controller.isAvailable
                              ? 'No nearby matching requests yet.'
                              : 'You have no active transport request.',
                          style: const TextStyle(color: _muted),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransportRequestCard extends StatelessWidget {
  const _TransportRequestCard({
    required this.request,
    this.active = false,
    this.onAccept,
    this.onComplete,
  });

  final Map<String, dynamic> request;
  final bool active;
  final VoidCallback? onAccept;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFFF5F8F5),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${request['vehicle_type']} · ${request['service_type']}',
            style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
          ),
          Text(
            '${request['pickup_address']} → ${request['destination_address']}',
            style: const TextStyle(color: _muted),
          ),
          if (request['load_description']?.toString().isNotEmpty == true)
            Text(
              'Load: ${request['load_description']}',
              style: const TextStyle(color: _muted),
            ),
          if (request['distance_km'] != null)
            Text(
              'Pickup ${request['distance_km']} km away',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          if (request['requester_name'] != null)
            Text(
              'Requested by ${request['requester_name']} · ${request['requester_phone'] ?? ''}',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: active
                ? TextButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Mark complete'),
                  )
                : FilledButton.tonal(
                    onPressed: onAccept,
                    child: const Text('Accept request'),
                  ),
          ),
        ],
      ),
    ),
  );
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({required this.controller, super.key});
  final DriverController controller;

  @override
  Widget build(BuildContext context) => _FormScaffold(
    title: 'Driver profile',
    subtitle: 'Your approved transport and vehicle details.',
    child: Column(
      children: [
        _InfoRow('Driver', controller.driver['name']),
        _InfoRow('Phone', controller.driver['phone']),
        _InfoRow('County', controller.driver['county']),
        _InfoRow(
          'Services',
          (controller.driver['service_types'] as List? ?? const []).join(', '),
        ),
        _InfoRow('Vehicle', controller.driver['vehicle_type']),
        _InfoRow(
          'Registration',
          controller.driver['vehicle_registration_number'],
        ),
        _InfoRow('Load capacity', controller.driver['capacity_description']),
        _InfoRow(
          'Subscription expires',
          controller.driver['subscription_expires_at'],
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () {
            controller.openPage(DriverPage.home);
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.map_outlined),
          label: const Text('Back to map'),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            await controller.logout();
            if (context.mounted) Navigator.of(context).pop();
          },
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
      ],
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label, style: const TextStyle(color: _muted, fontSize: 13)),
    subtitle: Text(
      value?.toString() ?? '—',
      style: const TextStyle(color: _ink),
    ),
  );
}

class _FormScaffold extends StatelessWidget {
  const _FormScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Driver')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(color: _muted, height: 1.5),
              ),
              const SizedBox(height: 24),
              child,
            ],
          ),
        ),
      ),
    ),
  );
}

class _StatusScaffold extends StatelessWidget {
  const _StatusScaffold({
    required this.icon,
    required this.title,
    required this.message,
    required this.button,
    required this.onPressed,
  });
  final IconData icon;
  final String title;
  final String message;
  final String button;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 64, color: _brand),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, height: 1.5),
              ),
              const SizedBox(height: 24),
              _PrimaryButton(label: button, onPressed: onPressed),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Input extends StatelessWidget {
  const _Input(
    this.controller,
    this.label, {
    this.keyboard,
    this.obscure = false,
    this.suffix,
  });
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboard;
  final bool obscure;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      validator: (value) => value == null || value.trim().isEmpty
          ? 'This field is required.'
          : null,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    ),
  );
}
