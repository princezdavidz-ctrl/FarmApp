import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _brand = Color(0xFF7054A3);
String get _baseUrl {
  const configured = String.fromEnvironment('API_BASE_URL');
  if (configured.isNotEmpty) return configured;
  if (kReleaseMode) {
    throw StateError(
      'API_BASE_URL is required for release builds. Pass '
      '--dart-define=API_BASE_URL=https://<your-api-host>/api/v1.',
    );
  }
  return defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:8000/api/v1'
      : 'http://localhost:8000/api/v1';
}

void main() {
  runApp(const BuyerApp());
}

class BuyerApp extends StatelessWidget {
  const BuyerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Buyer',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _brand),
      scaffoldBackgroundColor: const Color(0xFFF5F7F4),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: const BuyerFlow(),
  );
}

class BuyerFlow extends StatefulWidget {
  const BuyerFlow({super.key});

  @override
  State<BuyerFlow> createState() => _BuyerFlowState();
}

class _BuyerFlowState extends State<BuyerFlow> {
  final _api = BuyerMarketplaceApi(Dio(BaseOptions(baseUrl: _baseUrl)));
  String _page = 'splash';
  String _language = 'en';
  String _name = '';
  String _email = '';
  String _phone = '';
  String? _challengeId;
  String? _challengeDestination;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final savedLanguage = await _api.readLanguage();
    BuyerAccount? account;
    try {
      account = await _api.restoreBuyer();
    } on DioException {
      if (!mounted) return;
      setState(() {
        _language = savedLanguage ?? _language;
        _page = savedLanguage == null ? 'language' : 'login';
        _error = _copy(_language, 'connectionError');
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      if (savedLanguage != null) _language = savedLanguage;
      if (account != null) {
        _name = account.name;
        _email = account.email;
        _phone = account.phone;
        _page = 'home';
      } else if (savedLanguage == null) {
        _page = 'language';
      } else {
        _page = 'login';
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_page == 'splash') {
      return const _SplashScreen();
    }
    if (_page == 'language') {
      return _LanguageScreen(
        language: _language,
        onSelected: (language) async {
          await _api.saveLanguage(language);
          if (mounted) {
            setState(() {
              _language = language;
              _page = 'login';
            });
          }
        },
      );
    }
    if (_page == 'signup') {
      return _BuyerSignupPage(
        language: _language,
        busy: _busy,
        error: _error,
        onBack: () => setState(() {
          _page = 'login';
          _error = null;
        }),
        onSubmit: (values) => _run(() async {
          final account = await _api.registerBuyer(values);
          if (!mounted) return;
          setState(() {
            _name = account.name;
            _email = account.email;
            _phone = account.phone;
            _page = 'home';
          });
        }),
      );
    }
    if (_page == 'forgot') {
      return _ForgotPasswordPage(
        language: _language,
        busy: _busy,
        error: _error,
        onBack: () => setState(() {
          _page = 'login';
          _error = null;
        }),
        onSubmit: (email) => _run(() async {
          await _api.forgotPassword(email);
          if (mounted) setState(() => _error = _copy(_language, 'resetSent'));
        }),
      );
    }
    if (_page == 'otp') {
      return _BuyerOtpPage(
        language: _language,
        busy: _busy,
        error: _error,
        destination: _challengeDestination ?? '',
        onBack: () => setState(() {
          _page = 'login';
          _challengeId = null;
          _error = null;
        }),
        onResend: () => _run(() async {
          final result = await _api.resendOtp(_challengeId!);
          if (mounted) {
            setState(() {
              _challengeId = result.challengeId;
              _challengeDestination = result.destination;
            });
          }
        }),
        onSubmit: (code) => _run(() async {
          final account = await _api.verifyOtp(_challengeId!, code);
          if (!mounted) return;
          setState(() {
            _name = account.name;
            _email = account.email;
            _phone = account.phone;
            _page = 'home';
          });
        }),
      );
    }
    if (_page == 'home') {
      return BuyerHomePage(
        api: _api,
        language: _language,
        buyer: BuyerAccount(name: _name, email: _email, phone: _phone),
        onLogout: () async {
          await _api.logout();
          if (mounted) setState(() => _page = 'login');
        },
      );
    }
    return _BuyerSignInPage(
      language: _language,
      busy: _busy,
      error: _error,
      onLanguage: () => setState(() => _page = 'language'),
      onSignUp: () => setState(() {
        _page = 'signup';
        _error = null;
      }),
      onForgot: () => setState(() {
        _page = 'forgot';
        _error = null;
      }),
      onSubmit: (identifier, password) => _run(() async {
        final challenge = await _api.login(identifier, password);
        if (mounted) {
          setState(() {
            _challengeId = challenge.challengeId;
            _challengeDestination = challenge.destination;
            _page = 'otp';
          });
        }
      }),
    );
  }
}

class BuyerHomePage extends StatefulWidget {
  const BuyerHomePage({
    required this.api,
    required this.language,
    required this.buyer,
    required this.onLogout,
    super.key,
  });

  final BuyerMarketplaceApi api;
  final String language;
  final BuyerAccount buyer;
  final VoidCallback onLogout;

  @override
  State<BuyerHomePage> createState() => _BuyerHomePageState();
}

class _BuyerHomePageState extends State<BuyerHomePage> {
  late Future<List<PigListing>> _listingsFuture;
  late Future<List<BuyerDelivery>> _deliveriesFuture;
  String _search = '';
  String? _selectedBreed;
  String _sortOrder = 'newest';
  MarketplaceFilters _filters = const MarketplaceFilters();
  final _searchFocusNode = FocusNode();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _listingsFuture = widget.api.fetchListings();
    _deliveriesFuture = widget.api.fetchBuyerDeliveries();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _page = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _openNotifications() {
    setState(() {
      _page = 1;
      _deliveriesFuture = widget.api.fetchBuyerDeliveries();
    });
  }

  Future<void> _refresh() async {
    final future = widget.api.fetchListings();
    setState(() => _listingsFuture = future);
    try {
      await future;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not refresh pigs: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const _BrandIcon(size: 34),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                _copy(widget.language, 'marketplace'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: _copy(widget.language, 'searchListings'),
            icon: const Icon(Icons.search),
            onPressed: _openSearch,
          ),
          IconButton(
            tooltip: _copy(widget.language, 'notifications'),
            icon: const Icon(Icons.notifications_outlined),
            onPressed: _openNotifications,
          ),
        ],
      ),
      body: switch (_page) {
        0 => _marketplace(),
        1 => _deliveries(),
        _ => _profile(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _page,
        onDestinationSelected: (value) => setState(() => _page = value),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: _copy(widget.language, 'home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.local_shipping_outlined),
            selectedIcon: const Icon(Icons.local_shipping),
            label: _copy(widget.language, 'delivery'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: _copy(widget.language, 'profile'),
          ),
        ],
      ),
    );
  }

  Widget _marketplace() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: TextField(
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            labelText: _copy(widget.language, 'searchListings'),
          ),
          onChanged: (value) =>
              setState(() => _search = value.trim().toLowerCase()),
        ),
      ),
      FutureBuilder<List<PigListing>>(
        future: _listingsFuture,
        builder: (context, snapshot) {
          final listings = snapshot.data ?? const <PigListing>[];
          final breeds =
              listings.map((listing) => listing.breed).toSet().toList()..sort();
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    key: ValueKey(_selectedBreed),
                    initialValue: _selectedBreed,
                    decoration: InputDecoration(
                      labelText: _copy(widget.language, 'filterBreed'),
                      isDense: true,
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(_copy(widget.language, 'allBreeds')),
                      ),
                      for (final breed in breeds)
                        DropdownMenuItem<String?>(
                          value: breed,
                          child: Text(breed, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedBreed = value),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(_sortOrder),
                    initialValue: _sortOrder,
                    decoration: InputDecoration(
                      labelText: _copy(widget.language, 'sortBy'),
                      isDense: true,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'newest',
                        child: Text(_copy(widget.language, 'sortNewest')),
                      ),
                      DropdownMenuItem(
                        value: 'price_low',
                        child: Text(_copy(widget.language, 'sortPriceLow')),
                      ),
                      DropdownMenuItem(
                        value: 'price_high',
                        child: Text(_copy(widget.language, 'sortPriceHigh')),
                      ),
                      DropdownMenuItem(
                        value: 'weight_high',
                        child: Text(_copy(widget.language, 'sortWeight')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _sortOrder = value);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: _showFilterSheet,
            child: Text(
              _filters.activeCount == 0
                  ? _copy(widget.language, 'moreFilters')
                  : '${_copy(widget.language, 'moreFilters')} (${_filters.activeCount})',
            ),
          ),
        ),
      ),
      Expanded(
        child: FutureBuilder<List<PigListing>>(
          future: _listingsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _LoadError(
                error: snapshot.error!,
                onRetry: () => setState(
                  () => _listingsFuture = widget.api.fetchListings(),
                ),
              );
            }
            final listings = filterAndSortListings(
              snapshot.data ?? const <PigListing>[],
              search: _search,
              breed: _selectedBreed,
              sortOrder: _sortOrder,
              filters: _filters,
            );
            if (listings.isEmpty) {
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    const _BrandIcon(size: 56),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        _search.isEmpty &&
                                _selectedBreed == null &&
                                _filters.activeCount == 0
                            ? _copy(widget.language, 'noPigs')
                            : _copy(widget.language, 'noMatches'),
                      ),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1000
                      ? 4
                      : constraints.maxWidth >= 640
                      ? 3
                      : 2;
                  return GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: constraints.maxWidth < 640 ? 340 : 370,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: listings.length,
                    itemBuilder: (context, index) => _BuyerListingCard(
                      listing: listings[index],
                      language: widget.language,
                      onDetails: () => _showListingDetails(listings[index]),
                      onRequest: () => _showRequestDialog(listings[index]),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ],
  );

  Future<void> _showFilterSheet() async {
    final location = TextEditingController(text: _filters.location);
    final minPrice = TextEditingController(
      text: _filters.minPrice?.toString() ?? '',
    );
    final maxPrice = TextEditingController(
      text: _filters.maxPrice?.toString() ?? '',
    );
    final minAge = TextEditingController(
      text: _filters.minAgeWeeks?.toString() ?? '',
    );
    final maxAge = TextEditingController(
      text: _filters.maxAgeWeeks?.toString() ?? '',
    );
    final minWeight = TextEditingController(
      text: _filters.minWeightKg?.toString() ?? '',
    );
    final maxWeight = TextEditingController(
      text: _filters.maxWeightKg?.toString() ?? '',
    );
    var currency = _filters.currency;

    final result = await showModalBottomSheet<MarketplaceFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _copy(widget.language, 'filterListings'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: location,
                    decoration: InputDecoration(
                      labelText: _copy(widget.language, 'filterLocation'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: currency,
                    decoration: InputDecoration(
                      labelText: _copy(widget.language, 'currency'),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(_copy(widget.language, 'anyCurrency')),
                      ),
                      for (final code in const ['KES', 'UGX', 'TZS', 'USD'])
                        DropdownMenuItem<String?>(
                          value: code,
                          child: Text(code),
                        ),
                    ],
                    onChanged: (value) => setSheetState(() => currency = value),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minPrice,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: _copy(widget.language, 'minPrice'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: maxPrice,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: _copy(widget.language, 'maxPrice'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minAge,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: _copy(widget.language, 'minAgeWeeks'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: maxAge,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: _copy(widget.language, 'maxAgeWeeks'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minWeight,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: _copy(widget.language, 'minWeightKg'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: maxWeight,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: _copy(widget.language, 'maxWeightKg'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            location.clear();
                            minPrice.clear();
                            maxPrice.clear();
                            minAge.clear();
                            maxAge.clear();
                            minWeight.clear();
                            maxWeight.clear();
                            currency = null;
                          });
                        },
                        child: Text(_copy(widget.language, 'clearFilters')),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          final parsedMinPrice = double.tryParse(
                            minPrice.text.trim(),
                          );
                          final parsedMaxPrice = double.tryParse(
                            maxPrice.text.trim(),
                          );
                          final parsedMinAge = int.tryParse(minAge.text.trim());
                          final parsedMaxAge = int.tryParse(maxAge.text.trim());
                          final parsedMinWeight = double.tryParse(
                            minWeight.text.trim(),
                          );
                          final parsedMaxWeight = double.tryParse(
                            maxWeight.text.trim(),
                          );
                          if (currency == null &&
                              (minPrice.text.trim().isNotEmpty ||
                                  maxPrice.text.trim().isNotEmpty)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _copy(
                                    widget.language,
                                    'chooseCurrencyForPrice',
                                  ),
                                ),
                              ),
                            );
                            return;
                          }
                          final invalid =
                              _hasInvalidRange(
                                minPrice.text,
                                parsedMinPrice,
                                maxPrice.text,
                                parsedMaxPrice,
                              ) ||
                              _hasInvalidRange(
                                minAge.text,
                                parsedMinAge,
                                maxAge.text,
                                parsedMaxAge,
                              ) ||
                              _hasInvalidRange(
                                minWeight.text,
                                parsedMinWeight,
                                maxWeight.text,
                                parsedMaxWeight,
                              );
                          if (invalid) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _copy(widget.language, 'invalidFilterRange'),
                                ),
                              ),
                            );
                            return;
                          }
                          Navigator.pop(
                            sheetContext,
                            MarketplaceFilters(
                              location: location.text.trim(),
                              currency: currency,
                              minPrice: parsedMinPrice,
                              maxPrice: parsedMaxPrice,
                              minAgeWeeks: parsedMinAge,
                              maxAgeWeeks: parsedMaxAge,
                              minWeightKg: parsedMinWeight,
                              maxWeightKg: parsedMaxWeight,
                            ),
                          );
                        },
                        child: Text(_copy(widget.language, 'applyFilters')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    location.dispose();
    minPrice.dispose();
    maxPrice.dispose();
    minAge.dispose();
    maxAge.dispose();
    minWeight.dispose();
    maxWeight.dispose();
    if (result != null && mounted) setState(() => _filters = result);
  }

  bool _hasInvalidRange<T extends num>(
    String minText,
    T? minValue,
    String maxText,
    T? maxValue,
  ) {
    if ((minText.trim().isNotEmpty && minValue == null) ||
        (maxText.trim().isNotEmpty && maxValue == null)) {
      return true;
    }
    if ((minValue != null && minValue < 0) ||
        (maxValue != null && maxValue < 0) ||
        (minValue != null && !minValue.isFinite) ||
        (maxValue != null && !maxValue.isFinite)) {
      return true;
    }
    return minValue != null && maxValue != null && minValue > maxValue;
  }

  Future<void> _showListingDetails(PigListing listing) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: double.infinity,
                  height: 220,
                  child: listing.imageUrl == null || listing.imageUrl!.isEmpty
                      ? const ColoredBox(
                          color: Color(0xFFE9F2EC),
                          child: Center(child: _BrandIcon(size: 80)),
                        )
                      : Image.network(
                          listing.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const ColoredBox(
                                color: Color(0xFFE9F2EC),
                                child: Center(child: _BrandIcon(size: 80)),
                              ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                listing.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                '${listing.farmName} · ${listing.location ?? _copy(widget.language, 'locationUnknown')}',
              ),
              const SizedBox(height: 12),
              Text(
                '${listing.currency} ${listing.pricePerPig.toStringAsFixed(0)} ${_copy(widget.language, 'each')}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _brand,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _DetailLine(
                label: _copy(widget.language, 'breed'),
                value: listing.breed,
              ),
              _DetailLine(
                label: _copy(widget.language, 'weight'),
                value: listing.weightKg == null
                    ? _copy(widget.language, 'notProvided')
                    : '${listing.weightKg} kg',
              ),
              if (listing.ageWeeks != null)
                _DetailLine(
                  label: _copy(widget.language, 'age'),
                  value:
                      '${listing.ageWeeks} ${_copy(widget.language, 'weeks')}',
                ),
              _DetailLine(
                label: _copy(widget.language, 'available'),
                value: '${listing.quantity}',
              ),
              if (listing.description?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(
                  _copy(widget.language, 'farmDescription'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(listing.description!),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _showRequestDialog(listing);
                  },
                  child: Text(_copy(widget.language, 'contactFarm')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRequestDialog(PigListing listing) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: widget.buyer.name);
    final phone = TextEditingController(text: widget.buyer.phone);
    final email = TextEditingController(text: widget.buyer.email);
    final quantity = TextEditingController(text: '1');
    final message = TextEditingController();
    var submitting = false;
    String? error;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${_copy(widget.language, 'request')} ${listing.title}'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: InputDecoration(
                        labelText: _copy(widget.language, 'fullName'),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: phone,
                      decoration: InputDecoration(
                        labelText: _copy(widget.language, 'phone'),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: _required,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: email,
                      decoration: InputDecoration(
                        labelText: _copy(widget.language, 'emailOptional'),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: _validEmail,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: quantity,
                      decoration: InputDecoration(
                        labelText: _copy(widget.language, 'numberPigs'),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final parsed = int.tryParse(value?.trim() ?? '');
                        if (parsed == null || parsed < 1) {
                          return _copy(widget.language, 'enterAtLeastOne');
                        }
                        if (parsed > listing.quantity) {
                          return _copy(
                            widget.language,
                            'onlyAvailable',
                          ).replaceAll('{count}', '${listing.quantity}');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: message,
                      decoration: InputDecoration(
                        labelText: _copy(widget.language, 'messageFarm'),
                      ),
                      maxLines: 3,
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(dialogContext),
              child: Text(_copy(widget.language, 'cancel')),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        submitting = true;
                        error = null;
                      });
                      try {
                        await widget.api.sendInquiry(
                          listingId: listing.id,
                          buyerName: name.text.trim(),
                          phone: phone.text.trim(),
                          email: email.text.trim(),
                          quantity: int.parse(quantity.text.trim()),
                          message: message.text.trim(),
                        );
                        if (mounted) {
                          setState(
                            () => _deliveriesFuture = widget.api
                                .fetchBuyerDeliveries(),
                          );
                        }
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _copy(widget.language, 'requestSent'),
                              ),
                            ),
                          );
                        }
                      } catch (exception) {
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            submitting = false;
                            error =
                                '${_copy(widget.language, 'requestFailed')}: $exception';
                          });
                        }
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_copy(widget.language, 'sendRequest')),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    phone.dispose();
    email.dispose();
    quantity.dispose();
    message.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  String? _validEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value.trim())
        ? null
        : 'Enter a valid email address.';
  }

  Widget _deliveries() => RefreshIndicator(
    onRefresh: () async {
      final future = widget.api.fetchBuyerDeliveries();
      setState(() => _deliveriesFuture = future);
      try {
        await future;
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$error')));
        }
      }
    },
    child: FutureBuilder<List<BuyerDelivery>>(
      future: _deliveriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _LoadError(
            error: snapshot.error!,
            onRetry: () => setState(
              () => _deliveriesFuture = widget.api.fetchBuyerDeliveries(),
            ),
          );
        }
        final deliveries = snapshot.data ?? const <BuyerDelivery>[];
        if (deliveries.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 100),
              const _BrandIcon(size: 64),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  _copy(widget.language, 'noDeliveries'),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );
        }
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: deliveries.length,
          itemBuilder: (context, index) => _DeliveryCard(
            delivery: deliveries[index],
            language: widget.language,
          ),
        );
      },
    ),
  );

  Widget _profile() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const SizedBox(height: 20),
      CircleAvatar(
        radius: 42,
        backgroundColor: const Color(0xFFE9F2EC),
        child: Icon(Icons.person, size: 48, color: _brand),
      ),
      const SizedBox(height: 14),
      Text(
        widget.buyer.name,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: _brand,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 20),
      Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(_copy(widget.language, 'fullName')),
              subtitle: Text(widget.buyer.name),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: Text(_copy(widget.language, 'email')),
              subtitle: Text(
                widget.buyer.email.isEmpty
                    ? _copy(widget.language, 'notProvided')
                    : widget.buyer.email,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: Text(_copy(widget.language, 'phone')),
              subtitle: Text(
                widget.buyer.phone.isEmpty
                    ? _copy(widget.language, 'notProvided')
                    : widget.buyer.phone,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        onPressed: widget.onLogout,
        icon: const Icon(Icons.logout),
        label: Text(_copy(widget.language, 'signOut')),
      ),
    ],
  );
}

