import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api.dart';

const _offlineDemoEnabled = kDebugMode &&
    bool.fromEnvironment('FARMAPP_ENABLE_OFFLINE_DEMO_LOGIN');
const _offlineDemoEmail = 'test@exampl.com';
const _offlineDemoPassword = 'Password@123';

void main() {
  runApp(const FarmAppVeterinarianApp());
}

enum AppPage {
  welcome,
  application,
  pending,
  login,
  otp,
  plans,
  payment,
  home,
  profile,
}

class AppController extends ChangeNotifier {
  AppController() : api = VetApi();

  static const _tokenKey = 'vet_access_token';
  static const _refreshTokenKey = 'vet_refresh_token';
  static const _applicationKey = 'vet_application_reference';
  static const _storage = FlutterSecureStorage();

  final VetApi api;
  AppPage page = AppPage.welcome;
  Map<String, dynamic> veterinarian = {};
  List<Map<String, dynamic>> plans = [];
  List<Map<String, dynamic>> veterinaryRequests = [];
  Map<String, dynamic>? activeVeterinaryRequest;
  Timer? _requestTimer;
  bool _loadingRequests = false;
  String? applicationReference;
  String? challengeId;
  String? otpDestination;
  String? paymentId;
  bool busy = false;
  bool isOfflineDemo = false;
  String? error;

