/// `F-135` — **what happened, how, and where**, written into every export row.
///
/// ## What was asked for
///
/// > *"the export file which henceforth gets generated, has a detailed log of
/// > what, how and where went down once it detected a qr a pos tap or a payment
/// > hyperlink redirection"*
///
/// The export used to be a dump of database columns. That is fine for restoring
/// onto a new phone and useless for the thing an export is actually opened for:
/// working out, months later, **why a particular row says what it says.**
///
/// So each capture now carries a `provenance` block alongside its raw columns.
/// It is derived, never stored — every field is recomputed from the payload at
/// export time, so it cannot drift out of step with the row it describes and
/// costs nothing in the database.
///
/// ## Two audiences, one block
///
/// `story` is a sentence a person can read. Everything else is structured, for
/// a spreadsheet or a script. Writing only the sentence would make the file
/// unusable for analysis; writing only the fields would make it unreadable by
/// the person it belongs to.
///
/// ## The rule about `raw`
///
/// The raw payload is already in the row and stays there. It is the one field
/// that lets any claim in `provenance` be checked, which is the same reason the
/// capture sheet has "View technical details". **An export that cannot be
/// audited is just a receipt for a number somebody made up.**
library;

import '../models/capture_event.dart';
import 'mcc_route.dart';
import 'merchant_identity.dart';
import 'rupay_outlook.dart';
import 'upi_uri_parser.dart';

abstract final class ExportNarrative {
  /// Version this block's shape, so a later reader can tell whether a field's
  /// absence means "not applicable" or "written by an older build".
  static const version = 1;

  /// Build the provenance block for one exported row.
  ///
  /// [row] is the database record as `exportRows` returns it. Nothing here
  /// throws: an export that fails on one malformed row out of nine hundred is
  /// worse than an export with one thin row in it.
  static Map<String, Object?> of(Map<String, Object?> row) {
    try {
      return _build(row);
    } catch (e) {
      return {
        'narrativeVersion': version,
        'story': 'This capture could not be described.',
        'error': e.toString(),
      };
    }
  }

  static Map<String, Object?> _build(Map<String, Object?> row) {
    final raw = row['raw_payload'] as String?;
    final mcc = row['mcc'] as String?;
    final vectorName = row['vector'] as String?;
    final merchant = row['merchant_name'] as String?;
    final handle = row['merchant_handle'] as String?;
    final place = row['place_label'] as String?;
    final at = row['captured_at'];

    final upi = raw == null ? null : UpiUriParser.tryParse(raw);
    final identity = upi == null ? null : MerchantIdentifier.ofIntent(upi);

    final how = _how(vectorName);
    final publication = upi?.mccPublication;

    final verdict = identity == null
        ? null
        : RupayVerdict.of(identity: identity, intent: upi);

    final absence = (identity == null || mcc != null)
        ? null
        : MccAbsence.of(identity: identity, intent: upi);

    return {
      'narrativeVersion': version,

      // ── WHAT ──
      'what': mcc == null
          ? 'No category was published'
          : 'Category $mcc',
      'categoryFound': mcc != null,
      'categorySource': _categorySource(publication, mcc, vectorName),
      if (publication != null) 'mcField': publication.name,

      // ── HOW ──
      'how': how,
      'howDetail': _howDetail(vectorName, upi),
      if (upi?.acquirerHint != null) 'terminalVendor': upi!.acquirerHint,
      if (upi?.mode != null) 'upiMode': upi!.mode,
      if (upi?.isDynamic ?? false) 'dynamicQr': true,

      // ── WHERE ──
      'where': place ?? 'Not recorded',
      'wherePrecision': place == null
          ? 'Location was off for this capture'
          : 'Approximate area, about 1 km, computed on the device',

      // ── WHO ──
      'merchant': merchant ?? 'Not named in the payload',
      if (handle != null) 'payeeHandle': handle,
      if (identity?.psp != null) 'paymentCompany': identity!.psp,
      if (identity != null) 'merchantTier': identity.tier.name,
      if (identity != null) 'payeeKind': identity.kind.name,

      // ── WHAT IT MEANS FOR A CARD ──
      if (verdict != null) ...{
        'rupayOutlook': verdict.outlook.name,
        if (verdict.headline != null) 'rupayHeadline': verdict.headline,
        if (verdict.because != null) 'rupayEvidence': verdict.because,
      },

      // ── WHY IT IS MISSING, WHEN IT IS ──
      if (absence != null) ...{
        'whyNoCategory': absence.reason,
        'couldStillBeFound': absence.fixable,
        'routesToFindIt':
            absence.routes.map((r) => r.title).toList(growable: false),
      },

      // ── THE SENTENCE ──
      'story': _story(
        at: at,
        how: how,
        mcc: mcc,
        merchant: merchant ?? handle,
        place: place,
        publication: publication,
      ),
    };
  }

  static String _how(String? vector) => switch (vector) {
        'qr' => 'Read from a QR code',
        'nfc' => 'Read from a card terminal over NFC',
        'intent' => 'Handed over by a payment app at checkout',
        'statement' => 'Learned from an imported bank statement',
        'graph' => 'Filled in from another capture of the same merchant',
        'manual' => 'Entered by hand',
        'link' => 'Read from a payment link',
        'probe' => 'Read by a probe',
        _ => 'Unknown route',
      };

  static String _howDetail(String? vector, UpiIntent? upi) =>
      switch (vector) {
        'qr' => upi == null
            ? 'EMVCo merchant-presented QR, category at tag 52'
            : 'UPI intent QR, category in the mc parameter',
        'nfc' => 'EMV contactless, category in tag 9F15. SWIP declines the '
            'transaction with SW=6985 - no payment is made',
        'intent' => 'Android intent from the paying app, category in mc',
        'statement' => 'Parsed from the transaction narration',
        'graph' => 'Same merchant key as an earlier capture that had a '
            'category',
        _ => 'No further detail',
      };

  static String _categorySource(
      MccPublication? pub, String? mcc, String? vector) {
    if (mcc == null) {
      return switch (pub) {
        MccPublication.blank =>
          'The mc field was present in the payload but empty - the acquirer '
              'did not fill it in',
        MccPublication.malformed =>
          'The mc field was present but not four digits, so it was refused',
        MccPublication.absent || null =>
          'The payload carried no category field at all',
        _ => 'No category',
      };
    }
    if (pub == MccPublication.unclassified) {
      return 'Published as 0000, which is the code for unclassified';
    }
    return switch (vector) {
      'qr' => 'Published in the QR code itself',
      'nfc' => 'Returned by the terminal in EMV tag 9F15',
      'intent' => 'Included in the checkout hand-off',
      'statement' => 'Printed on the bank statement line',
      'graph' => 'Inherited from another capture of the same merchant',
      _ => 'Recorded',
    };
  }

  static String _story({
    required Object? at,
    required String how,
    required String? mcc,
    required String? merchant,
    required String? place,
    required MccPublication? publication,
  }) {
    final who = merchant ?? 'an unnamed merchant';
    final wherePart = place == null ? '' : ' in $place';
    final when = at == null ? '' : ' on $at';

    if (mcc != null) {
      return '${how.replaceFirst('Read', 'SWIP read')}$when: $who$wherePart '
          'is filed under category $mcc.';
    }

    final why = switch (publication) {
      MccPublication.blank =>
        'their bank left the category field empty',
      MccPublication.malformed =>
        'the category field was not four digits',
      _ => 'no category was in the payload',
    };
    return '${how.replaceFirst('Read', 'SWIP read')}$when: $who$wherePart, '
        'but $why.';
  }
}
