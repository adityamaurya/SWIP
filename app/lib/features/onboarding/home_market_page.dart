import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/home_market.dart';
import '../../core/theme/swip_tokens.dart';

/// `S-23` — where do you live? `F-15`.
///
/// One question, asked once, at first run. It is the baseline every later
/// "domestic or international" verdict is measured against (`F-14`, `F-16`).
///
/// Deliberately **not** inferred from the SIM, the locale or an IP lookup. A
/// person with an Indian card and a European SIM would be told every purchase
/// at home was international, which is the exact opposite of useful — and it
/// would be wrong silently. Asking costs one screen and is right every time.
///
/// The currency follows the country by default and stays editable, because the
/// two genuinely come apart: someone living in Dubai may still settle on an
/// Indian card, and their "domestic" is not their currency.
class HomeMarketPage extends ConsumerStatefulWidget {
  const HomeMarketPage({super.key, this.initial, this.isOnboarding = true});

  final HomeMarket? initial;

  /// Onboarding cannot be dismissed; Settings can.
  final bool isOnboarding;

  @override
  ConsumerState<HomeMarketPage> createState() => _HomeMarketPageState();
}

class _HomeMarketPageState extends ConsumerState<HomeMarketPage> {
  final _search = TextEditingController();
  late Country? _selected = Countries.byCode(widget.initial?.countryCode);
  late String? _currency = widget.initial?.currency;
  bool _saving = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final country = _selected;
    if (country == null || _saving) return;
    setState(() => _saving = true);

    final service = await ref.read(homeMarketServiceProvider.future);
    await service.set(HomeMarket(
      countryCode: country.code,
      currency: _currency ?? country.currency,
    ));
    ref.read(homeMarketRevisionProvider.notifier).state++;

    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final results = Countries.search(_search.text);

    return Scaffold(
      backgroundColor: SwipColors.bg,
      appBar: widget.isOnboarding
          ? null
          : AppBar(title: const Text('Home country')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SwipSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: SwipSpace.xl),

              Text('Where do you live?',
                      style: SwipType.titleL
                          .copyWith(color: SwipColors.textPrimary))
                  .animate()
                  .fadeIn(duration: 420.ms)
                  .moveY(begin: 12, curve: SwipMotion.captureCurve),

              const SizedBox(height: SwipSpace.sm),

              Text(
                'The same category earns differently at home and abroad. SWIP '
                'compares every capture against this, so it can tell you which '
                'one you are looking at.',
                style: SwipType.bodyM.copyWith(color: SwipColors.textSecondary),
              )
                  .animate()
                  .fadeIn(delay: 100.ms, duration: 420.ms)
                  .moveY(begin: 12, curve: SwipMotion.captureCurve),

              const SizedBox(height: SwipSpace.xl),

              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                style: SwipType.bodyM.copyWith(color: SwipColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Search country or currency',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                ),
              ),

              const SizedBox(height: SwipSpace.md),

              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Text(
                          'No match. SWIP still reads codes from everywhere - '
                          'this only sets what counts as home.',
                          textAlign: TextAlign.center,
                          style: SwipType.bodyS
                              .copyWith(color: SwipColors.textTertiary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, i) {
                          final c = results[i];
                          final selected = _selected?.code == c.code;
                          return _CountryTile(
                            country: c,
                            selected: selected,
                            onTap: () => setState(() {
                              _selected = c;
                              _currency = c.currency;
                            }),
                          )
                              .animate()
                              .fadeIn(
                                  delay: (i.clamp(0, 14) * 20).ms,
                                  duration: 220.ms);
                        },
                      ),
              ),

              if (_selected != null) _currencyRow(_selected!),

              const SizedBox(height: SwipSpace.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selected == null || _saving ? null : _save,
                  child: Text(_selected == null
                      ? 'Pick your country'
                      : 'Home is ${_selected!.name}'),
                ),
              ),
              const SizedBox(height: SwipSpace.lg),
            ],
          ),
        ),
      ),
    );
  }

  /// Currency follows the country but is not welded to it — see the class doc.
  Widget _currencyRow(Country c) => Container(
        padding: const EdgeInsets.all(SwipSpace.md),
        decoration: BoxDecoration(
          color: SwipColors.surfaceRaised,
          borderRadius: SwipRadius.inputAll,
          border: SwipElevation.e1,
        ),
        child: Row(
          children: [
            const Icon(Icons.payments_outlined,
                size: 18, color: SwipColors.gold500),
            const SizedBox(width: SwipSpace.sm),
            Expanded(
              child: Text('Home currency',
                  style: SwipType.bodyM
                      .copyWith(color: SwipColors.textSecondary)),
            ),
            DropdownButton<String>(
              value: _currency ?? c.currency,
              underline: const SizedBox.shrink(),
              dropdownColor: SwipColors.surfaceRaised2,
              style: SwipType.label.copyWith(color: SwipColors.gold500),
              items: [
                for (final code in _currencyChoices(c))
                  DropdownMenuItem(value: code, child: Text(code)),
              ],
              onChanged: (v) => setState(() => _currency = v),
            ),
          ],
        ),
      );

  /// The country's own currency first, then the handful people actually hold a
  /// card in. A full ISO 4217 list is 180 entries of noise.
  static List<String> _currencyChoices(Country c) {
    final list = <String>[
      c.currency,
      for (final code in const ['INR', 'USD', 'EUR', 'GBP', 'AED', 'SGD'])
        if (code != c.currency) code,
    ];
    return list;
  }
}

class _CountryTile extends StatelessWidget {
  const _CountryTile({
    required this.country,
    required this.selected,
    this.onTap,
  });

  final Country country;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: SwipRadius.inputAll,
          child: Container(
            margin: const EdgeInsets.only(bottom: SwipSpace.xs),
            padding: const EdgeInsets.symmetric(
                horizontal: SwipSpace.md, vertical: SwipSpace.md),
            decoration: BoxDecoration(
              color:
                  selected ? SwipColors.gold900 : SwipColors.surfaceRaised,
              borderRadius: SwipRadius.inputAll,
              border: Border.all(
                color: selected ? SwipColors.gold500 : SwipColors.hairline,
              ),
            ),
            child: Row(
              children: [
                Text(country.flag, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: SwipSpace.md),
                Expanded(
                  child: Text(
                    country.name,
                    style: SwipType.bodyM.copyWith(
                        color: selected
                            ? SwipColors.gold300
                            : SwipColors.textPrimary),
                  ),
                ),
                Text(
                  country.currency,
                  style: SwipType.bodyS
                      .copyWith(color: SwipColors.textTertiary),
                ),
                if (selected) ...[
                  const SizedBox(width: SwipSpace.sm),
                  const Icon(Icons.check_circle_rounded,
                      size: 18, color: SwipColors.gold500),
                ],
              ],
            ),
          ),
        ),
      );
}