class BuyerMarketplaceApi {
  BuyerMarketplaceApi(this._dio, {FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'buyer_access_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          if (error.response?.statusCode != 401 ||
              request.extra['buyer_retried'] == true ||
              (request.path.startsWith('/auth/') &&
                  request.path != '/auth/me')) {
            handler.next(error);
            return;
          }
          try {
            final refreshToken = await _storage.read(
              key: 'buyer_refresh_token',
            );
            if (refreshToken == null || refreshToken.isEmpty) {
              await _clearSession();
              handler.next(error);
              return;
            }
            final response =
                await Dio(
                  BaseOptions(baseUrl: _dio.options.baseUrl),
                ).post<Map<String, dynamic>>(
                  '/auth/refresh',
                  data: {'refresh_token': refreshToken},
                );
            await _saveSession(response.data!);
            final accessToken = response.data!['access_token'] as String;
            request
              ..headers['Authorization'] = 'Bearer $accessToken'
              ..extra['buyer_retried'] = true;
            handler.resolve(await _dio.fetch<dynamic>(request));
          } on DioException {
            await _clearSession();
            handler.next(error);
          }
        },
      ),
    );
  }

  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<String?> readLanguage() => _storage.read(key: 'buyer_language');

  Future<void> saveLanguage(String language) =>
      _storage.write(key: 'buyer_language', value: language);

  Future<BuyerAccount?> restoreBuyer() async {
    if (await _storage.read(key: 'buyer_access_token') == null) return null;
    try {
      final response = await _dio.get<Map<String, dynamic>>('/auth/me');
      final user = response.data?['user'] as Map<String, dynamic>?;
      if (user == null || user['role'] != 'buyer') {
        await _clearSession();
        return null;
      }
      return BuyerAccount.fromJson(user);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await _clearSession();
        return null;
      }
      rethrow;
    }
  }

  Future<BuyerLoginChallenge> login(String identifier, String password) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'identifier': identifier,
          'password': password,
          'remember_me': true,
        },
      );
      return BuyerLoginChallenge.fromJson(response.data!);
    } on DioException catch (error) {
      throw StateError(_errorMessage(error));
    }
  }

  Future<BuyerAccount> verifyOtp(String challengeId, String code) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/verify-otp',
        data: {'challenge_id': challengeId, 'code': code},
      );
      final data = response.data!;
      final user = data['user'] as Map<String, dynamic>;
      if (user['role'] != 'buyer') {
        await _clearSession();
        throw StateError(
          'Use a buyer account to access the buyer marketplace.',
        );
      }
      await _saveSession(data);
      return BuyerAccount.fromJson(user);
    } on DioException catch (error) {
      throw StateError(_errorMessage(error));
    }
  }

  Future<BuyerLoginChallenge> resendOtp(String challengeId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/resend-otp',
        data: {'challenge_id': challengeId},
      );
      return BuyerLoginChallenge.fromJson(response.data!);
    } on DioException catch (error) {
      throw StateError(_errorMessage(error));
    }
  }

  Future<BuyerAccount> registerBuyer(Map<String, String> values) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          ...values,
          'role': 'buyer',
          'password_confirmation': values['password'],
        },
      );
      final data = response.data!;
      final user = data['user'] as Map<String, dynamic>;
      if (user['role'] != 'buyer') {
        await _clearSession();
        throw StateError(
          'Buyer account registration did not return a buyer profile.',
        );
      }
      await _saveSession(data);
      return BuyerAccount.fromJson(user);
    } on DioException catch (error) {
      throw StateError(_errorMessage(error));
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      await _dio.post<void>('/auth/forgot-password', data: {'email': email});
    } on DioException catch (error) {
      throw StateError(_errorMessage(error));
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post<void>('/auth/logout');
    } on DioException {
      // Clear local credentials even if the network is unavailable.
    } finally {
      await _clearSession();
    }
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    await _storage.write(
      key: 'buyer_access_token',
      value: data['access_token'] as String?,
    );
    await _storage.write(
      key: 'buyer_refresh_token',
      value: data['refresh_token'] as String?,
    );
  }

  Future<void> _clearSession() async {
    await _storage.delete(key: 'buyer_access_token');
    await _storage.delete(key: 'buyer_refresh_token');
  }

  Future<List<PigListing>> fetchListings() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/marketplace/pigs',
      );
      final rows = response.data?['data'] as List<dynamic>? ?? const [];
      return rows
          .map((row) => PigListing.fromJson(row as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw StateError(_errorMessage(error));
    }
  }

  Future<void> sendInquiry({
    required String listingId,
    required String buyerName,
    required String phone,
    required String email,
    required int quantity,
    required String message,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/marketplace/pigs/$listingId/buyer-inquiries',
        data: {
          'buyer_name': buyerName,
          'phone': phone,
          if (email.isNotEmpty) 'email': email,
          'quantity': quantity,
          if (message.isNotEmpty) 'message': message,
        },
      );
    } on DioException catch (error) {
      throw StateError(_errorMessage(error));
    }
  }

  Future<List<BuyerDelivery>> fetchBuyerDeliveries() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/marketplace/buyer/deliveries',
      );
      final rows = response.data?['data'] as List<dynamic>? ?? const [];
      return rows
          .map((row) => BuyerDelivery.fromJson(row as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      throw StateError(_errorMessage(error));
    }
  }

  String _errorMessage(DioException error) {
    final responseMessage = error.response?.data is Map<String, dynamic>
        ? (error.response!.data as Map<String, dynamic>)['message']
        : null;
    if (responseMessage is String && responseMessage.isNotEmpty) {
      return responseMessage;
    }
    return error.message ?? 'Unable to reach the marketplace.';
  }
}