  Future<void> initialize() async {
    final token = await _storage.read(key: _tokenKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (token != null || refreshToken != null) {
      api.setAccessToken(token);
      try {
        await _loadProfile();
        return;
      } catch (profileError) {
        if (refreshToken != null) {
          try {
            final refreshed = await api.refresh(refreshToken);
            final newAccessToken = refreshed['access_token']?.toString();
            final newRefreshToken = refreshed['refresh_token']?.toString();
            if (newAccessToken == null ||
                newAccessToken.isEmpty ||
                newRefreshToken == null ||
                newRefreshToken.isEmpty) {
              throw const FormatException(
                'The server did not return refreshed sign-in tokens.',
              );
            }
            api.setAccessToken(newAccessToken);
            await _storage.write(key: _tokenKey, value: newAccessToken);
            await _storage.write(key: _refreshTokenKey, value: newRefreshToken);
            await _loadProfile();
            return;
          } catch (refreshError) {
            error = refreshError.toString().replaceFirst('Exception: ', '');
          }
        } else {
          error = profileError.toString().replaceFirst('Exception: ', '');
        }
        isOfflineDemo = false;
        ${cfg.field} = {};
        page = AppPage.login;
        _notify();
        return;
      }
    }

    applicationReference = await _storage.read(key: _applicationKey);
    if (applicationReference != null) {
      page = AppPage.pending;
      _notify();
      await checkApproval();
    } else {
      _notify();
    }
  }

  void openApplication() => _go(AppPage.application);
  void openLogin() => _go(AppPage.login);
  void openWelcome() => _go(AppPage.welcome);
  void openHome() => _go(AppPage.home);
  void openProfile() => _go(AppPage.profile);

  Future<void> submitApplication(Map<String, dynamic> data) async {
    await _run(() async {
      final result = await api.apply(data);
      final application = _map(result['application']);
      applicationReference = application['reference']?.toString();
      if (applicationReference == null || applicationReference!.isEmpty) {
        throw const FormatException(
          'The server did not return an application reference.',
        );
      }
      await _storage.write(key: _applicationKey, value: applicationReference);
      page = AppPage.pending;
    });
  }

  Future<void> checkApproval() async {
    final reference = applicationReference;
    if (reference == null || reference.isEmpty) return;
    await _run(() async {
      final result = await api.applicationStatus(reference);
      final application = _map(result['application']);
      switch (application['status']) {
        case 'approved':
          veterinarian = application;
          page = AppPage.login;
          error =
              'Your veterinary application is approved. Sign in to continue.';
          break;
        case 'rejected':
          error =
              application['review_note']?.toString() ??
              'Your application was not approved. Please contact support.';
          break;
        case 'pending':
          error = null;
          break;
        default:
          throw const FormatException(
            'The server returned an unknown application status.',
          );
      }
    });
  }

  Future<void> beginLogin(String identifier, String password) async {
    if (_offlineDemoEnabled &&
        identifier.trim().toLowerCase() == _offlineDemoEmail &&
        password == _offlineDemoPassword) {
      isOfflineDemo = true;
      api.setAccessToken(null);
      veterinarian = {
        'status': 'approved',
      'name': 'Demo Veterinarian',
      'email': _offlineDemoEmail,
      'phone': '+254700000003',
      'clinic_name': 'FarmApp Demo Veterinary Clinic',
      'county': 'Nairobi',
      'license_number': 'DEMO-VET-001',
      'specialization': 'General veterinary practice',
      'subscription_expires_at': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
      };
      plans = [];
      veterinaryRequests = [];
      activeVeterinaryRequest = null;
      page = AppPage.home;
      error = null;
      _notify();
      return;
    }
    await _run(() async {
      final result = await api.login(identifier.trim(), password);
      if (result['otp_required'] != true || result['challenge_id'] is! String) {
        throw const FormatException(
          'The server did not return a sign-in verification challenge.',
        );
      }
      challengeId = result['challenge_id'] as String;
      otpDestination = result['destination']?.toString();
      page = AppPage.otp;
    });
  }

  Future<void> verifyOtp(String code) async {
    final challenge = challengeId;
    if (challenge == null) return;
    await _run(() async {
      final result = await api.verifyLoginOtp(challenge, code.trim());
      final accessToken = result['access_token']?.toString();
      final refreshToken = result['refresh_token']?.toString();
      if (accessToken == null ||
          accessToken.isEmpty ||
          refreshToken == null ||
          refreshToken.isEmpty) {
        throw const FormatException(
          'The server did not return valid sign-in tokens.',
        );
      }
      api.setAccessToken(accessToken);
      await _storage.write(key: _tokenKey, value: accessToken);
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
      await _loadProfile();
    });
  }

  Future<void> loadPlans() async {
    await _run(() async {
      await _loadProfile();
      if (veterinarian['status'] != 'approved') {
        throw const FormatException(
          'Your veterinary account must be approved before subscribing.',
        );
      }
    });
  }

  Future<void> requestPayment(String plan, String phone) async {
    await _run(() async {
      final result = await api.requestPayment(plan: plan, phone: phone);
      final payment = _map(result['payment']);
      paymentId = payment['id']?.toString();
      if (paymentId == null || paymentId!.isEmpty) {
        throw const FormatException(
          'The server did not return a payment reference.',
        );
      }
      page = AppPage.payment;
    });
  }

  Future<void> checkPayment() async {
    final id = paymentId;
    if (id == null) return;
    await _run(() async {
      final result = await api.payment(id);
      final payment = _map(result['payment']);
      if (payment['status'] == 'paid') {
        await _loadProfile();
        if (!hasActiveSubscription) {
          throw const FormatException(
            'Payment was received but account activation is still pending.',
          );
        }
        page = AppPage.home;
      } else if (payment['status'] == 'failed') {
        throw FormatException(
          payment['result_description']?.toString() ??
              'M-Pesa did not complete this payment. You can try again.',
        );
      }
    });
  }

  Future<void> refreshVeterinaryRequests() async {
    if (_loadingRequests || !hasActiveSubscription || page != AppPage.home) {
      return;
    }
    _loadingRequests = true;
    try {
      final response = await api.transportRequests();
      final rows = response['data'];
      veterinaryRequests = rows is List
          ? rows.whereType<Map>().map(_map).toList()
          : [];
      final active = response['active_request'];
      activeVeterinaryRequest = active is Map ? _map(active) : null;
      _notify();
    } catch (exception) {
      error = exception.toString().replaceFirst('Exception: ', '');
      _notify();
    } finally {
      _loadingRequests = false;
    }
  }

  Future<void> acceptVeterinaryRequest(String id) async {
    await _run(() async {
      final response = await api.acceptTransportRequest(id);
      activeVeterinaryRequest = _map(response['data']);
      veterinaryRequests = veterinaryRequests
          .where((request) => request['id']?.toString() != id)
          .toList();
    });
  }

  Future<void> completeVeterinaryRequest() async {
    final active = activeVeterinaryRequest;
    if (active == null) return;
    await _run(() async {
      await api.updateTransportRequestStatus(
        active['id'].toString(),
        'completed',
      );
      activeVeterinaryRequest = null;
      await refreshVeterinaryRequests();
    });
  }

  void _startRequestPolling() {
    _requestTimer?.cancel();
    unawaited(refreshVeterinaryRequests());
    _requestTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => unawaited(refreshVeterinaryRequests()),
    );
  }

