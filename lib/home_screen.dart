import 'dart:async';
import 'dart:math' show pi;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'amount_history_service.dart';
import 'app_colors.dart';
import 'currency_service.dart';
import 'favorites_service.dart';
import 'format_utils.dart';
import 'quick_rates_service.dart';
import 'widget_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _amountController = TextEditingController(text: '1.00');
  String _fromCurrency = 'USD';
  String _toCurrency = 'EUR';
  double? _rate;
  bool _loading = false;
  String? _error;
  bool _usingCache = false;
  bool _isInitialFetch = true;

  BannerAd? _bannerAd;
  bool _bannerAdLoaded = false;

  // Replace with your production ad unit ID from the AdMob console.
  static const _bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  final _currencyService = CurrencyService();
  final _favoritesService = FavoritesService();
  final _amountHistoryService = AmountHistoryService();
  final _quickRatesService = QuickRatesService();

  List<CurrencyPair> _favorites = [];
  List<CurrencyPair> _recents = [];
  bool _isFavorite = false;
  List<double> _amountHistory = [];
  Timer? _historyTimer;
  List<int> _quickRateAmounts = List.of(QuickRatesService.defaultAmounts);
  bool _hasCustomQuickRates = false;

  late final AnimationController _swapAnimController;
  late final AnimationController _bgAnimController;
  late final AnimationController _refreshAnimController;
  late final AnimationController _themeAnimController;

  @override
  void initState() {
    super.initState();
    _swapAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _refreshAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _themeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: widget.isDark ? 1.0 : 0.0,
    );
    _fetchRate();
    _loadBannerAd();
    _loadFavoritesAndRecents();
    _amountController.addListener(_onAmountChanged);
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _bannerAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
        },
      ),
    )..load();
  }

  Future<void> _fetchRate() async {
    setState(() {
      _loading = true;
      _error = null;
      _usingCache = false;
    });
    _startRefreshAnimation();

    final result = await _currencyService.fetchRate(_fromCurrency, _toCurrency);

    if (!mounted) return;

    _stopRefreshAnimation();

    setState(() {
      _loading = false;
      _rate = result.rate;
      _usingCache = result.fromCache;
      if (result.rate == null) {
        _error = 'Failed to fetch exchange rate.\nCheck your connection.';
      }
    });

    // Skip haptic feedback on the initial silent load; only fire for user-triggered refreshes.
    if (!_isInitialFetch) {
      if (result.rate != null) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.vibrate();
      }
    }
    _isInitialFetch = false;

    if (result.rate != null) {
      await WidgetService.updateWidget(
        fromCurrency: _fromCurrency,
        toCurrency: _toCurrency,
        rate: result.rate!,
      );
      await _favoritesService.addRecent(_fromCurrency, _toCurrency);
    }

    // Refresh favorite status and recents for the current pair.
    await _loadFavoritesAndRecents();
    await _loadAmountHistory();
    await _loadQuickRates();
  }

  void _swapCurrencies() {
    HapticFeedback.mediumImpact();
    _swapAnimController.forward(from: 0);
    setState(() {
      final tmp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = tmp;
    });
    _fetchRate();
  }

  double get _convertedAmount {
    final input = double.tryParse(_amountController.text) ?? 0;
    return input * (_rate ?? 0);
  }

  void _startRefreshAnimation() {
    if (!_refreshAnimController.isAnimating) {
      _refreshAnimController.repeat();
    }
  }

  void _stopRefreshAnimation() {
    if (!_refreshAnimController.isAnimating) return;
    final progress = _refreshAnimController.value;
    if (progress == 0.0) {
      _refreshAnimController.stop();
      return;
    }
    _refreshAnimController
        .animateTo(
      1.0,
      duration: Duration(milliseconds: ((1.0 - progress) * 450).round()),
      curve: Curves.easeOut,
    )
        .then((_) {
      if (mounted) _refreshAnimController.value = 0;
    });
  }

  Future<void> _loadFavoritesAndRecents() async {
    final favoritesFuture = _favoritesService.getFavorites();
    final recentsFuture = _favoritesService.getRecents();

    final favorites = await favoritesFuture;
    final recents = await recentsFuture;

    final isFav = favorites.any(
      (pair) => pair.from == _fromCurrency && pair.to == _toCurrency,
    );
    if (mounted) {
      setState(() {
        _favorites = favorites;
        _recents = recents;
        _isFavorite = isFav;
      });
    }
  }

  Future<void> _loadAmountHistory() async {
    final history =
        await _amountHistoryService.getHistory(_fromCurrency, _toCurrency);
    if (mounted) setState(() => _amountHistory = history);
  }

  void _onAmountChanged() {
    _historyTimer?.cancel();
    _historyTimer = Timer(
      const Duration(milliseconds: 1500),
      _saveAmountToHistory,
    );
  }

  Future<void> _saveAmountToHistory() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;
    // Capture currencies before the async gap to avoid saving to the wrong
    // pair if the user switches currencies while the save is in flight.
    final from = _fromCurrency;
    final to = _toCurrency;
    await _amountHistoryService.addAmount(from, to, amount);
    if (mounted && _fromCurrency == from && _toCurrency == to) {
      await _loadAmountHistory();
    }
  }

  Future<void> _clearAmountHistory() async {
    HapticFeedback.lightImpact();
    await _amountHistoryService.clearHistory(_fromCurrency, _toCurrency);
    if (mounted) setState(() => _amountHistory = []);
  }

  Future<void> _loadQuickRates() async {
    final amounts =
        await _quickRatesService.getAmounts(_fromCurrency, _toCurrency);
    final isCustom =
        await _quickRatesService.hasCustomAmounts(_fromCurrency, _toCurrency);
    if (mounted) {
      setState(() {
        _quickRateAmounts = amounts;
        _hasCustomQuickRates = isCustom;
      });
    }
  }

  Future<void> _saveCurrentAmountToQuickRates() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return;
    final rounded = amount.round();
    if (rounded <= 0) return;
    HapticFeedback.lightImpact();
    await _quickRatesService.addAmount(_fromCurrency, _toCurrency, rounded);
    await _loadQuickRates();
  }

  Future<void> _resetQuickRates() async {
    HapticFeedback.lightImpact();
    await _quickRatesService.resetToDefaults(_fromCurrency, _toCurrency);
    if (mounted) {
      setState(() {
        _quickRateAmounts = List.of(QuickRatesService.defaultAmounts);
        _hasCustomQuickRates = false;
      });
    }
  }

  Future<void> _removeQuickRate(int amount) async {
    HapticFeedback.lightImpact();
    await _quickRatesService.removeAmount(_fromCurrency, _toCurrency, amount);
    await _loadQuickRates();
  }

  String _formatHistoryAmount(double amount) {
    if (amount == amount.truncateToDouble()) return amount.toInt().toString();
    return amount.toStringAsFixed(2);
  }

  Future<void> _toggleFavorite() async {
    HapticFeedback.lightImpact();
    await _favoritesService.toggleFavorite(_fromCurrency, _toCurrency);
    await _loadFavoritesAndRecents();
  }

  Future<void> _removeFavorite(CurrencyPair pair) async {
    HapticFeedback.lightImpact();
    await _favoritesService.toggleFavorite(pair.from, pair.to);
    await _loadFavoritesAndRecents();
  }

  Future<void> _removeRecent(CurrencyPair pair) async {
    HapticFeedback.lightImpact();
    await _favoritesService.removeRecent(pair.from, pair.to);
    await _loadFavoritesAndRecents();
  }

  void _loadPair(CurrencyPair pair) {
    HapticFeedback.selectionClick();
    setState(() {
      _fromCurrency = pair.from;
      _toCurrency = pair.to;
    });
    _fetchRate();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDark != widget.isDark) {
      if (widget.isDark) {
        _themeAnimController.forward();
      } else {
        _themeAnimController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _historyTimer?.cancel();
    _amountController.dispose();
    _swapAnimController.dispose();
    _bgAnimController.dispose();
    _refreshAnimController.dispose();
    _themeAnimController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final p = AppPalette.of(context);

    return Scaffold(
      // Banner ad anchored at the bottom
      bottomNavigationBar: _bannerAdLoaded && _bannerAd != null
          ? SafeArea(
              top: false,
              child: SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            )
          : null,
      body: Stack(
        children: [
          // Animated gradient background with orbs
          _AnimatedGradientBackground(controller: _bgAnimController),

          // Content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                final hPad = isWide ? constraints.maxWidth * 0.15 : 24.0;
                return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(hPad, 48, hPad, 0),
                      child: _buildHeader(textTheme),
                    ),
                    const SizedBox(height: 32),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async {
                          HapticFeedback.mediumImpact();
                          await _fetchRate();
                        },
                        displacement: 48,
                        strokeWidth: 1.5,
                        color: p.refreshFg,
                        backgroundColor: p.refreshBg,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.symmetric(horizontal: hPad),
                          children: [
                            _buildAmountCard(textTheme),
                            const SizedBox(height: 20),
                            _buildCurrencySelectorCard(textTheme),
                            const SizedBox(height: 24),
                            _buildResultArea(textTheme),
                            const SizedBox(height: 20),
                            _loading && _favorites.isEmpty && _recents.isEmpty
                                ? _buildFavoritesLoadingState(textTheme)
                                : _buildFavoritesAndRecents(textTheme),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // -- Header --

  Widget _buildHeader(TextTheme textTheme) {
    final p = AppPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Currex',
              style: textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Currency Converter',
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w300,
                color: p.textMuted,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const Spacer(),
        _buildThemeToggleButton(),
        const SizedBox(width: 8),
        _buildFavoriteButton(),
        const SizedBox(width: 8),
        _buildRefreshButton(),
      ],
    );
  }

  Widget _buildThemeToggleButton() {
    final p = AppPalette.of(context);
    return Semantics(
      label: widget.isDark ? 'Switch to light theme' : 'Switch to dark theme',
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onToggleTheme();
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: p.glassFill,
            border: Border.all(color: p.glassBorder),
          ),
          child: AnimatedBuilder(
            animation: _themeAnimController,
            builder: (context, _) {
              final t = _themeAnimController.value;
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Sun (visible when t → 0, i.e. light mode)
                  Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0),
                    child: Transform.rotate(
                      angle: t * pi,
                      child: Transform.scale(
                        scale: 1.0 - t * 0.4,
                        child: const Icon(
                          Icons.wb_sunny_rounded,
                          color: Colors.amber,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  // Moon (visible when t → 1, i.e. dark mode)
                  Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: Transform.rotate(
                      angle: (1 - t) * -pi,
                      child: Transform.scale(
                        scale: 0.6 + t * 0.4,
                        child: Icon(
                          Icons.nightlight_round,
                          color: p.refreshFg,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteButton() {
    final p = AppPalette.of(context);
    return Semantics(
      label: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
      button: true,
      child: GestureDetector(
        onTap: _toggleFavorite,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isFavorite ? Colors.amber.withAlpha(31) : p.glassFill,
            border: Border.all(
              color: _isFavorite ? Colors.amber.withAlpha(102) : p.glassBorder,
            ),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                key: ValueKey(_isFavorite),
                color:
                    _isFavorite ? Colors.amber.withAlpha(230) : p.iconPrimary,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    final p = AppPalette.of(context);
    return Semantics(
      label: 'Refresh exchange rate',
      button: true,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: _loading ? 0.4 : 1.0,
        child: GestureDetector(
          onTap: _loading
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  _fetchRate();
                },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: p.glassFill,
              border: Border.all(color: p.glassBorder),
            ),
            child: Center(
              child: RotationTransition(
                turns: _refreshAnimController,
                child: Icon(
                  Icons.refresh_rounded,
                  color: p.iconPrimary,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -- Amount Card --

  Widget _buildAmountCard(TextTheme textTheme) {
    final p = AppPalette.of(context);
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'AMOUNT',
                style: textTheme.labelSmall?.copyWith(
                  color: p.textMuted,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _saveCurrentAmountToQuickRates,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_circle_outline_rounded,
                        size: 14,
                        color: p.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'QUICK RATE',
                        style: textTheme.labelSmall?.copyWith(
                          color: p.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'Enter amount to convert',
            child: TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: p.textPrimary,
              ),
              cursorColor: AppColors.purple,
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: textTheme.headlineMedium?.copyWith(
                  color: p.textHint,
                  fontWeight: FontWeight.w300,
                ),
                prefixIcon: Container(
                  margin: const EdgeInsets.only(left: 12, right: 8),
                  child: Icon(
                    Icons.monetization_on_rounded,
                    color: AppColors.purple.withAlpha(204),
                    size: 28,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                _historyTimer?.cancel();
                _saveAmountToHistory();
              },
            ),
          ),
        ],
      ),
    );
  }

  // -- Currency Selector --

  Widget _buildCurrencySelectorCard(TextTheme textTheme) {
    return _GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _GlassCurrencyPicker(
              label: 'FROM',
              value: _fromCurrency,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _fromCurrency = v!);
                _fetchRate();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: RotationTransition(
              turns: Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
                parent: _swapAnimController,
                curve: Curves.easeOutCubic,
              )),
              child: Semantics(
                label: 'Swap currencies',
                button: true,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.purple.withAlpha(153),
                        AppColors.blue.withAlpha(153),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: AppPalette.of(context).glassBorder,
                    ),
                  ),
                  child: IconButton(
                    onPressed: _swapCurrencies,
                    icon: const Icon(
                      Icons.swap_horiz_rounded,
                      color: Colors.white,
                    ),
                    iconSize: 24,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _GlassCurrencyPicker(
              label: 'TO',
              value: _toCurrency,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _toCurrency = v!);
                _fetchRate();
              },
            ),
          ),
        ],
      ),
    );
  }

  // -- Favorites & Recents --

  Widget _buildFavoritesAndRecents(TextTheme textTheme) {
    if (_favorites.isEmpty && _recents.isEmpty) return const SizedBox.shrink();
    final p = AppPalette.of(context);

    final nonFavRecents =
        _recents.where((pair) => !_favorites.contains(pair)).take(5).toList();

    return _GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_favorites.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.star_rounded, size: 14, color: p.textMuted),
                const SizedBox(width: 6),
                Text(
                  'FAVORITES',
                  style: textTheme.labelSmall?.copyWith(
                    color: p.textMuted,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _favorites
                    .map((pair) => _PairChip(
                          pair: pair,
                          onTap: () => _loadPair(pair),
                          onRemove: () => _removeFavorite(pair),
                          highlight: pair.from == _fromCurrency &&
                              pair.to == _toCurrency,
                        ))
                    .toList(),
              ),
            ),
          ],
          if (_favorites.isNotEmpty &&
              _recents.isNotEmpty &&
              nonFavRecents.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Container(height: 1, color: p.divider),
            ),
          if (_recents.isNotEmpty && nonFavRecents.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.history_rounded, size: 14, color: p.textMuted),
                const SizedBox(width: 6),
                Text(
                  'RECENT',
                  style: textTheme.labelSmall?.copyWith(
                    color: p.textMuted,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...nonFavRecents.map((pair) => _RecentRow(
                  pair: pair,
                  onTap: () => _loadPair(pair),
                  onRemove: () => _removeRecent(pair),
                  active: pair.from == _fromCurrency && pair.to == _toCurrency,
                )),
          ],
        ],
      ),
    );
  }

  // -- Result Area --

  Widget _buildResultArea(TextTheme textTheme) {
    // Determine the child to display:
    // - Error takes priority
    // - Show loading skeleton only on initial fetch (no rate yet)
    // - Otherwise show success state, dimmed while refreshing
    final Widget child;
    if (_error != null && !_loading) {
      child = _buildErrorState(textTheme);
    } else if (_rate == null && _loading) {
      child = _buildLoadingState(textTheme);
    } else if (_rate == null && _error != null) {
      child = _buildErrorState(textTheme);
    } else if (_rate != null) {
      child = AnimatedOpacity(
        key: ValueKey('success-$_fromCurrency-$_toCurrency'),
        duration: const Duration(milliseconds: 250),
        opacity: _loading ? 0.5 : 1.0,
        child: _buildSuccessState(textTheme),
      );
    } else {
      child = _buildLoadingState(textTheme);
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1.0,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildLoadingState(TextTheme textTheme) {
    final p = AppPalette.of(context);
    return _GlassCard(
      key: const ValueKey('loading'),
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        height: 142,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left: mirrors converted-amount column
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SkeletonLine(width: 120, height: 42),
                  SizedBox(height: 4),
                  _SkeletonLine(width: 52, height: 17),
                  SizedBox(height: 16),
                  _SkeletonLine(width: double.infinity, height: 30),
                ],
              ),
            ),
            // Vertical divider
            Container(
              width: 1,
              color: p.divider,
              margin: const EdgeInsets.symmetric(horizontal: 12),
            ),
            // Right: mirrors rate table
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const _SkeletonLine(width: 28, height: 9),
                const SizedBox(height: 8),
                for (final _ in const [0, 1, 2, 3])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        _SkeletonLine(width: 20, height: 9),
                        SizedBox(width: 18),
                        _SkeletonLine(width: 44, height: 9),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesLoadingState(TextTheme textTheme) {
    final p = AppPalette.of(context);
    return _GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Favorites section header
          const Row(
            children: [
              _SkeletonLine(width: 14, height: 14),
              SizedBox(width: 6),
              _SkeletonLine(width: 80, height: 10),
            ],
          ),
          const SizedBox(height: 12),
          // Chip row: mirrors horizontal _PairChip list
          const Row(
            children: [
              _SkeletonLine(width: 92, height: 32),
              SizedBox(width: 8),
              _SkeletonLine(width: 92, height: 32),
              SizedBox(width: 8),
              _SkeletonLine(width: 92, height: 32),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Container(height: 1, color: p.divider),
          ),
          // Recents section header
          const Row(
            children: [
              _SkeletonLine(width: 14, height: 14),
              SizedBox(width: 6),
              _SkeletonLine(width: 56, height: 10),
            ],
          ),
          const SizedBox(height: 8),
          // Recent rows: mirrors _RecentRow (full-width, vertical padding 10)
          for (final _ in const [0, 1, 2])
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: _SkeletonLine(width: double.infinity, height: 34),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState(TextTheme textTheme) {
    final p = AppPalette.of(context);
    return _GlassCard(
      key: const ValueKey('error'),
      borderColor: Colors.red.withAlpha(77),
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withAlpha(31),
            ),
            child: Icon(
              Icons.cloud_off_rounded,
              size: 32,
              color: Colors.red.withAlpha(204),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: p.textMedium,
            ),
          ),
          const SizedBox(height: 20),
          _GlassButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              _fetchRate();
            },
            label: 'Retry',
            icon: Icons.refresh_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState(TextTheme textTheme) {
    final p = AppPalette.of(context);
    return _GlassCard(
      key: const ValueKey('success'),
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        height: 142,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left: result info
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _convertedAmount.toStringAsFixed(2),
                        key: ValueKey(_convertedAmount.toStringAsFixed(2)),
                        maxLines: 1,
                        style: textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: p.textPrimary,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _toCurrency,
                    style: textTheme.titleMedium?.copyWith(
                      color: AppColors.purple.withAlpha(204),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: p.glassFill,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: p.glassBorder),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '1 $_fromCurrency = ${_rate?.toStringAsFixed(2) ?? '—'} $_toCurrency',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: p.textMedium,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  if (_usingCache) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.offline_bolt_rounded,
                          size: 12,
                          color: Colors.amber.withAlpha(179),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Cached rate',
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.amber.withAlpha(179),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Divider
            Container(
              width: 1,
              color: p.divider,
              margin: const EdgeInsets.symmetric(horizontal: 12),
            ),
            // Right: rate table (always visible)
            _RateTable(
              rate: _rate!,
              fromCurrency: _fromCurrency,
              toCurrency: _toCurrency,
              amounts: _quickRateAmounts,
              onRemove: _removeQuickRate,
              onReset: _resetQuickRates,
              hasCustomRates: _hasCustomQuickRates,
              onAmountSelected: (amount) {
                _amountController.text = amount.toString();
                setState(() {});
              },
            ),
            // Amount history (when available)
            if (_amountHistory.isNotEmpty) ...[
              Container(
                width: 1,
                color: p.divider,
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              _AmountHistoryPanel(
                history: _amountHistory,
                rate: _rate!,
                fromCurrency: _fromCurrency,
                toCurrency: _toCurrency,
                onAmountSelected: (amount) {
                  _amountController.text = _formatHistoryAmount(amount);
                  setState(() {});
                },
                onClear: _clearAmountHistory,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// RATE TABLE
// ===========================================================================

class _RateTable extends StatelessWidget {
  const _RateTable({
    required this.rate,
    required this.fromCurrency,
    required this.toCurrency,
    required this.amounts,
    required this.onRemove,
    required this.onReset,
    required this.hasCustomRates,
    required this.onAmountSelected,
  });

  final double rate;
  final String fromCurrency;
  final String toCurrency;
  final List<int> amounts;
  final ValueChanged<int> onRemove;
  final VoidCallback onReset;
  final bool hasCustomRates;
  final ValueChanged<int> onAmountSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final p = AppPalette.of(context);
    final labelStyle = textTheme.labelSmall?.copyWith(
      color: p.textMuted,
      letterSpacing: 2,
      fontWeight: FontWeight.w600,
      fontSize: 9,
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title (sticky)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('QUICK RATES', style: labelStyle),
            if (hasCustomRates) ...[
              const SizedBox(width: 6),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onReset,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.restart_alt_rounded,
                    size: 12,
                    color: p.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        // Column headers (sticky)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                fromCurrency,
                textAlign: TextAlign.left,
                style: labelStyle,
              ),
            ),
            const SizedBox(width: 24),
            SizedBox(
              width: 44,
              child: Text(
                toCurrency,
                textAlign: TextAlign.right,
                style: labelStyle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Scrollable rows
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: amounts.map((a) {
                final converted = formatCompactAmount(a * rate);
                final source = formatCompactInt(a);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onAmountSelected(a),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 34,
                          child: Text(
                            source,
                            textAlign: TextAlign.left,
                            style: textTheme.labelSmall?.copyWith(
                              color: p.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Container(
                            width: 10,
                            height: 1,
                            color: p.glassBorder,
                          ),
                        ),
                        SizedBox(
                          width: 48,
                          child: Text(
                            converted,
                            textAlign: TextAlign.right,
                            style: textTheme.bodySmall?.copyWith(
                              color: p.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onRemove(a),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.close_rounded,
                              size: 10,
                              color: p.iconDim,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// AMOUNT HISTORY PANEL
// ===========================================================================

/// Displays the per-pair history of searched amounts in the result card's
/// right panel.  Each row is tappable to restore the amount into the input
/// field.  A clear button removes all entries for the current pair.
class _AmountHistoryPanel extends StatelessWidget {
  const _AmountHistoryPanel({
    required this.history,
    required this.rate,
    required this.fromCurrency,
    required this.toCurrency,
    required this.onAmountSelected,
    required this.onClear,
  });

  final List<double> history;
  final double rate;
  final String fromCurrency;
  final String toCurrency;
  final ValueChanged<double> onAmountSelected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final p = AppPalette.of(context);
    final labelStyle = textTheme.labelSmall?.copyWith(
      color: p.textMuted,
      letterSpacing: 2,
      fontWeight: FontWeight.w600,
      fontSize: 9,
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label + clear button
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('HISTORY', style: labelStyle),
            const SizedBox(width: 6),
            Semantics(
              label: 'Clear amount history',
              button: true,
              child: GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.clear_all_rounded,
                  size: 12,
                  color: p.iconDim,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Column headers
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              child: Text(fromCurrency,
                  textAlign: TextAlign.left, style: labelStyle),
            ),
            const SizedBox(width: 24),
            SizedBox(
              width: 44,
              child: Text(toCurrency,
                  textAlign: TextAlign.right, style: labelStyle),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Scrollable history rows
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: history.map((amount) {
                final converted = formatCompactAmount(amount * rate);
                final amountStr = formatCompactAmount(amount);
                return Semantics(
                  label:
                      '$amountStr $fromCurrency = $converted $toCurrency, tap to use',
                  button: true,
                  child: GestureDetector(
                    onTap: () => onAmountSelected(amount),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              amountStr,
                              textAlign: TextAlign.left,
                              // labelSmall for the source amount (dimmer, smaller) —
                              // intentionally matches _RateTable's FROM-column style.
                              style: textTheme.labelSmall?.copyWith(
                                color: p.textMedium,
                                fontSize: 10,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Container(
                              width: 12,
                              height: 1,
                              color: p.glassBorder,
                            ),
                          ),
                          SizedBox(
                            width: 44,
                            child: Text(
                              converted,
                              textAlign: TextAlign.right,
                              // bodySmall for the converted result (brighter, bolder) —
                              // intentionally matches _RateTable's TO-column style.
                              style: textTheme.bodySmall?.copyWith(
                                color: p.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// GLASSMORPHISM PRIMITIVES
// ===========================================================================

/// A pulsing skeleton line used as a loading placeholder.
class _SkeletonLine extends StatefulWidget {
  const _SkeletonLine({required this.width, required this.height});

  final double width;
  final double height;

  @override
  State<_SkeletonLine> createState() => _SkeletonLineState();
}

class _SkeletonLineState extends State<_SkeletonLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final alpha = lerpDouble(AppColors.skeletonAlphaMin,
                AppColors.skeletonAlphaMax, _anim.value)!
            .round();
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.height / 2),
            color: p.textPrimary.withAlpha(alpha),
          ),
        );
      },
    );
  }
}

/// A frosted glass card with blur, semi-transparent fill, and subtle border.
/// Reference: background rgba(255,255,255, 0.05–0.15), blur 20–40px,
/// border 1px rgba(255,255,255, 0.1–0.2), border-radius 24px.
class _GlassCard extends StatelessWidget {
  const _GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: p.glassFill,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: borderColor ?? p.glassBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: p.shadowColor,
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Small translucent button for inline actions.
class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.onPressed,
    required this.label,
    required this.icon,
  });

  final VoidCallback onPressed;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: p.divider,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.glassBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: p.iconPrimary),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: p.textHigh,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Currency picker styled as a frosted glass dropdown.
class _GlassCurrencyPicker extends StatelessWidget {
  const _GlassCurrencyPicker({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final p = AppPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: p.textMuted,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: '$label currency selector',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: p.glassFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.divider),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: p.textMuted,
                  size: 20,
                ),
                dropdownColor: p.dropdownColor,
                borderRadius: BorderRadius.circular(16),
                style: textTheme.titleMedium?.copyWith(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                items: CurrencyService.currencies
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                            '${CurrencyService.currencyFlags[c] ?? ''} $c',
                          ),
                        ))
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// PAIR CHIP — used in the Favorites horizontal scroll row
// ===========================================================================

class _PairChip extends StatelessWidget {
  const _PairChip({
    required this.pair,
    required this.onTap,
    required this.onRemove,
    required this.highlight,
  });

  final CurrencyPair pair;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final fromFlag = CurrencyService.currencyFlags[pair.from] ?? '';
    final toFlag = CurrencyService.currencyFlags[pair.to] ?? '';
    final p = AppPalette.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        label: '${pair.from} to ${pair.to}',
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: highlight ? AppColors.purple.withAlpha(51) : p.glassFill,
              border: Border.all(
                color:
                    highlight ? AppColors.purple.withAlpha(128) : p.glassBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$fromFlag ${pair.from}',
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 13,
                    fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 12,
                    color: p.textMuted,
                  ),
                ),
                Text(
                  '$toFlag ${pair.to}',
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 13,
                    fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onRemove,
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: p.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// RECENT ROW — used in the Recent searches list
// ===========================================================================

class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.pair,
    required this.onTap,
    required this.onRemove,
    required this.active,
  });

  final CurrencyPair pair;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final fromFlag = CurrencyService.currencyFlags[pair.from] ?? '';
    final toFlag = CurrencyService.currencyFlags[pair.to] ?? '';
    final textTheme = Theme.of(context).textTheme;
    final p = AppPalette.of(context);

    return Semantics(
      label: '${pair.from} to ${pair.to} recent search',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: Row(
            children: [
              Icon(
                Icons.history_rounded,
                size: 14,
                color: p.iconDim,
              ),
              const SizedBox(width: 10),
              Text(
                '$fromFlag ${pair.from}',
                style: textTheme.bodyMedium?.copyWith(
                  color: active ? p.textPrimary : p.textMedium,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 12,
                  color: p.iconDim,
                ),
              ),
              Text(
                '$toFlag ${pair.to}',
                style: textTheme.bodyMedium?.copyWith(
                  color: active ? p.textPrimary : p.textMedium,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              const Spacer(),
              if (active)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.purple.withAlpha(204),
                  ),
                ),
              Semantics(
                button: true,
                label: 'Remove ${pair.from} to ${pair.to} from recent searches',
                child: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                  onPressed: onRemove,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// ANIMATED BACKGROUND
// ===========================================================================

/// Animated background with a gradient and floating color orbs.
class _AnimatedGradientBackground extends StatelessWidget {
  const _AnimatedGradientBackground({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors =
        isDark ? AppColors.darkGradient : AppColors.lightGradient;
    final orbAlpha = isDark ? 1.0 : 0.5;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
              stops: const [0.0, 0.2, 0.45, 0.7, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Purple orb — top right
              Positioned(
                top: -60 + (20 * t),
                right: -40 + (30 * t),
                child: _Orb(
                  size: 260,
                  color: AppColors.purple.withAlpha((51 * orbAlpha).round()),
                  blur: 80,
                ),
              ),
              // Blue orb — center left
              Positioned(
                top: MediaQuery.of(context).size.height * 0.35 + (15 * t),
                left: -60 + (25 * t),
                child: _Orb(
                  size: 200,
                  color: AppColors.blue.withAlpha((38 * orbAlpha).round()),
                  blur: 70,
                ),
              ),
              // Pink orb — bottom right
              Positioned(
                bottom: -40 + (20 * t),
                right: 20 - (20 * t),
                child: _Orb(
                  size: 180,
                  color: AppColors.pink.withAlpha((31 * orbAlpha).round()),
                  blur: 60,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A single soft gradient orb for the background.
class _Orb extends StatelessWidget {
  const _Orb({
    required this.size,
    required this.color,
    required this.blur,
  });

  final double size;
  final Color color;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: blur,
            spreadRadius: blur * 0.5,
          ),
        ],
      ),
    );
  }
}