class BuyerAccount {
  const BuyerAccount({
    required this.name,
    required this.email,
    required this.phone,
  });

  final String name;
  final String email;
  final String phone;

  factory BuyerAccount.fromJson(Map<String, dynamic> json) => BuyerAccount(
    name: '${json['name'] ?? ''}',
    email: '${json['email'] ?? ''}',
    phone: '${json['phone'] ?? ''}',
  );
}

class BuyerLoginChallenge {
  const BuyerLoginChallenge({
    required this.challengeId,
    required this.destination,
  });

  final String challengeId;
  final String destination;

  factory BuyerLoginChallenge.fromJson(Map<String, dynamic> json) =>
      BuyerLoginChallenge(
        challengeId: '${json['challenge_id'] ?? ''}',
        destination: '${json['destination'] ?? 'your registered email'}',
      );
}

class BuyerDelivery {
  const BuyerDelivery({
    required this.id,
    required this.buyerName,
    required this.phone,
    required this.quantity,
    required this.status,
    required this.listingTitle,
    required this.farmName,
    required this.createdAt,
    this.breed,
    this.currency,
    this.pricePerPig,
    this.weightKg,
    this.imageUrl,
    this.ageWeeks,
    this.location,
    this.message,
  });

  final String id;
  final String buyerName;
  final String phone;
  final int quantity;
  final String status;
  final String listingTitle;
  final String farmName;
  final DateTime? createdAt;
  final String? breed;
  final String? currency;
  final double? pricePerPig;
  final double? weightKg;
  final String? imageUrl;
  final int? ageWeeks;
  final String? location;
  final String? message;