  Future<void> logout() async {
    await _run(() async {
      try {
        if (!isOfflineDemo) await api.logout();
      } finally {
        api.setAccessToken(null);
        await _storage.delete(key: _tokenKey);
        await _storage.delete(key: _refreshTokenKey);
        isOfflineDemo = false;
        veterinarian = {};
        page = AppPage.login;
      }
    });
  }

  Future<void> _loadProfile() async {
    final result = await api.veterinarianProfile();
    veterinarian = _map(result['veterinarian']);
    switch (veterinarian['status']) {
      case 'pending':
        applicationReference = veterinarian['reference']?.toString();
        if (applicationReference != null) {
          await _storage.write(
            key: _applicationKey,
            value: applicationReference,
          );
        }
        page = AppPage.pending;
        break;
      case 'rejected':
        page = AppPage.pending;
        break;
      case 'approved':
        if (hasActiveSubscription) {
          page = AppPage.home;
          _startRequestPolling();
        } else {
          plans = await api.subscriptionPlans();
          if (plans.isEmpty) {
            throw const FormatException(
              'No veterinary subscription plans are available yet. Please contact support.',
            );
          }
          page = AppPage.plans;
        }
        break;
      default:
        throw const FormatException(
          'The server returned an unknown veterinary account status.',
        );
    }
  }

  bool get hasActiveSubscription {
    final expiry = DateTime.tryParse(
      veterinarian['subscription_expires_at']?.toString() ?? '',
    );
    return expiry != null && expiry.isAfter(DateTime.now());
  }

  Future<void> _run(Future<void> Function() action) async {
    busy = true;
    error = null;
    _notify();
    try {
      await action();
    } on FormatException catch (exception) {
      error = exception.message;
    } catch (exception) {
      error = exception.toString().replaceFirst('Exception: ', '');
    } finally {
      busy = false;
      _notify();
    }
  }

  void _go(AppPage next) {
    error = null;
    page = next;
    _notify();
  }

  void dismissError() {
    error = null;
    _notify();
  }

  void _notify() => notifyListeners();

  @override
  void dispose() {
    _requestTimer?.cancel();
    super.dispose();
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is! Map) return <String, dynamic>{};
    return value.map((key, value) => MapEntry('$key', value));
  }
}

class FarmAppVeterinarianApp extends StatefulWidget {
  const FarmAppVeterinarianApp({super.key});

  @override
  State<FarmAppVeterinarianApp> createState() => _FarmAppVeterinarianAppState();
}

