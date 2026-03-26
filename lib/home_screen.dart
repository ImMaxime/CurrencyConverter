import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'currency_service.dart';
import 'favorites_service.dart';
import 'widget_service.dart';

/// Gradient background colors for the mesh-like backdrop.
const _kGradientColors = [
  Color(0xFF0D0221),
  Color(0xFF1A0533),
  Color(0xFF2D1B69),
  Color(0xFF1B1464),
  Color(0xFF0F0C29),
];

/// Accent orbs for the animated gradient blobs.
const _kOrbPurple = Color(0xFF7C4DFF);
const _kOrbBlue = Color(0xFF448AFF);
const _kOrbPink = Color(0xFFE040FB);

/// Skeleton shimmer alpha range (min/max out of 255, ~4–12% opacity).
const _kSkeletonAlphaMin = 10;
const _kSkeletonAlphaMax = 30;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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

  List<CurrencyPair> _favorites = [];
  List<CurrencyPair> _recents = [];
  bool _isFavorite = false;

  late final AnimationController _swapAnimController;
  late final AnimationController _bgAnimController;
  late final AnimationController _refreshAnimController;

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
    _fetchRate();
    _loadBannerAd();
    _loadFavoritesAndRecents();
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
  void dispose() {
    _amountController.dispose();
    _swapAnimController.dispose();
    _bgAnimController.dispose();
    _refreshAnimController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
                return RefreshIndicator(
                  onRefresh: () async {
                    HapticFeedback.mediumImpact();
                    await _fetchRate();
                  },
                  // Refined, minimal indicator matching the glass dark theme
                  displacement: 48,
                  strokeWidth: 1.5,
                  color: Colors.white.withAlpha(230),
                  backgroundColor: Colors.white.withAlpha(20),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    children: [
                      const SizedBox(height: 48),
                      _buildHeader(textTheme),
                      const SizedBox(height: 32),
                      _buildAmountCard(textTheme),
                      const SizedBox(height: 20),
                      _buildCurrencySelectorCard(textTheme),
                      const SizedBox(height: 24),
                      _buildResultArea(textTheme),
                      const SizedBox(height: 20),
                      _buildFavoritesAndRecents(textTheme),
                      const SizedBox(height: 40),
                    ],
                  ),
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
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Currency Converter',
              style: textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w300,
                color: Colors.white.withAlpha(128),
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const Spacer(),
        _buildFavoriteButton(),
        const SizedBox(width: 8),
        _buildRefreshButton(),
      ],
    );
  }

  Widget _buildFavoriteButton() {
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
            color: _isFavorite
                ? Colors.amber.withAlpha(31)
                : Colors.white.withAlpha(13),
            border: Border.all(
              color: _isFavorite
                  ? Colors.amber.withAlpha(102)
                  : Colors.white.withAlpha(26),
            ),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                key: ValueKey(_isFavorite),
                color: _isFavorite
                    ? Colors.amber.withAlpha(230)
                    : Colors.white.withAlpha(204),
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
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
              color: Colors.white.withAlpha(13),
              border: Border.all(color: Colors.white.withAlpha(26)),
            ),
            child: Center(
              child: RotationTransition(
                turns: _refreshAnimController,
                child: Icon(
                  Icons.refresh_rounded,
                  color: Colors.white.withAlpha(204),
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
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AMOUNT',
            style: textTheme.labelSmall?.copyWith(
              color: Colors.white.withAlpha(128),
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
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
                color: Colors.white,
              ),
              cursorColor: _kOrbPurple,
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: textTheme.headlineMedium?.copyWith(
                  color: Colors.white.withAlpha(38),
                  fontWeight: FontWeight.w300,
                ),
                prefixIcon: Container(
                  margin: const EdgeInsets.only(left: 12, right: 8),
                  child: Icon(
                    Icons.monetization_on_rounded,
                    color: _kOrbPurple.withAlpha(204),
                    size: 28,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
              ),
              onChanged: (_) => setState(() {}),
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
              turns: Tween(begin: 0.0, end: 0.5).animate(CurvedAnimation(
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
                        _kOrbPurple.withAlpha(153),
                        _kOrbBlue.withAlpha(153),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withAlpha(31),
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
                Icon(Icons.star_rounded,
                    size: 14, color: Colors.amber.withAlpha(204)),
                const SizedBox(width: 6),
                Text(
                  'FAVORITES',
                  style: textTheme.labelSmall?.copyWith(
                    color: Colors.white.withAlpha(128),
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
              child: Container(height: 1, color: Colors.white.withAlpha(20)),
            ),
          if (_recents.isNotEmpty && nonFavRecents.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.history_rounded,
                    size: 14, color: Colors.white.withAlpha(128)),
                const SizedBox(width: 6),
                Text(
                  'RECENT',
                  style: textTheme.labelSmall?.copyWith(
                    color: Colors.white.withAlpha(128),
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: _loading
          ? _buildLoadingState(textTheme)
          : _error != null
              ? _buildErrorState(textTheme)
              : _buildSuccessState(textTheme),
    );
  }

  Widget _buildLoadingState(TextTheme textTheme) {
    return const _GlassCard(
      key: ValueKey('loading'),
      padding: EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Skeleton: result value line
          _SkeletonLine(width: 160, height: 40),
          SizedBox(height: 8),
          // Skeleton: currency label
          _SkeletonLine(width: 80, height: 14),
          SizedBox(height: 20),
          // Skeleton: rate badge
          _SkeletonLine(width: double.infinity, height: 28),
          SizedBox(height: 20),
          // Skeleton: rate table rows
          _SkeletonLine(width: double.infinity, height: 12),
          SizedBox(height: 8),
          _SkeletonLine(width: double.infinity, height: 12),
          SizedBox(height: 8),
          _SkeletonLine(width: double.infinity, height: 12),
          SizedBox(height: 8),
          _SkeletonLine(width: double.infinity, height: 12),
        ],
      ),
    );
  }

  Widget _buildErrorState(TextTheme textTheme) {
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
              color: Colors.white.withAlpha(179),
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
    return _GlassCard(
      key: const ValueKey('success'),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left: result info
            Expanded(
              child: Column(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      _convertedAmount.toStringAsFixed(2),
                      key: ValueKey(_convertedAmount.toStringAsFixed(2)),
                      style: textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _toCurrency,
                    style: textTheme.titleMedium?.copyWith(
                      color: _kOrbPurple.withAlpha(204),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(13),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withAlpha(26)),
                    ),
                    child: Text(
                      '1 $_fromCurrency = ${_rate?.toStringAsFixed(4) ?? '—'} $_toCurrency',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.white.withAlpha(179),
                        fontWeight: FontWeight.w500,
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
              color: Colors.white.withAlpha(20),
              margin: const EdgeInsets.symmetric(horizontal: 12),
            ),
            // Right: rate table
            _RateTable(
              rate: _rate!,
              toCurrency: _toCurrency,
            ),
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
  const _RateTable({required this.rate, required this.toCurrency});

  final double rate;
  final String toCurrency;

  static const _amounts = [10, 50, 100, 250];

  String _fmt(double v) {
    if (v >= 10000) return '${(v / 1000).toStringAsFixed(0)}k';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v >= 100) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          toCurrency,
          style: textTheme.labelSmall?.copyWith(
            color: Colors.white.withAlpha(102),
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
            fontSize: 9,
          ),
        ),
        const SizedBox(height: 8),
        ..._amounts.map((a) {
          final converted = _fmt(a * rate);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '$a',
                    textAlign: TextAlign.right,
                    style: textTheme.labelSmall?.copyWith(
                      color: Colors.white.withAlpha(90),
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
                    color: Colors.white.withAlpha(30),
                  ),
                ),
                Text(
                  converted,
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          );
        }),
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
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final alpha =
            lerpDouble(_kSkeletonAlphaMin, _kSkeletonAlphaMax, _anim.value)!
                .round();
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.height / 2),
            color: Colors.white.withAlpha(alpha),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(13), // ~5% opacity
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: borderColor ?? Colors.white.withAlpha(26), // ~10%
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(26),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withAlpha(18),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withAlpha(31)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: Colors.white.withAlpha(204)),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withAlpha(204),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: Colors.white.withAlpha(102),
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
              color: Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withAlpha(20)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white.withAlpha(102),
                  size: 20,
                ),
                dropdownColor: const Color(0xFF1A1235),
                borderRadius: BorderRadius.circular(16),
                style: textTheme.titleMedium?.copyWith(
                  color: Colors.white,
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
              color: highlight
                  ? _kOrbPurple.withAlpha(51)
                  : Colors.white.withAlpha(13),
              border: Border.all(
                color: highlight
                    ? _kOrbPurple.withAlpha(128)
                    : Colors.white.withAlpha(26),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$fromFlag ${pair.from}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 12,
                    color: Colors.white.withAlpha(128),
                  ),
                ),
                Text(
                  '$toFlag ${pair.to}',
                  style: TextStyle(
                    color: Colors.white,
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
                    color: Colors.white.withAlpha(128),
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

    return Semantics(
      label: '${pair.from} to ${pair.to} recent search',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Icon(
                Icons.history_rounded,
                size: 14,
                color: Colors.white.withAlpha(77),
              ),
              const SizedBox(width: 10),
              Text(
                '$fromFlag ${pair.from}',
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withAlpha(active ? 255 : 179),
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 12,
                  color: Colors.white.withAlpha(77),
                ),
              ),
              Text(
                '$toFlag ${pair.to}',
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withAlpha(active ? 255 : 179),
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
                    color: _kOrbPurple.withAlpha(204),
                  ),
                ),
              Semantics(
                button: true,
                label:
                    'Remove ${pair.from} to ${pair.to} from recent searches',
                child: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.6),
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

/// Animated background with a dark gradient and floating color orbs.
class _AnimatedGradientBackground extends StatelessWidget {
  const _AnimatedGradientBackground({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value;
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _kGradientColors,
              stops: [0.0, 0.2, 0.45, 0.7, 1.0],
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
                  color: _kOrbPurple.withAlpha(51),
                  blur: 80,
                ),
              ),
              // Blue orb — center left
              Positioned(
                top: MediaQuery.of(context).size.height * 0.35 + (15 * t),
                left: -60 + (25 * t),
                child: _Orb(
                  size: 200,
                  color: _kOrbBlue.withAlpha(38),
                  blur: 70,
                ),
              ),
              // Pink orb — bottom right
              Positioned(
                bottom: -40 + (20 * t),
                right: 20 - (20 * t),
                child: _Orb(
                  size: 180,
                  color: _kOrbPink.withAlpha(31),
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