  factory BuyerDelivery.fromJson(Map<String, dynamic> json) {
    final listing = json['listing'] as Map<String, dynamic>? ?? const {};
    return BuyerDelivery(
      id: '${json['id'] ?? ''}',
      buyerName: '${json['buyer_name'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      status: '${json['status'] ?? 'pending'}',
      listingTitle: '${listing['title'] ?? 'Pig listing'}',
      farmName: '${listing['farm_name'] ?? 'Farm'}',
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
      breed: listing['breed'] as String?,
      currency: listing['currency'] as String?,
      pricePerPig: double.tryParse('${listing['price_per_pig'] ?? ''}'),
      weightKg: double.tryParse('${listing['weight_kg'] ?? ''}'),
      imageUrl: listing['image_url'] as String?,
      ageWeeks: (listing['age_weeks'] as num?)?.toInt(),
      location:
          listing['location'] as String? ?? listing['farm_location'] as String?,
      message: json['message'] as String?,
    );
  }
}

class PigListing {
  const PigListing({
    required this.id,
    required this.title,
    required this.breed,
    required this.quantity,
    required this.pricePerPig,
    required this.currency,
    required this.farmName,
    this.createdAt,
    this.imageUrl,
    this.ageWeeks,
    this.weightKg,
    this.location,
    this.description,
  });