class _FarmAppVeterinarianAppState extends State<FarmAppVeterinarianApp> {
  late final AppController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AppController();
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => MaterialApp(
      title: 'Veterinarian',
      debugShowCheckedModeBanner: false,
      theme: _theme,
      home: _page(),
    ),
  );

  Widget _page() {
    final controller = _controller;
    final error = controller.error;
    final child = switch (controller.page) {
      AppPage.welcome => WelcomePage(controller: controller),
      AppPage.application => ApplicationPage(controller: controller),
      AppPage.pending => PendingPage(controller: controller),
      AppPage.login => LoginPage(controller: controller),
      AppPage.otp => OtpPage(controller: controller),
      AppPage.plans => PlansPage(controller: controller),
      AppPage.payment => PaymentPage(controller: controller),
      AppPage.home => HomePage(controller: controller),
      AppPage.profile => ProfilePage(controller: controller),
    };
    return Stack(
      children: [
        child,
        if (controller.busy)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x44000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        if (error != null && error.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Material(
              elevation: 8,
              color: const Color(0xFF9F312C),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        error,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    IconButton(
                      onPressed: controller.dismissError,
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

final _theme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _brand,
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: const Color(0xFFF5F8F5),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFDCE6DD)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFDCE6DD)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: _brand, width: 1.6),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  ),
);

const _brand = Color(0xFF147D78);
const _ink = Color(0xFF18231C);
const _muted = Color(0xFF66746A);

class WelcomePage extends StatelessWidget {
  const WelcomePage({required this.controller, super.key});
  final AppController controller;

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
                Container(
                  width: 172,
                  height: 172,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12172F20),
                        blurRadius: 30,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.medical_services,
                    size: 120,
                    color: _brand,
                    semanticLabel: 'Veterinarian',
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Veterinarian',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 29,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'A smarter connection between pig farmers and veterinary professionals.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 34),
                PrimaryButton(
                  label: 'Apply as a veterinarian',
                  icon: Icons.medical_services_outlined,
                  onPressed: controller.openApplication,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: controller.openLogin,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
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

class ApplicationPage extends StatefulWidget {
  const ApplicationPage({required this.controller, super.key});
  final AppController controller;

  @override
  State<ApplicationPage> createState() => _ApplicationPageState();
}

class _ApplicationPageState extends State<ApplicationPage> {
  final _formKey = GlobalKey<FormState>();
  final _fields = {
    'name': TextEditingController(),
    'email': TextEditingController(),
    'phone': TextEditingController(),
    'password': TextEditingController(),
    'password_confirmation': TextEditingController(),
    'license_number': TextEditingController(),
    'clinic_name': TextEditingController(),
    'county': TextEditingController(),
    'specialization': TextEditingController(),
    'years_experience': TextEditingController(text: '0'),
  };

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormPageFrame(
    title: 'Veterinarian application',
    subtitle: 'Share your professional details for verification.',
    onBack: widget.controller.openWelcome,
    child: Form(
      key: _formKey,
      child: Column(
        children: [
          _input('name', 'Full name', Icons.person_outline),
          _input(
            'email',
            'Email address',
            Icons.mail_outline,
            keyboard: TextInputType.emailAddress,
          ),
          _input(
            'phone',
            'Phone number',
            Icons.phone_outlined,
            keyboard: TextInputType.phone,
          ),
          _input(
            'license_number',
            'Veterinary license number',
            Icons.badge_outlined,
          ),
          _input(
            'clinic_name',
            'Clinic or practice name',
            Icons.local_hospital_outlined,
          ),
          _input('county', 'County', Icons.location_on_outlined),
          _input(
            'specialization',
            'Specialization (optional)',
            Icons.medical_information_outlined,
            required: false,
          ),
          _input(
            'years_experience',
            'Years of experience',
            Icons.work_history_outlined,
            keyboard: TextInputType.number,
          ),
          _input(
            'password',
            'Password (8+ characters)',
            Icons.lock_outline,
            obscure: true,
            minLength: 8,
          ),
          _input(
            'password_confirmation',
            'Confirm password',
            Icons.lock_reset_outlined,
            obscure: true,
            matchesPassword: true,
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: 'Submit for verification',
            icon: Icons.send_outlined,
            onPressed: _submit,
          ),
          const SizedBox(height: 20),
          const Text(
            'Your account remains pending until the platform verifies your professional details.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, height: 1.45),
          ),
        ],
      ),
    ),
  );

  Widget _input(
    String key,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    bool obscure = false,
    bool required = true,
    int minLength = 1,
    bool matchesPassword = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: TextFormField(
      controller: _fields[key],
      keyboardType: keyboard,
      obscureText: obscure,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (!required && text.isEmpty) return null;
        if (text.isEmpty) return 'This field is required.';
        if (text.length < minLength) {
          return 'Use at least $minLength characters.';
        }
        if (key == 'email' &&
            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
          return 'Enter a valid email address.';
        }
        if (key == 'years_experience' && int.tryParse(text) == null) {
          return 'Enter a whole number.';
        }
        if (matchesPassword && text != _fields['password']!.text) {
          return 'Passwords do not match.';
        }
        return null;
      },
    ),
  );

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final data = <String, dynamic>{
      for (final entry in _fields.entries) entry.key: entry.value.text.trim(),
    };
    data['years_experience'] = int.parse(data['years_experience']!);
    data.remove('password_confirmation');
    await widget.controller.submitApplication({
      ...data,
      'password_confirmation': _fields['password_confirmation']!.text,
    });
  }
}

