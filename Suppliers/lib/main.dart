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
  runApp(const FarmAppSupplierApp());
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
  productForm,
}

class AppController extends ChangeNotifier {
  AppController() : api = SupplierApi();

  static const _tokenKey = 'supplier_access_token';
  static const _refreshTokenKey = 'supplier_refresh_token';
  static const _applicationKey = 'supplier_application_reference';
  static const _storage = FlutterSecureStorage();

  final SupplierApi api;
  AppPage page = AppPage.welcome;
  Map<String, dynamic> supplier = {};
  List<Map<String, dynamic>> plans = [];
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> transportRequests = [];
  Map<String, dynamic>? editingProduct;
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
        supplier = {};
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
  void openProductForm([Map<String, dynamic>? product]) {
    editingProduct = product;
    _go(AppPage.productForm);
  }

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
          supplier = application;
          page = AppPage.login;
          error = 'Your supplier application is approved. Sign in to continue.';
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
      supplier = {
        'status': 'approved',
      'name': 'Demo Supplier',
      'business_name': 'FarmApp Demo Supplies',
      'email': _offlineDemoEmail,
      'phone': '+254700000002',
      'county': 'Nairobi',
      'business_type': 'Animal feed and farm supplies',
      'subscription_expires_at': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
      };
      plans = [];
      products = [{'id': 'demo-feed-1', 'name': 'Demo livestock feed', 'price': 2500, 'stock': 25}, {'id': 'demo-vaccine-1', 'name': 'Demo animal supplement', 'price': 1200, 'stock': 40}];
      transportRequests = [];
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
      if (supplier['status'] != 'approved') {
        throw const FormatException(
          'Your supplier account must be approved before subscribing.',
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

  Future<void> loadProducts() async {
    await _run(() async {
      await _loadProfile();
      if (!hasActiveSubscription) {
        throw const FormatException(
          'An active supplier subscription is required to manage listings.',
        );
      }
      products = await api.products();
      page = AppPage.home;
    });
  }

  Future<void> saveProduct(Map<String, dynamic> data) async {
    await _run(() async {
      final current = editingProduct;
      if (current == null) {
        await api.createProduct(data);
      } else {
        await api.updateProduct(current['id'].toString(), data);
      }
      products = await api.products();
      page = AppPage.home;
      editingProduct = null;
    });
  }

  Future<void> toggleProduct(Map<String, dynamic> product) async {
    await _run(() async {
      await api.updateProduct(product['id'].toString(), {
        'active': product['active'] != true,
      });
      products = await api.products();
    });
  }

  Future<void> createTransportRequest(Map<String, dynamic> data) async {
    await _run(() async {
      await api.createTransportRequest(data);
      transportRequests = await api.transportRequests();
    });
  }

  Future<void> refreshTransportRequests() async {
    await _run(() async {
      transportRequests = await api.transportRequests();
    });
  }

  Future<void> cancelTransportRequest(Map<String, dynamic> request) async {
    await _run(() async {
      final id = request['id']?.toString();
      if (id == null || id.isEmpty) {
        throw const FormatException(
          'The server returned a transport request without an ID.',
        );
      }
      await api.updateTransportRequestStatus(id, 'cancelled');
      transportRequests = await api.transportRequests();
    });
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
        supplier = {};
        page = AppPage.login;
      }
    });
  }

  Future<void> _loadProfile() async {
    final result = await api.supplierProfile();
    supplier = _map(result['supplier']);
    switch (supplier['status']) {
      case 'pending':
        applicationReference = supplier['reference']?.toString();
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
          products = await api.products();
          transportRequests = await api.transportRequests();
          page = AppPage.home;
        } else {
          plans = await api.subscriptionPlans();
          if (plans.isEmpty) {
            throw const FormatException(
              'No supplier subscription plans are available yet. Please contact support.',
            );
          }
          page = AppPage.plans;
        }
        break;
      default:
        throw const FormatException(
          'The server returned an unknown supplier account status.',
        );
    }
  }

  bool get hasActiveSubscription {
    final expiry = DateTime.tryParse(
      supplier['subscription_expires_at']?.toString() ?? '',
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

  static Map<String, dynamic> _map(dynamic value) {
    if (value is! Map) return <String, dynamic>{};
    return value.map((key, value) => MapEntry('$key', value));
  }
}

class FarmAppSupplierApp extends StatefulWidget {
  const FarmAppSupplierApp({super.key});

  @override
  State<FarmAppSupplierApp> createState() => _FarmAppSupplierAppState();
}

class _FarmAppSupplierAppState extends State<FarmAppSupplierApp> {
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
      title: 'Supplier',
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
      AppPage.productForm => ProductFormPage(controller: controller),
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

const _brand = Color(0xFF9A631D);
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
                    Icons.storefront,
                    size: 120,
                    color: _brand,
                    semanticLabel: 'Supplier',
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Supplier',
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
                  'Reach pig farmers with the feed, medicines, and livestock products they need.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 34),
                PrimaryButton(
                  label: 'Register as a supplier',
                  icon: Icons.storefront_outlined,
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
    'business_registration_number': TextEditingController(),
    'business_name': TextEditingController(),
    'county': TextEditingController(),
    'product_categories': TextEditingController(),
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
    title: 'Supplier registration',
    subtitle: 'Tell us about your business and the animal products you sell.',
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
            'business_registration_number',
            'Business registration number',
            Icons.badge_outlined,
          ),
          _input(
            'business_name',
            'Business or shop name',
            Icons.storefront_outlined,
          ),
          _input('county', 'County', Icons.location_on_outlined),
          _input(
            'product_categories',
            'Products sold (e.g. feed, medicine, equipment)',
            Icons.inventory_2_outlined,
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
            'Your seller account remains pending until the platform verifies your business details.',
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
    final rejected = controller.supplier['status'] == 'rejected';
    final approved = controller.supplier['status'] == 'approved';
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
          ? (controller.supplier['review_note']?.toString() ??
                'Please contact support for more information.')
          : approved
          ? 'Your professional details have been approved. Sign in and choose a subscription to continue.'
          : 'We’re reviewing your business registration and product details. You can check again later or sign in after approval.',
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
  void initState() {
    super.initState();
    if (_offlineDemoEnabled) {
      _identifier.text = _offlineDemoEmail;
      _password.text = _offlineDemoPassword;
    }
  }

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormPageFrame(
    title: 'Welcome back',
    subtitle: 'Sign in to your verified supplier account.',
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
              _identifier.text,
              _password.text,
            ),
          ),
        ],
        const SizedBox(height: 14),
        TextButton(
          onPressed: widget.controller.openApplication,
          child: const Text('New to the platform? Register as a supplier'),
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
    _phone.text = widget.controller.supplier['phone']?.toString() ?? '';
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
    title: 'Supplier dashboard',
    subtitle: 'Manage your animal product listings.',
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
                Icons.storefront_outlined,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome, ${controller.supplier['business_name'] ?? controller.supplier['name'] ?? 'Supplier'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your seller account is approved and the subscription is active.',
                style: TextStyle(color: Color(0xFFE2F3E7), height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Business details',
          style: TextStyle(
            color: _ink,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        InfoTile(
          icon: Icons.storefront_outlined,
          label: 'Business',
          value: controller.supplier['business_name']?.toString() ?? '—',
        ),
        InfoTile(
          icon: Icons.location_on_outlined,
          label: 'County',
          value: controller.supplier['county']?.toString() ?? '—',
        ),
        InfoTile(
          icon: Icons.inventory_2_outlined,
          label: 'Products sold',
          value: controller.supplier['product_categories']?.toString() ?? '—',
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.local_shipping_outlined, color: _brand),
            title: const Text(
              'Request supplies transport',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Find an online driver nearby with the vehicle you need.',
            ),
            trailing: FilledButton(
              onPressed: () =>
                  _showSupplierTransportDialog(context, controller),
              child: const Text('Request'),
            ),
          ),
        ),
        if (controller.transportRequests.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Transport requests',
                style: TextStyle(
                  color: _ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                tooltip: 'Refresh transport requests',
                onPressed: controller.busy
                    ? null
                    : controller.refreshTransportRequests,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          ...controller.transportRequests.map(
            (request) => ListTile(
              leading: const Icon(Icons.local_shipping_outlined),
              title: Text('${request['vehicle_type']} · ${request['status']}'),
              subtitle: Text(
                '${request['pickup_address']} → ${request['destination_address']}'
                '${request['driver_name'] == null ? '' : '\nDriver: ${request['driver_name']} · ${request['driver_phone'] ?? ''}'}',
              ),
              isThreeLine: request['driver_name'] != null,
              trailing: request['status'] == 'open'
                  ? IconButton(
                      tooltip: 'Cancel transport request',
                      onPressed: controller.busy
                          ? null
                          : () => _confirmCancelTransportRequest(
                              context,
                              controller,
                              request,
                            ),
                      icon: const Icon(Icons.cancel_outlined),
                    )
                  : null,
            ),
          ),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Product listings',
              style: TextStyle(
                color: _ink,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton.icon(
              onPressed: controller.openProductForm,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        if (controller.products.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text(
              'No products yet. Add your first listing to get started.',
              style: TextStyle(color: _muted),
            ),
          )
        else
          ...controller.products.map(
            (product) => ProductTile(
              product: product,
              onTap: () => controller.openProductForm(product),
              onToggle: () => controller.toggleProduct(product),
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

Future<void> _confirmCancelTransportRequest(
  BuildContext context,
  AppController controller,
  Map<String, dynamic> request,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Cancel transport request?'),
      content: const Text(
        'Only requests that have not yet been accepted can be cancelled.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Keep request'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Cancel request'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await controller.cancelTransportRequest(request);
  }
}

Future<void> _showSupplierTransportDialog(
  BuildContext context,
  AppController controller,
) async {
  final formKey = GlobalKey<FormState>();
  final vehicle = TextEditingController();
  final pickupAddress = TextEditingController(
    text: controller.supplier['county']?.toString(),
  );
  final pickupLat = TextEditingController();
  final pickupLng = TextEditingController();
  final destinationAddress = TextEditingController();
  final destinationLat = TextEditingController();
  final destinationLng = TextEditingController();
  final load = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Request supplies transport'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in [
                  (vehicle, 'Required vehicle type'),
                  (pickupAddress, 'Pickup address'),
                  (pickupLat, 'Pickup latitude'),
                  (pickupLng, 'Pickup longitude'),
                  (destinationAddress, 'Destination address'),
                  (destinationLat, 'Destination latitude'),
                  (destinationLng, 'Destination longitude'),
                  (load, 'Load details (optional)'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextFormField(
                      controller: entry.$1,
                      decoration: InputDecoration(labelText: entry.$2),
                      validator: (value) {
                        if (entry.$1 == load) return null;
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        if (entry.$1 == pickupLat ||
                            entry.$1 == pickupLng ||
                            entry.$1 == destinationLat ||
                            entry.$1 == destinationLng) {
                          final coordinate = double.tryParse(value.trim());
                          if (coordinate == null || !coordinate.isFinite) {
                            return 'Enter a valid coordinate';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                const Text(
                  'Matching is based on the requested vehicle and a 25 km pickup radius.',
                  style: TextStyle(fontSize: 12),
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
  );
  if (confirmed == true) {
    await controller.createTransportRequest({
      'service_type': 'supplies',
      'vehicle_type': vehicle.text.trim(),
      'pickup_address': pickupAddress.text.trim(),
      'pickup_latitude': double.parse(pickupLat.text.trim()),
      'pickup_longitude': double.parse(pickupLng.text.trim()),
      'destination_address': destinationAddress.text.trim(),
      'destination_latitude': double.parse(destinationLat.text.trim()),
      'destination_longitude': double.parse(destinationLng.text.trim()),
      if (load.text.trim().isNotEmpty) 'load_description': load.text.trim(),
      'radius_km': 25,
    });
  }
  for (final textController in [
    vehicle,
    pickupAddress,
    pickupLat,
    pickupLng,
    destinationAddress,
    destinationLat,
    destinationLng,
    load,
  ]) {
    textController.dispose();
  }
}

class ProductTile extends StatelessWidget {
  const ProductTile({
    required this.product,
    required this.onTap,
    required this.onToggle,
    super.key,
  });

  final Map<String, dynamic> product;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFE3EAE4)),
    ),
    child: ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFE4F0E6),
        child: Icon(
          _categoryIcon(product['category']?.toString()),
          color: _brand,
        ),
      ),
      title: Text(
        product['name']?.toString() ?? 'Product',
        style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
      ),
      subtitle: Text(
        '${product['category'] ?? 'Animal product'} · ${product['currency'] ?? 'KES'} ${product['price'] ?? '—'} / ${product['unit'] ?? 'unit'} · Stock ${product['stock_quantity'] ?? 0}',
      ),
      trailing: Switch(
        value: product['active'] == true,
        activeThumbColor: _brand,
        onChanged: (_) => onToggle(),
      ),
    ),
  );
}

IconData _categoryIcon(String? category) {
  switch (category?.toLowerCase()) {
    case 'feed':
    case 'nutrition':
      return Icons.grass_outlined;
    case 'medicine':
    case 'vaccine':
    case 'veterinary':
      return Icons.medication_outlined;
    case 'equipment':
      return Icons.handyman_outlined;
    default:
      return Icons.inventory_2_outlined;
  }
}

class ProductFormPage extends StatefulWidget {
  const ProductFormPage({required this.controller, super.key});
  final AppController controller;

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _unit;
  late final TextEditingController _stock;
  bool _active = true;

  bool get _editing => widget.controller.editingProduct != null;

  @override
  void initState() {
    super.initState();
    final product = widget.controller.editingProduct ?? {};
    _name = TextEditingController(text: product['name']?.toString() ?? '');
    _category = TextEditingController(
      text: product['category']?.toString() ?? '',
    );
    _description = TextEditingController(
      text: product['description']?.toString() ?? '',
    );
    _price = TextEditingController(text: product['price']?.toString() ?? '');
    _unit = TextEditingController(text: product['unit']?.toString() ?? '');
    _stock = TextEditingController(
      text: product['stock_quantity']?.toString() ?? '0',
    );
    _active = product['active'] != false;
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _description.dispose();
    _price.dispose();
    _unit.dispose();
    _stock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormPageFrame(
    title: _editing ? 'Edit product' : 'Add a product',
    subtitle:
        'List animal feed, medicine, equipment, and other livestock products.',
    onBack: widget.controller.openHome,
    child: Form(
      key: _formKey,
      child: Column(
        children: [
          _textField(_name, 'Product name', Icons.inventory_2_outlined),
          _textField(
            _category,
            'Category (feed, medicine, equipment...)',
            Icons.category_outlined,
          ),
          _textField(
            _description,
            'Description (optional)',
            Icons.notes_outlined,
            required: false,
            maxLines: 3,
          ),
          _textField(
            _price,
            'Price in KES',
            Icons.payments_outlined,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
          _textField(
            _unit,
            'Unit (bag, bottle, piece...)',
            Icons.straighten_outlined,
          ),
          _textField(
            _stock,
            'Available stock',
            Icons.warehouse_outlined,
            keyboard: TextInputType.number,
          ),
          SwitchListTile(
            value: _active,
            contentPadding: EdgeInsets.zero,
            activeThumbColor: _brand,
            title: const Text('Show listing as available'),
            onChanged: (value) => setState(() => _active = value),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: _editing ? 'Save changes' : 'Publish product listing',
            icon: _editing ? Icons.save_outlined : Icons.publish_outlined,
            onPressed: _save,
          ),
        ],
      ),
    ),
  );

  Widget _textField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = true,
    int maxLines = 1,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (!required && text.isEmpty) return null;
        if (text.isEmpty) return 'This field is required.';
        if (identical(controller, _price) &&
            (double.tryParse(text) == null || double.parse(text) <= 0)) {
          return 'Enter a price greater than zero.';
        }
        if (identical(controller, _stock) &&
            (int.tryParse(text) == null || int.parse(text) < 0)) {
          return 'Enter a valid whole-number stock count.';
        }
        return null;
      },
    ),
  );

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await widget.controller.saveProduct({
      'name': _name.text.trim(),
      'category': _category.text.trim(),
      'description': _description.text.trim(),
      'price': double.parse(_price.text.trim()),
      'currency': 'KES',
      'unit': _unit.text.trim(),
      'stock_quantity': int.parse(_stock.text.trim()),
      'active': _active,
    });
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({required this.controller, super.key});
  final AppController controller;

  @override
  Widget build(BuildContext context) => AppPageFrame(
    title: 'My profile',
    subtitle: 'Business and account details.',
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
            _initialFor(controller.supplier['business_name']?.toString()),
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
          value: controller.supplier['name']?.toString() ?? '—',
        ),
        InfoTile(
          icon: Icons.email_outlined,
          label: 'Email',
          value: controller.supplier['email']?.toString() ?? '—',
        ),
        InfoTile(
          icon: Icons.phone_outlined,
          label: 'Phone',
          value: controller.supplier['phone']?.toString() ?? '—',
        ),
        InfoTile(
          icon: Icons.badge_outlined,
          label: 'Business registration number',
          value:
              controller.supplier['business_registration_number']?.toString() ??
              '—',
        ),
        InfoTile(
          icon: Icons.storefront_outlined,
          label: 'Business name',
          value: controller.supplier['business_name']?.toString() ?? '—',
        ),
        InfoTile(
          icon: Icons.location_on_outlined,
          label: 'County',
          value: controller.supplier['county']?.toString() ?? '—',
        ),
        InfoTile(
          icon: Icons.inventory_2_outlined,
          label: 'Products sold',
          value: controller.supplier['product_categories']?.toString() ?? '—',
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
        'Supplier',
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