  final String id;
  final String title;
  final String breed;
  final int quantity;
  final double pricePerPig;
  final String currency;
  final String farmName;
  final DateTime? createdAt;
  final String? imageUrl;
  final int? ageWeeks;
  final double? weightKg;
  final String? location;
  final String? description;

  String get searchableText =>
      '$title $breed $farmName ${location ?? ''}'.toLowerCase();

  factory PigListing.fromJson(Map<String, dynamic> json) => PigListing(
    id: '${json['id'] ?? ''}',
    title: '${json['title'] ?? 'Pig listing'}',
    breed: '${json['breed'] ?? 'Unknown breed'}',
    quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    pricePerPig: double.tryParse('${json['price_per_pig'] ?? 0}') ?? 0,
    currency: '${json['currency'] ?? 'KES'}',
    farmName: '${json['farm_name'] ?? 'Farm'}',
    createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    imageUrl: json['image_url'] as String?,
    ageWeeks: (json['age_weeks'] as num?)?.toInt(),
    weightKg: json['weight_kg'] == null
        ? null
        : double.tryParse('${json['weight_kg']}'),
    location: json['location'] as String? ?? json['farm_location'] as String?,
    description: json['description'] as String?,
  );
}

class MarketplaceFilters {
  const MarketplaceFilters({
    this.location = '',
    this.currency,
    this.minPrice,
    this.maxPrice,
    this.minAgeWeeks,
    this.maxAgeWeeks,
    this.minWeightKg,
    this.maxWeightKg,
  });

  final String location;
  final String? currency;
  final double? minPrice;
  final double? maxPrice;
  final int? minAgeWeeks;
  final int? maxAgeWeeks;
  final double? minWeightKg;
  final double? maxWeightKg;

  int get activeCount => [
    location.trim().isNotEmpty,
    currency != null,
    minPrice != null || maxPrice != null,
    minAgeWeeks != null || maxAgeWeeks != null,
    minWeightKg != null || maxWeightKg != null,
  ].where((isActive) => isActive).length;
}

List<PigListing> filterAndSortListings(
  Iterable<PigListing> source, {
  String search = '',
  String? breed,
  String sortOrder = 'newest',
  MarketplaceFilters filters = const MarketplaceFilters(),
}) {
  final listings = source
      .where(
        (listing) =>
            listing.searchableText.contains(search.trim().toLowerCase()) &&
            (breed == null || listing.breed == breed) &&
            (filters.location.trim().isEmpty ||
                (listing.location ?? '').toLowerCase().contains(
                  filters.location.trim().toLowerCase(),
                )) &&
            (filters.currency == null ||
                listing.currency == filters.currency) &&
            (filters.minPrice == null ||
                listing.pricePerPig >= filters.minPrice!) &&
            (filters.maxPrice == null ||
                listing.pricePerPig <= filters.maxPrice!) &&
            (filters.minAgeWeeks == null ||
                (listing.ageWeeks != null &&
                    listing.ageWeeks! >= filters.minAgeWeeks!)) &&
            (filters.maxAgeWeeks == null ||
                (listing.ageWeeks != null &&
                    listing.ageWeeks! <= filters.maxAgeWeeks!)) &&
            (filters.minWeightKg == null ||
                (listing.weightKg != null &&
                    listing.weightKg! >= filters.minWeightKg!)) &&
            (filters.maxWeightKg == null ||
                (listing.weightKg != null &&
                    listing.weightKg! <= filters.maxWeightKg!)),
      )
      .toList();
  listings.sort((a, b) {
    switch (sortOrder) {
      case 'price_low':
        return a.pricePerPig.compareTo(b.pricePerPig);
      case 'price_high':
        return b.pricePerPig.compareTo(a.pricePerPig);
      case 'weight_high':
        return (b.weightKg ?? 0).compareTo(a.weightKg ?? 0);
      default:
        return (b.createdAt ?? DateTime(0)).compareTo(
          a.createdAt ?? DateTime(0),
        );
    }
  });
  return listings;
}

class _BuyerListingCard extends StatelessWidget {
  const _BuyerListingCard({
    required this.listing,
    required this.language,
    required this.onDetails,
    required this.onRequest,
  });

  final PigListing listing;
  final String language;
  final VoidCallback onDetails;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onDetails,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 122,
            child: listing.imageUrl == null || listing.imageUrl!.isEmpty
                ? const ColoredBox(
                    color: Color(0xFFE9F2EC),
                    child: Center(child: _BrandIcon(size: 76)),
                  )
                : Image.network(
                    listing.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const ColoredBox(
                          color: Color(0xFFE9F2EC),
                          child: Center(child: _BrandIcon(size: 76)),
                        ),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${listing.farmName} · ${listing.location ?? _copy(language, 'locationUnknown')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${listing.breed} · ${listing.quantity} ${_copy(language, 'available')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _brand,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${listing.currency} ${listing.pricePerPig.toStringAsFixed(0)} ${_copy(language, 'each')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: _brand,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onRequest,
                      child: Text(
                        _copy(language, 'requestToBuy'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _BrandIcon extends StatelessWidget {
  const _BrandIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.storefront, size: size, color: _brand, semanticLabel: 'Buyer');
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _BrandIcon(size: 48),
          const SizedBox(height: 12),
          const Text('Could not load pigs from the marketplace.'),
          const SizedBox(height: 6),
          Text('$error', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const _BrandIcon(size: 20),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE9F2EC), Colors.white],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront, size: 180, color: _brand),
            const SizedBox(height: 20),
            Text(
              'Buyer',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: _brand,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Find pigs. Buy direct from farms.'),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    ),
  );
}

class _LanguageScreen extends StatelessWidget {
  const _LanguageScreen({required this.language, required this.onSelected});

  final String language;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => _AuthFrame(
    language: language,
    title: _copy(language, 'chooseLanguage'),
    subtitle: _copy(language, 'languageSubtitle'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LanguageChoice(
          label: 'English',
          detail: 'Continue in English',
          selected: language == 'en',
          onTap: () => onSelected('en'),
        ),
        const SizedBox(height: 12),
        _LanguageChoice(
          label: 'Kiswahili',
          detail: 'Endelea kwa Kiswahili',
          selected: language == 'sw',
          onTap: () => onSelected('sw'),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => onSelected(language),
          child: Text(_copy(language, 'continue')),
        ),
      ],
    ),
  );
}

class _LanguageChoice extends StatelessWidget {
  const _LanguageChoice({
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? _brand : Colors.transparent,
            width: 2,
          ),
          shape: BoxShape.circle,
        ),
        child: const _BrandIcon(size: 26),
      ),
      title: Text(label),
      subtitle: Text(detail),
      selected: selected,
    ),
  );
}