class PendingPage extends StatelessWidget {
  const PendingPage({required this.controller, super.key});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final rejected = controller.veterinarian['status'] == 'rejected';
    final approved = controller.veterinarian['status'] == 'approved';
    return StatusPageFrame(
      icon: rejected
          ? Icons.cancel_outlined
          : approved
          ? Icons.verified_outlined
          : Icons.hourglass_top_rounded,
      color: rejected ? const Color(0xFF9F312C) : _brand,
      title: rejected
          ? 'Application needs attention'
          : approved
          ? 'You’re approved'
          : 'Verification in progress',
      message: rejected
          ? (controller.veterinarian['review_note']?.toString() ??
                'Please contact support for more information.')
          : approved
          ? 'Your professional details have been approved. Sign in and choose a subscription to continue.'
          : 'We’re reviewing your veterinary license and practice details. You can check again later or sign in after approval.',
      button: rejected || approved ? 'Sign in' : 'Check application status',
      onPressed: rejected || approved
          ? controller.openLogin
          : controller.checkApproval,
      secondButton: rejected || approved ? null : 'Back to welcome',
      onSecondPressed: rejected || approved ? null : controller.openWelcome,
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({required this.controller, super.key});
  final AppController controller;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormPageFrame(
    title: 'Welcome back',
    subtitle: 'Sign in to your verified veterinary account.',
    onBack: widget.controller.openWelcome,
    child: Column(
      children: [
        TextField(
          controller: _identifier,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email or phone number',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock_outline),
          ),
          onSubmitted: (_) => _signIn(),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Continue',
          icon: Icons.arrow_forward,
          onPressed: _signIn,
        ),
        if (_offlineDemoEnabled) ...[
          const SizedBox(height: 12),
          const Text(
            'Development demo · local access only',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
          PrimaryButton(
            label: 'Continue with offline demo',
            icon: Icons.wifi_off,
            onPressed: () => widget.controller.beginLogin(
              _offlineDemoEmail,
              _offlineDemoPassword,
            ),
          ),
        ],
        const SizedBox(height: 14),
        TextButton(
          onPressed: widget.controller.openApplication,
          child: const Text('New to the platform? Apply as a veterinarian'),
        ),
      ],
    ),
  );

  Future<void> _signIn() {
    if (_identifier.text.trim().isEmpty || _password.text.isEmpty) {
      return Future<void>.value();
    }
    return widget.controller.beginLogin(_identifier.text, _password.text);
  }
}

class OtpPage extends StatefulWidget {
  const OtpPage({required this.controller, super.key});
  final AppController controller;

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormPageFrame(
    title: 'Verify it’s you',
    subtitle:
        'Enter the six-digit code sent to ${widget.controller.otpDestination ?? 'your email'}.',
    onBack: widget.controller.openLogin,
    child: Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 12,
            ),
            decoration: const InputDecoration(
              labelText: 'Verification code',
              counterText: '',
            ),
            validator: (value) =>
                RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')
                ? null
                : 'Enter the six-digit code.',
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Verify and continue',
            icon: Icons.verified_user_outlined,
            onPressed: () {
              if (_formKey.currentState?.validate() ?? false) {
                widget.controller.verifyOtp(_code.text);
              }
            },
          ),
        ],
      ),
    ),
  );
}

class PlansPage extends StatefulWidget {
  const PlansPage({required this.controller, super.key});
  final AppController controller;

  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  final _phone = TextEditingController();
  String? _selected;

