import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/localization/translations/app_strings.dart';
import '../../../../app/theme/theme.dart';
import '../../../../design_system/design_system.dart';
import '../../application/coordinators/top_up_coordinator.dart';
import '../../domain/entities/wallet.dart';
import '../controllers/wallet_controller.dart';

/// Money, with Latin digits in both languages - the product's rule: a
/// merchant copies these figures into a bank app or a spreadsheet.
String formatWalletMoney(double amount, String currency) =>
    NumberFormat.simpleCurrency(locale: 'en', name: currency).format(amount);

/// The AI wallet: what it holds, how to add to it, and what happened to it.
///
/// ## The order is the argument
///
/// 1. **The balance**, because it is the question the screen is opened for.
/// 2. **Top up**, only where it can actually be done: the member may spend
///    the workspace's money and this device has Google Play. Each offer says
///    in three numbers what reaches the wallet, the fee on top, and the
///    total - the same three lines the web shows - and Google's own price in
///    the buyer's currency beside them, because that is the figure the
///    purchase sheet will show next.
/// 3. **Purchases**, then the **statement** - the history, from the same
///    server the web reads, so the two can never disagree.
///
/// Nothing on this screen points to another way of paying. Google Play's
/// policy forbids leading a buyer away from its billing inside the app.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final AsyncValue<WalletSummary> summary = ref.watch(walletSummaryProvider);
    final AsyncValue<TopUpShelf> shelf = ref.watch(topUpShelfProvider);
    final AsyncValue<List<WalletPayment>> payments = ref.watch(
      walletPaymentsProvider,
    );
    final AsyncValue<WalletStatementPage> statement = ref.watch(
      walletStatementProvider,
    );
    final TopUpState topUp = ref.watch(topUpControllerProvider);
    final String locale =
        Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';

    Future<void> refresh() async {
      ref
        ..invalidate(walletSummaryProvider)
        ..invalidate(walletPaymentsProvider)
        ..invalidate(walletStatementProvider)
        ..invalidate(topUpShelfProvider);
      await ref.read(walletSummaryProvider.future);
    }

    return AppScaffold(
      toolbar: AppToolbar(title: strings.walletTitle, showBack: true),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            TajeerSpacing.md,
            TajeerSpacing.sm,
            TajeerSpacing.md,
            TajeerSpacing.xl2,
          ),
          children: <Widget>[
            switch (summary) {
              AsyncValue<WalletSummary>(:final WalletSummary value?) =>
                _BalanceCard(summary: value, strings: strings),
              AsyncValue<WalletSummary>(hasError: true) => AppErrorState(
                message: strings.walletLoadFailed,
                onRetry: () => ref.invalidate(walletSummaryProvider),
              ),
              _ => const AppLoadingState(),
            },
            if (topUp.outcome case final TopUpOutcome outcome?)
              if (_outcomeBanner(outcome, strings) case final Widget banner)
                Padding(
                  padding: const EdgeInsets.only(top: TajeerSpacing.md),
                  child: banner,
                ),
            if (shelf.value case final TopUpShelf value?
                when value.isOpen) ...<Widget>[
              const SizedBox(height: TajeerSpacing.lg),
              _TopUpSection(
                shelf: value,
                buyingPackageId: topUp.buyingPackageId,
                strings: strings,
                onBuy: (TopUpOffer offer) =>
                    ref.read(topUpControllerProvider.notifier).buy(offer),
              ),
            ],
            const SizedBox(height: TajeerSpacing.lg),
            AppListSection(
              title: strings.walletPurchases,
              children: switch (payments) {
                AsyncValue<List<WalletPayment>>(
                  :final List<WalletPayment> value?,
                )
                    when value.isEmpty =>
                  <Widget>[
                    AppEmptyState(
                      title: strings.walletNoPurchases,
                      icon: LucideIcons.receipt,
                      bordered: false,
                    ),
                  ],
                AsyncValue<List<WalletPayment>>(
                  :final List<WalletPayment> value?,
                ) =>
                  <Widget>[
                    for (final WalletPayment payment in value)
                      _PaymentRow(
                        payment: payment,
                        strings: strings,
                        locale: locale,
                      ),
                  ],
                AsyncValue<List<WalletPayment>>(hasError: true) => <Widget>[
                  AppErrorState(
                    message: strings.walletLoadFailed,
                    onRetry: () => ref.invalidate(walletPaymentsProvider),
                  ),
                ],
                _ => const <Widget>[AppLoadingState()],
              },
            ),
            const SizedBox(height: TajeerSpacing.lg),
            AppListSection(
              title: strings.walletStatement,
              children: switch (statement) {
                AsyncValue<WalletStatementPage>(
                  :final WalletStatementPage value?,
                )
                    when value.entries.isEmpty =>
                  <Widget>[
                    AppEmptyState(
                      title: strings.walletNoEntries,
                      icon: LucideIcons.scrollText,
                      bordered: false,
                    ),
                  ],
                AsyncValue<WalletStatementPage>(
                  :final WalletStatementPage value?,
                ) =>
                  <Widget>[
                    for (final WalletEntry entry in value.entries)
                      _EntryRow(entry: entry, strings: strings, locale: locale),
                  ],
                AsyncValue<WalletStatementPage>(hasError: true) => <Widget>[
                  AppErrorState(
                    message: strings.walletLoadFailed,
                    onRetry: () => ref.invalidate(walletStatementProvider),
                  ),
                ],
                _ => const <Widget>[AppLoadingState()],
              },
            ),
          ],
        ),
      ),
    );
  }

  /// A cancel says nothing: the member closed the sheet on purpose.
  Widget? _outcomeBanner(TopUpOutcome outcome, AppStrings strings) =>
      switch (outcome) {
        TopUpCredited(:final WalletPayment payment) => AppStatusBanner(
          tone: AppStatusTone.success,
          icon: LucideIcons.circleCheck,
          message: strings.walletTopUpCredited(
            formatWalletMoney(
              payment.walletCredit ?? payment.total,
              payment.currency,
            ),
          ),
        ),
        TopUpPending() => AppStatusBanner(
          tone: AppStatusTone.info,
          icon: LucideIcons.clock,
          message: strings.walletTopUpPending,
        ),
        TopUpFailed() => AppStatusBanner(
          icon: LucideIcons.triangleAlert,
          message: strings.walletTopUpFailed,
        ),
        TopUpCanceled() => null,
      };
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary, required this.strings});

  final WalletSummary summary;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(strings.walletAvailable, style: context.text.labelMedium),
          const SizedBox(height: TajeerSpacing.xs),
          Text(
            formatWalletMoney(summary.available, summary.currency),
            style: context.text.headlineMedium,
          ),
          if (summary.reserved > 0) ...<Widget>[
            const SizedBox(height: TajeerSpacing.xs),
            Text(
              strings.walletReserved(
                formatWalletMoney(summary.reserved, summary.currency),
              ),
              style: context.text.bodySmall,
            ),
          ],
          if (summary.frozen) ...<Widget>[
            const SizedBox(height: TajeerSpacing.sm),
            AppStatusBanner(
              icon: LucideIcons.snowflake,
              message: strings.walletFrozen,
            ),
          ],
        ],
      ),
    );
  }
}