class _AuthFrame extends StatelessWidget {
  const _AuthFrame({
    required this.language,
    required this.title,
    required this.subtitle,
    required this.child,
    this.back,
  });

  final String language;
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? back;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (back != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: back,
                      icon: const _BrandIcon(size: 24),
                    ),
                  ),
                Center(
                  child: const Icon(Icons.storefront, size: 112, color: _brand),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: _brand,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(subtitle, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                child,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _BuyerSignInPage extends StatefulWidget {
  const _BuyerSignInPage({
    required this.language,
    required this.busy,
    required this.error,
    required this.onLanguage,
    required this.onSignUp,
    required this.onForgot,
    required this.onSubmit,
  });

  final String language;
  final bool busy;
  final String? error;
  final VoidCallback onLanguage;
  final VoidCallback onSignUp;
  final VoidCallback onForgot;
  final void Function(String identifier, String password) onSubmit;

  @override
  State<_BuyerSignInPage> createState() => _BuyerSignInPageState();
}

class _BuyerSignInPageState extends State<_BuyerSignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthFrame(
    language: widget.language,
    title: _copy(widget.language, 'welcomeBack'),
    subtitle: _copy(widget.language, 'signInSubtitle'),
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: widget.onLanguage,
              icon: const _BrandIcon(size: 20),
              label: Text(widget.language == 'sw' ? 'Kiswahili' : 'English'),
            ),
          ),
          TextFormField(
            controller: _identifier,
            decoration: InputDecoration(
              labelText: _copy(widget.language, 'emailOrPhone'),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: _required,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _password,
            decoration: InputDecoration(
              labelText: _copy(widget.language, 'password'),
            ),
            obscureText: true,
            validator: _required,
            onFieldSubmitted: (_) => _submit(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: widget.onForgot,
              child: Text(_copy(widget.language, 'forgotPassword')),
            ),
          ),
          if (widget.error != null) _FormMessage(message: widget.error!),
          FilledButton(
            onPressed: widget.busy ? null : _submit,
            child: widget.busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_copy(widget.language, 'signIn')),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: widget.onSignUp,
            child: Text(_copy(widget.language, 'createAccount')),
          ),
        ],
      ),
    ),
  );

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onSubmit(_identifier.text.trim(), _password.text);
    }
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? _copy(widget.language, 'required')
      : null;
}

class _BuyerSignupPage extends StatefulWidget {
  const _BuyerSignupPage({
    required this.language,
    required this.busy,
    required this.error,
    required this.onBack,
    required this.onSubmit,
  });

  final String language;
  final bool busy;
  final String? error;
  final VoidCallback onBack;
  final ValueChanged<Map<String, String>> onSubmit;

  @override
  State<_BuyerSignupPage> createState() => _BuyerSignupPageState();
}

class _BuyerSignupPageState extends State<_BuyerSignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthFrame(
    language: widget.language,
    title: _copy(widget.language, 'createAccount'),
    subtitle: _copy(widget.language, 'signupSubtitle'),
    back: widget.onBack,
    child: Form(
      key: _formKey,
      child: Column(
        children: [
          _field(_name, 'fullName'),
          _field(_email, 'email', keyboard: TextInputType.emailAddress),
          _field(_phone, 'phone', keyboard: TextInputType.phone),
          _field(_password, 'password', secret: true),
          TextFormField(
            controller: _confirm,
            obscureText: true,
            decoration: InputDecoration(
              labelText: _copy(widget.language, 'confirmPassword'),
            ),
            validator: (value) => value != _password.text
                ? _copy(widget.language, 'passwordMismatch')
                : null,
          ),
          if (widget.error != null) _FormMessage(message: widget.error!),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.busy ? null : _submit,
              child: Text(_copy(widget.language, 'createAccount')),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String labelKey, {
    bool secret = false,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      obscureText: secret,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: _copy(widget.language, labelKey)),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return _copy(widget.language, 'required');
        }
        if (secret && value.length < 8) {
          return _copy(widget.language, 'passwordLength');
        }
        if (labelKey == 'email' &&
            !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value.trim())) {
          return _copy(widget.language, 'emailInvalid');
        }
        return null;
      },
    ),
  );

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onSubmit({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'password': _password.text,
      });
    }
  }
}

class _ForgotPasswordPage extends StatefulWidget {
  const _ForgotPasswordPage({
    required this.language,
    required this.busy,
    required this.error,
    required this.onBack,
    required this.onSubmit,
  });

  final String language;
  final bool busy;
  final String? error;
  final VoidCallback onBack;
  final ValueChanged<String> onSubmit;

  @override
  State<_ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<_ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthFrame(
    language: widget.language,
    title: _copy(widget.language, 'forgotPassword'),
    subtitle: _copy(widget.language, 'forgotSubtitle'),
    back: widget.onBack,
    child: Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _email,
            decoration: InputDecoration(
              labelText: _copy(widget.language, 'email'),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) =>
                value == null ||
                    !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value.trim())
                ? _copy(widget.language, 'emailInvalid')
                : null,
          ),
          if (widget.error != null)
            _FormMessage(
              message: widget.error!,
              success: widget.error == _copy(widget.language, 'resetSent'),
            ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.busy
                  ? null
                  : () {
                      if (_formKey.currentState!.validate()) {
                        widget.onSubmit(_email.text.trim());
                      }
                    },
              child: Text(_copy(widget.language, 'sendResetLink')),
            ),
          ),
        ],
      ),
    ),
  );
}

class _BuyerOtpPage extends StatefulWidget {
  const _BuyerOtpPage({
    required this.language,
    required this.busy,
    required this.error,
    required this.destination,
    required this.onBack,
    required this.onResend,
    required this.onSubmit,
  });

  final String language;
  final bool busy;
  final String? error;
  final String destination;
  final VoidCallback onBack;
  final VoidCallback onResend;
  final ValueChanged<String> onSubmit;

  @override
  State<_BuyerOtpPage> createState() => _BuyerOtpPageState();
}