  @override
  void initState() {
    super.initState();
    _phone.text = widget.controller.veterinarian['phone']?.toString() ?? '';
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPageFrame(
    title: 'Choose your subscription',
    subtitle: 'Pay securely with M-Pesa to activate your account.',
    onProfile: widget.controller.openProfile,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...widget.controller.plans.map((plan) {
          final code = plan['code']?.toString() ?? '';
          final amount = plan['amount']?.toString() ?? '';
          final currency = plan['currency']?.toString() ?? 'KES';
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => setState(() => _selected = code),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _selected == code ? _brand : const Color(0xFFDCE6DD),
                    width: _selected == code ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selected == code
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: _selected == code ? _brand : _muted,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan['name']?.toString() ?? code,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (plan['description'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              plan['description'].toString(),
                              style: const TextStyle(color: _muted),
                            ),
                          ],
                          const SizedBox(height: 7),
                          Text(
                            '$currency $amount / ${plan['duration_days'] ?? 30} days',
                            style: const TextStyle(
                              color: _brand,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'M-Pesa phone number',
            helperText:
                'You can use the number on your profile or another line.',
            prefixIcon: Icon(Icons.phone_android_outlined),
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Pay with M-Pesa',
          icon: Icons.payments_outlined,
          onPressed: _selected == null
              ? null
              : () => widget.controller.requestPayment(_selected!, _phone.text),
        ),
      ],
    ),
  );
}

class PaymentPage extends StatelessWidget {
  const PaymentPage({required this.controller, super.key});
  final AppController controller;

  @override
  Widget build(BuildContext context) => StatusPageFrame(
    icon: Icons.phone_android_outlined,
    title: 'M-Pesa request sent',
    message:
        'Complete the payment on your phone, then check the payment status here. Your account activates after the backend confirms payment.',
    button: 'Check payment status',
    onPressed: controller.checkPayment,
    secondButton: 'Back to plans',
    onSecondPressed: controller.loadPlans,
  );
}

class HomePage extends StatelessWidget {
  const HomePage({required this.controller, super.key});
  final AppController controller;

  @override
  Widget build(BuildContext context) => AppPageFrame(
    title: 'Veterinary home',
    subtitle: 'Your professional workspace.',
    onProfile: controller.openProfile,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _brand,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.verified_user_outlined,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome, ${controller.veterinarian['name'] ?? 'Veterinarian'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your account is approved and your subscription is active.',
                style: TextStyle(color: Color(0xFFE2F3E7), height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Your account',
          style: TextStyle(
            color: _ink,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        InfoTile(
          icon: Icons.local_hospital_outlined,
          label: 'Practice',
          value: controller.veterinarian['clinic_name']?.toString() ?? '—',
        ),
        InfoTile(
          icon: Icons.location_on_outlined,
          label: 'County',
          value: controller.veterinarian['county']?.toString() ?? '—',
        ),
        InfoTile(
          icon: Icons.badge_outlined,
          label: 'License',
          value: controller.veterinarian['license_number']?.toString() ?? '—',
        ),
        const SizedBox(height: 16),
        Text(
          controller.activeVeterinaryRequest == null
              ? 'Nearby farm requests'
              : 'Active farm request',
          style: const TextStyle(
            color: _ink,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (controller.activeVeterinaryRequest case final active?)
          _VeterinaryRequestCard(
            request: active,
            active: true,
            onComplete: controller.completeVeterinaryRequest,
          )
        else if (controller.veterinaryRequests.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No open requests in your county yet.',
              style: TextStyle(color: _muted),
            ),
          )
        else
          ...controller.veterinaryRequests.map(
            (request) => _VeterinaryRequestCard(
              request: request,
              onAccept: () =>
                  controller.acceptVeterinaryRequest(request['id'].toString()),
            ),
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: controller.openProfile,
          icon: const Icon(Icons.person_outline),
          label: const Text('View profile'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
      ],
    ),
  );
}

class _VeterinaryRequestCard extends StatelessWidget {
  const _VeterinaryRequestCard({
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
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${request['animal_type']} · ${request['county']}',
            style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
          ),
          if (request['farm_name'] != null)
            Text('Farm: ${request['farm_name']}'),
          if (request['animal_name']?.toString().isNotEmpty == true)
            Text('Animal: ${request['animal_name']}'),
          Text('Location: ${request['location']}'),
          Text(request['issue_description']?.toString() ?? ''),
          if (request['requester_phone'] != null)
            Text('Contact: ${request['requester_phone']}'),
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
  final AppController controller;

  @override
  Widget build(BuildContext context) => AppPageFrame(
    title: 'My profile',
    subtitle: 'Professional and account details.',
    onProfile: null,
    leading: IconButton(
      onPressed: () {
        if (!controller.hasActiveSubscription) {
          controller.loadPlans();
        } else {
          controller.openHome();
        }
      },
      icon: const Icon(Icons.arrow_back),
    ),
    child: Column(
      children: [
        CircleAvatar(
          radius: 38,
          backgroundColor: const Color(0xFFE4F0E6),
          child: Text(
            _initialFor(controller.veterinarian['name']?.toString()),
            style: const TextStyle(
              color: _brand,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 18),
        InfoTile(
          icon: Icons.person_outline,
          label: 'Name',
          value: controller.veterinarian['name']?.toString() ?? '—',
        ),
        InfoTile(
          icon: Icons.email_outlined,
          label: 'Email',
          value: controller.veterinarian['email']?.toString() ?? '—',
        ),
        InfoTile(
          icon: Icons.phone_outlined,
          label: 'Phone',
          value: controller.veterinarian['phone']?.toString() ?? '—',
        ),
        InfoTile(
          icon: Icons.badge_outlined,
          label: 'License number',
          value: controller.veterinarian['license_number']?.toString() ?? '—',
        ),
        InfoTile(
          icon: Icons.local_hospital_outlined,
          label: 'Practice',
          value: controller.veterinarian['clinic_name']?.toString() ?? '—',
        ),
        InfoTile(
          icon: Icons.location_on_outlined,
          label: 'County',
          value: controller.veterinarian['county']?.toString() ?? '—',
        ),
        InfoTile(
          icon: Icons.medical_information_outlined,
          label: 'Specialization',
          value:
              controller.veterinarian['specialization']?.toString() ??
              'Not provided',
        ),
        const SizedBox(height: 22),
        OutlinedButton.icon(
          onPressed: controller.logout,
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF9F312C),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
      ],
    ),
  );
}

class FormPageFrame extends StatelessWidget {
  const FormPageFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onBack,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      leading: IconButton(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back),
      ),
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(color: _muted, height: 1.45),
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

class AppPageFrame extends StatelessWidget {
  const AppPageFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onProfile,
    this.leading,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onProfile;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: leading,
      title: const Text(
        'Veterinarian',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
      ),
      actions: [
        if (onProfile != null)
          IconButton(
            tooltip: 'Profile',
            onPressed: onProfile,
            icon: const Icon(Icons.account_circle_outlined),
          ),
      ],
      backgroundColor: Colors.transparent,
    ),
    body: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 32),
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(color: _muted)),
              const SizedBox(height: 22),
              child,
            ],
          ),
        ),
      ),
    ),
  );
}

class StatusPageFrame extends StatelessWidget {
  const StatusPageFrame({
    required this.icon,
    required this.title,
    required this.message,
    required this.button,
    required this.onPressed,
    this.secondButton,
    this.onSecondPressed,
    this.color = _brand,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String button;
  final VoidCallback onPressed;
  final String? secondButton;
  final VoidCallback? onSecondPressed;
  final Color color;

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
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 40, color: color),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted, height: 1.5),
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: button,
                  icon: Icons.arrow_forward,
                  onPressed: onPressed,
                ),
                if (secondButton != null && onSecondPressed != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onSecondPressed,
                    child: Text(secondButton!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(label),
    style: FilledButton.styleFrom(
      backgroundColor: _brand,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
  );
}

class InfoTile extends StatelessWidget {
  const InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFFE3EAE4)),
    ),
    child: Row(
      children: [
        Icon(icon, color: _brand),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

String _initialFor(String? name) {
  final value = name?.trim() ?? '';
  return value.isEmpty
      ? 'V'
      : String.fromCharCode(value.runes.first).toUpperCase();
}