class _TopUpSection extends StatelessWidget {
  const _TopUpSection({
    required this.shelf,
    required this.buyingPackageId,
    required this.strings,
    required this.onBuy,
  });

  final TopUpShelf shelf;
  final String? buyingPackageId;
  final AppStrings strings;
  final void Function(TopUpOffer offer) onBuy;

  @override
  Widget build(BuildContext context) {
    return AppListSection(
      title: strings.walletTopUp,
      children: <Widget>[
        for (final TopUpOffer offer in shelf.offers)
          AppListItem(
            title: Text(
              strings.walletOfferTitle(
                formatWalletMoney(offer.credit, offer.currency),
              ),
            ),
            subtitle: Text(
              <String>[
                strings.walletOfferBreakdown(
                  formatWalletMoney(offer.fee, offer.currency),
                  formatWalletMoney(offer.total, offer.currency),
                ),
                if (shelf.storePrices[offer.storeProductId]
                    case final String price?)
                  strings.walletOfferStorePrice(price),
              ].join('\n'),
            ),
            trailing: AppButton(
              label: strings.walletBuy,
              size: AppButtonSize.small,
              loading: buyingPackageId == offer.packageId,
              onPressed: buyingPackageId == null ? () => onBuy(offer) : null,
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(TajeerSpacing.sm),
          child: Text(strings.walletFeeOnTop, style: context.text.bodySmall),
        ),
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.payment,
    required this.strings,
    required this.locale,
  });

  final WalletPayment payment;
  final AppStrings strings;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return AppListItem(
      title: Text(
        formatWalletMoney(
          payment.walletCredit ?? payment.total,
          payment.currency,
        ),
      ),
      subtitle: Text(
        <String>[
          payment.gatewayName,
          if (payment.fee case final double fee when fee > 0)
            strings.walletPaymentFee(formatWalletMoney(fee, payment.currency)),
        ].join(' · '),
      ),
      meta: Text(
        AppRelativeTime.forRow(
          payment.createdAt,
          locale: locale,
          messages: context.strings,
        ),
      ),
      trailing: AppBadge(
        label: strings.walletPaymentState(payment.state),
        variant: switch (payment.state) {
          'paid' => AppBadgeVariant.success,
          'failed' || 'cancelled' => AppBadgeVariant.destructive,
          _ => AppBadgeVariant.muted,
        },
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.strings,
    required this.locale,
  });

  final WalletEntry entry;
  final AppStrings strings;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final String amount = formatWalletMoney(entry.amount, entry.currency);

    return AppListItem(
      title: Text(entry.description ?? strings.walletEntryType(entry.type)),
      subtitle: Text(
        strings.walletBalanceAfter(
          formatWalletMoney(entry.balanceAfter, entry.currency),
        ),
      ),
      meta: Text(
        AppRelativeTime.forRow(
          entry.createdAt,
          locale: locale,
          messages: context.strings,
        ),
      ),
      trailing: Text(
        entry.isCredit ? '+$amount' : '−$amount',
        style: context.text.labelLarge,
      ),
    );
  }
}