class _BuyerOtpPageState extends State<_BuyerOtpPage> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthFrame(
    language: widget.language,
    title: _copy(widget.language, 'verifyEmail'),
    subtitle: '${_copy(widget.language, 'otpSent')} ${widget.destination}',
    back: widget.onBack,
    child: Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _code,
            decoration: InputDecoration(
              labelText: _copy(widget.language, 'verificationCode'),
            ),
            keyboardType: TextInputType.number,
            maxLength: 6,
            validator: (value) => (value?.trim().length ?? 0) != 6
                ? _copy(widget.language, 'codeRequired')
                : null,
          ),
          if (widget.error != null) _FormMessage(message: widget.error!),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.busy
                  ? null
                  : () {
                      if (_formKey.currentState!.validate()) {
                        widget.onSubmit(_code.text.trim());
                      }
                    },
              child: Text(_copy(widget.language, 'verifySignIn')),
            ),
          ),
          TextButton(
            onPressed: widget.busy ? null : widget.onResend,
            child: Text(_copy(widget.language, 'resendCode')),
          ),
        ],
      ),
    ),
  );
}

class _FormMessage extends StatelessWidget {
  const _FormMessage({required this.message, this.success = false});
  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: success ? const Color(0xFFE8F4E9) : const Color(0xFFFFF0F0),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      message,
      style: TextStyle(
        color: success ? _brand : Theme.of(context).colorScheme.error,
      ),
    ),
  );
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.delivery, required this.language});
  final BuyerDelivery delivery;
  final String language;

  @override
  Widget build(BuildContext context) {
    final rejected =
        delivery.status == 'rejected' || delivery.status == 'cancelled';
    final complete = delivery.status == 'completed';
    final accepted =
        delivery.status == 'accepted' || delivery.status == 'ongoing';
    final status = rejected
        ? _copy(language, 'requestDeclined')
        : complete
        ? _copy(language, 'deliveryComplete')
        : accepted
        ? _copy(language, 'requestAccepted')
        : _copy(language, 'awaitingFarm');
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child:
                        delivery.imageUrl == null || delivery.imageUrl!.isEmpty
                        ? const ColoredBox(
                            color: Color(0xFFE9F2EC),
                            child: _BrandIcon(size: 24),
                          )
                        : Image.network(
                            delivery.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const ColoredBox(
                                  color: Color(0xFFE9F2EC),
                                  child: _BrandIcon(size: 24),
                                ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    delivery.listingTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(status)),
              ],
            ),
            const SizedBox(height: 8),
            Text('${delivery.farmName} · ${delivery.quantity} pigs'),
            if (delivery.breed != null) Text(delivery.breed!),
            if (delivery.ageWeeks != null)
              Text(
                '${_copy(language, 'age')}: ${delivery.ageWeeks} ${_copy(language, 'weeks')}',
              ),
            if (delivery.weightKg != null)
              Text('${_copy(language, 'weight')}: ${delivery.weightKg} kg'),
            if (delivery.location?.isNotEmpty == true)
              Text('${_copy(language, 'location')}: ${delivery.location}'),
            if (delivery.pricePerPig != null)
              Text(
                '${delivery.currency ?? ''} ${delivery.pricePerPig!.toStringAsFixed(0)} each',
              ),
            if (delivery.createdAt != null)
              Text(
                '${_copy(language, 'requestedOn')}: ${MaterialLocalizations.of(context).formatMediumDate(delivery.createdAt!.toLocal())}',
              ),
            const SizedBox(height: 12),
            if (rejected)
              Text(_copy(language, 'contactFarmForHelp'))
            else
              LinearProgressIndicator(
                value: complete
                    ? 1
                    : accepted
                    ? .65
                    : .2,
                color: _brand,
                backgroundColor: const Color(0xFFDCE7DC),
              ),
            const SizedBox(height: 8),
            Text(
              complete
                  ? _copy(language, 'deliveryCompleteHelp')
                  : accepted
                  ? _copy(language, 'acceptedHelp')
                  : _copy(language, 'pendingHelp'),
            ),
          ],
        ),
      ),
    );
  }
}

String _copy(String language, String key) =>
    (_translations[language] ?? _translations['en']!)[key] ??
    _translations['en']![key] ??
    key;

const _translations = <String, Map<String, String>>{
  'en': {
    'marketplace': 'Buyer',
    'home': 'Home',
    'profile': 'Profile',
    'notifications': 'Notifications',
    'searchListings': 'Search breed, farm or location',
    'filterBreed': 'Breed',
    'allBreeds': 'All breeds',
    'requestToBuy': 'Request to buy',
    'moreFilters': 'More filters',
    'filterListings': 'Filter listings',
    'filterLocation': 'Location',
    'currency': 'Currency',
    'anyCurrency': 'Any currency',
    'minPrice': 'Min price',
    'maxPrice': 'Max price',
    'minAgeWeeks': 'Min age (weeks)',
    'maxAgeWeeks': 'Max age (weeks)',
    'minWeightKg': 'Min weight (kg)',
    'maxWeightKg': 'Max weight (kg)',
    'clearFilters': 'Clear',
    'applyFilters': 'Apply filters',
    'invalidFilterRange':
        'Check that filter values are valid and ranges are ordered.',
    'chooseCurrencyForPrice': 'Choose a currency to filter by price.',
    'sortBy': 'Sort',
    'sortNewest': 'Newest',
    'sortPriceLow': 'Lowest price',
    'sortPriceHigh': 'Highest price',
    'sortWeight': 'Heaviest',
    'breed': 'Breed',
    'weight': 'Weight',
    'age': 'Age',
    'notProvided': 'Not provided',
    'farmDescription': 'Farm details',
    'noPigs': 'No pigs are available right now.',
    'noMatches': 'No pigs match your search.',
    'locationUnknown': 'Location not specified',
    'weeks': 'weeks',
    'available': 'available',
    'each': 'each',
    'request': 'Request',
    'emailOptional': 'Email (optional)',
    'numberPigs': 'Number of pigs',
    'enterAtLeastOne': 'Enter at least one pig.',
    'onlyAvailable': 'Only {count} pigs are listed.',
    'messageFarm': 'Message to the farm (optional)',
    'cancel': 'Cancel',
    'requestSent': 'Your request was sent to the farm.',
    'requestFailed': 'Could not send your request',
    'couldNotRefresh': 'Could not refresh pigs',
    'delivery': 'Delivery',
    'signOut': 'Sign out',
    'chooseLanguage': 'Choose your language',
    'languageSubtitle': 'Select a language to get started.',
    'continue': 'Continue',
    'welcomeBack': 'Welcome back',
    'signInSubtitle': 'Sign in to find pigs and track your requests.',
    'emailOrPhone': 'Email or phone',
    'password': 'Password',
    'forgotPassword': 'Forgot password?',
    'signIn': 'Sign in',
    'createAccount': 'Create buyer account',
    'signupSubtitle': 'Create an account to contact farms and track delivery.',
    'fullName': 'Full name',
    'email': 'Email address',
    'phone': 'Phone number',
    'confirmPassword': 'Confirm password',
    'passwordMismatch': 'Passwords do not match.',
    'required': 'This field is required.',
    'passwordLength': 'Use at least 8 characters.',
    'emailInvalid': 'Enter a valid email address.',
    'forgotSubtitle': 'We will email you a secure password reset link.',
    'sendResetLink': 'Send reset link',
    'resetSent': 'If that email is registered, a reset link has been sent.',
    'verifyEmail': 'Verify your sign in',
    'otpSent': 'Enter the code sent to',
    'verificationCode': '6-digit verification code',
    'codeRequired': 'Enter the 6-digit code.',
    'verifySignIn': 'Verify and sign in',
    'resendCode': 'Resend code',
    'connectionError': 'We could not check your saved sign-in. Please sign in.',
    'noDeliveries':
        'Your delivery requests will appear here after you contact a farm.',
    'awaitingFarm': 'Awaiting farm',
    'requestAccepted': 'Accepted',
    'requestDeclined': 'Declined',
    'deliveryComplete': 'Completed',
    'location': 'Location',
    'requestedOn': 'Requested',
    'pendingHelp': 'The farm has your request and will contact you to confirm.',
    'acceptedHelp':
        'The farm accepted your request. Contact them to agree on delivery.',
    'deliveryCompleteHelp': 'The farm marked this request as completed.',
    'contactFarmForHelp':
        'Please contact the farm directly about this request.',
    'contactFarm': 'Contact the farm',
  },
  'sw': {
    'marketplace': 'Soko la Wanunuzi',
    'home': 'Nyumbani',
    'profile': 'Wasifu',
    'notifications': 'Arifa',
    'searchListings': 'Tafuta aina, shamba au mahali',
    'filterBreed': 'Aina',
    'allBreeds': 'Aina zote',
    'requestToBuy': 'Omba kununua',
    'moreFilters': 'Vichujio zaidi',
    'filterListings': 'Chuja matangazo',
    'filterLocation': 'Mahali',
    'currency': 'Sarafu',
    'anyCurrency': 'Sarafu yoyote',
    'minPrice': 'Bei ya chini',
    'maxPrice': 'Bei ya juu',
    'minAgeWeeks': 'Umri wa chini (wiki)',
    'maxAgeWeeks': 'Umri wa juu (wiki)',
    'minWeightKg': 'Uzito wa chini (kg)',
    'maxWeightKg': 'Uzito wa juu (kg)',
    'clearFilters': 'Futa',
    'applyFilters': 'Tumia vichujio',
    'invalidFilterRange': 'Hakikisha thamani ni sahihi na mipaka imepangwa.',
    'chooseCurrencyForPrice': 'Chagua sarafu ili kuchuja kwa bei.',
    'sortBy': 'Panga',
    'sortNewest': 'Mpya zaidi',
    'sortPriceLow': 'Bei ya chini',
    'sortPriceHigh': 'Bei ya juu',
    'sortWeight': 'Mzito zaidi',
    'breed': 'Aina',
    'weight': 'Uzito',
    'age': 'Umri',
    'notProvided': 'Haijatolewa',
    'farmDescription': 'Maelezo ya shamba',
    'noPigs': 'Hakuna nguruwe wanaopatikana kwa sasa.',
    'noMatches': 'Hakuna nguruwe wanaolingana na utafutaji wako.',
    'locationUnknown': 'Mahali hakujatajwa',
    'weeks': 'wiki',
    'available': 'wanapatikana',
    'each': 'kila mmoja',
    'request': 'Omba',
    'emailOptional': 'Barua pepe (si lazima)',
    'numberPigs': 'Idadi ya nguruwe',
    'enterAtLeastOne': 'Weka angalau nguruwe mmoja.',
    'onlyAvailable': 'Nguruwe {count} pekee ndio waliotangazwa.',
    'messageFarm': 'Ujumbe kwa shamba (si lazima)',
    'cancel': 'Ghairi',
    'requestSent': 'Ombi lako limetumwa kwa shamba.',
    'requestFailed': 'Ombi halikuweza kutumwa',
    'couldNotRefresh': 'Nguruwe hawakuweza kupakiwa upya',
    'delivery': 'Uwasilishaji',
    'signOut': 'Ondoka',
    'chooseLanguage': 'Chagua lugha yako',
    'languageSubtitle': 'Chagua lugha ili kuendelea.',
    'continue': 'Endelea',
    'welcomeBack': 'Karibu tena',
    'signInSubtitle': 'Ingia kutafuta nguruwe na kufuatilia maombi yako.',
    'emailOrPhone': 'Barua pepe au simu',
    'password': 'Nenosiri',
    'forgotPassword': 'Umesahau nenosiri?',
    'signIn': 'Ingia',
    'createAccount': 'Fungua akaunti ya mnunuzi',
    'signupSubtitle':
        'Fungua akaunti ili kuwasiliana na mashamba na kufuatilia uwasilishaji.',
    'fullName': 'Jina kamili',
    'email': 'Anwani ya barua pepe',
    'phone': 'Nambari ya simu',
    'confirmPassword': 'Thibitisha nenosiri',
    'passwordMismatch': 'Nenosiri hazilingani.',
    'required': 'Sehemu hii inahitajika.',
    'passwordLength': 'Tumia angalau herufi 8.',
    'emailInvalid': 'Weka anwani sahihi ya barua pepe.',
    'forgotSubtitle': 'Tutakutumia kiungo salama cha kubadilisha nenosiri.',
    'sendResetLink': 'Tuma kiungo',
    'resetSent':
        'Ikiwa barua pepe imesajiliwa, kiungo cha kubadilisha nenosiri kimetumwa.',
    'verifyEmail': 'Thibitisha kuingia',
    'otpSent': 'Weka msimbo uliotumwa kwa',
    'verificationCode': 'Msimbo wa tarakimu 6',
    'codeRequired': 'Weka msimbo wa tarakimu 6.',
    'verifySignIn': 'Thibitisha na uingie',
    'resendCode': 'Tuma msimbo tena',
    'connectionError': 'Hatukuweza kuthibitisha akaunti yako. Tafadhali ingia.',
    'noDeliveries':
        'Maombi yako ya uwasilishaji yataonekana hapa baada ya kuwasiliana na shamba.',
    'awaitingFarm': 'Inasubiri shamba',
    'requestAccepted': 'Imekubaliwa',
    'requestDeclined': 'Imekataliwa',
    'deliveryComplete': 'Imekamilika',
    'location': 'Mahali',
    'requestedOn': 'Tarehe ya ombi',
    'pendingHelp': 'Shamba limepokea ombi lako na litawasiliana nawe.',
    'acceptedHelp':
        'Shamba limekubali ombi lako. Wasiliana nao kupanga uwasilishaji.',
    'deliveryCompleteHelp': 'Shamba limeweka ombi hili kuwa limekamilika.',
    'contactFarmForHelp': 'Tafadhali wasiliana na shamba kuhusu ombi hili.',
    'contactFarm': 'Wasiliana na shamba',
  },
};
