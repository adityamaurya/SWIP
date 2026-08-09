#!/usr/bin/env node
/**
 * Builds the world QR test corpus.
 *
 * WHY THIS IS GENERATED RATHER THAN SCRAPED
 * -----------------------------------------
 * The obvious approach is to collect real merchant QRs off the internet. Two
 * problems with that:
 *
 *  1. A real merchant QR is a payment instrument. Publishing someone's VPA or
 *     acquirer merchant ID in a public test fixture is not ours to do.
 *  2. Payloads copied out of blog posts and search results are routinely
 *     whitespace-stripped or truncated in transit, which silently breaks the
 *     CRC. A corpus of subtly corrupt vectors is worse than no corpus — the
 *     parser would be tuned against payloads that no terminal ever emits.
 *
 * So each vector here is built from the EMVCo Merchant-Presented Mode
 * structure documented for that scheme, with a CRC computed the same way a
 * real issuer computes it. They are known-correct by construction.
 *
 * WHAT THIS DOES NOT PROVE
 * ------------------------
 * That real acquirers in each country populate tag 52 the way the spec says.
 * That is a field-test question, exactly like the 9F15 question for terminals
 * (docs/03-RESEARCH-MCC-CAPTURE.md §3.4). This corpus proves SWIP parses
 * correctly-formed payloads from every scheme; it does not prove every
 * merchant emits one.
 *
 * Run:  node tool/build_qr_corpus.mjs
 * Out:  test/fixtures/qr_corpus.json
 */

import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// ── EMVCo primitives ──────────────────────────────────────────────────

/**
 * One TLV: 2-digit tag, 2-digit length, value.
 *
 * **Length is in BYTES, not characters.** This is the single most important
 * line in the file. `ラーメン一番` is 6 JavaScript characters but 18 UTF-8
 * bytes; declaring `06` produces a payload no conformant parser can read,
 * because every tag after it starts at the wrong offset — including tag 52.
 *
 * The first version of this generator used `v.length` and the Japanese vector
 * failed in CI exactly as designed, just with the bug on the fixture's side
 * rather than the parser's.
 */
function tlv(tag, value) {
  const v = String(value);
  const bytes = Buffer.byteLength(v, 'utf8');
  if (bytes > 99) throw new Error(`value too long for tag ${tag}: ${bytes}B`);
  return `${tag}${String(bytes).padStart(2, '0')}${v}`;
}

/**
 * CRC-16/CCITT-FALSE: poly 0x1021, init 0xFFFF, no reflection, no final xor.
 * Computed over the whole payload INCLUDING "6304", then appended as 4 upper
 * hex digits. Getting the "including 6304" part wrong is the classic bug.
 */
function crc16(s) {
  let crc = 0xffff;
  for (const byte of Buffer.from(s, 'utf8')) {
    crc ^= byte << 8;
    for (let i = 0; i < 8; i++) {
      crc = crc & 0x8000 ? ((crc << 1) ^ 0x1021) & 0xffff : (crc << 1) & 0xffff;
    }
  }
  return crc.toString(16).toUpperCase().padStart(4, '0');
}

function seal(body) {
  const withTag = `${body}6304`;
  return `${withTag}${crc16(withTag)}`;
}

// ── the corpus ────────────────────────────────────────────────────────
//
// Every entry states what it is testing and what SWIP must return. `expectMcc`
// null means "SWIP must report no category" — an honest unknown is a PASS, and
// inventing four digits would be a failure.

const vectors = [];

function add(v) {
  vectors.push(v);
}

// ── India ──
add({
  id: 'in-upi-intent',
  country: 'IN',
  scheme: 'UPI intent',
  note: 'The everyday Indian case. Category rides in the `mc` parameter.',
  payload:
    'upi://pay?pa=bluetokai@hdfcbank&pn=Blue%20Tokai%20Coffee&mc=5812&tid=TXN99&am=340.00&cu=INR',
  expectMcc: '5812',
  expectMerchant: 'Blue Tokai Coffee',
});

add({
  id: 'in-upi-malformed-ampersand',
  country: 'IN',
  scheme: 'UPI intent',
  note:
    'Real merchant QRs routinely carry an unencoded & inside the payee name. '
    + 'A naive Uri.parse loses every parameter after it, including mc.',
  payload: 'upi://pay?pa=shop@ybl&pn=Ram & Sons Traders&mc=5411&cu=INR',
  expectMcc: '5411',
});

add({
  id: 'in-upi-no-mcc',
  country: 'IN',
  scheme: 'UPI intent',
  note:
    'Person-to-person handle. No mc at all. SWIP must say so, not guess — '
    + 'this is the single most common QR in India.',
  payload: 'upi://pay?pa=9820012345@ybl&pn=Aditya&cu=INR',
  expectMcc: null,
});

add({
  id: 'in-bharatqr',
  country: 'IN',
  scheme: 'BharatQR (EMVCo MPM)',
  note: 'Static merchant QR, NPCI account template in tag 26.',
  payload: seal(
    tlv('00', '01') +
      tlv('01', '11') +
      tlv('26', tlv('00', 'A000000677010111') + tlv('01', '9876543210123')) +
      tlv('52', '5812') +
      tlv('53', '356') +
      tlv('58', 'IN') +
      tlv('59', 'BLUE TOKAI COFFEE') +
      tlv('60', 'MUMBAI'),
  ),
  expectMcc: '5812',
  expectCountry: 'IN',
});

// ── Brazil ──
add({
  id: 'br-pix-static',
  country: 'BR',
  scheme: 'PIX',
  note: 'Brazil. Merchant account template 26 carries the PIX key (BR.GOV.BCB.PIX).',
  payload: seal(
    tlv('00', '01') +
      tlv('01', '11') +
      tlv('26',
        tlv('00', 'BR.GOV.BCB.PIX') + tlv('01', 'cafe@padaria.com.br')) +
      tlv('52', '5812') +
      tlv('53', '986') +
      tlv('58', 'BR') +
      tlv('59', 'PADARIA CENTRAL') +
      tlv('60', 'SAO PAULO'),
  ),
  expectMcc: '5812',
  expectCountry: 'BR',
  expectCurrency: 'BRL',
});

// ── Thailand ──
add({
  id: 'th-promptpay',
  country: 'TH',
  scheme: 'PromptPay',
  note: 'Thailand. Tag 29/30 rather than 26. Currency 764 = THB.',
  payload: seal(
    tlv('00', '01') +
      tlv('01', '12') +
      tlv('30',
        tlv('00', 'A000000677010112') + tlv('01', '0105536000021')) +
      tlv('52', '5814') +
      tlv('53', '764') +
      tlv('54', '120.00') +
      tlv('58', 'TH') +
      tlv('59', 'COFFEE WORLD') +
      tlv('60', 'BANGKOK'),
  ),
  expectMcc: '5814',
  expectCountry: 'TH',
  expectCurrency: 'THB',
});

// ── Indonesia ──
add({
  id: 'id-qris',
  country: 'ID',
  scheme: 'QRIS',
  note: 'Indonesia. Currency 360 = IDR.',
  payload: seal(
    tlv('00', '01') +
      tlv('01', '11') +
      tlv('26', tlv('00', 'ID.CO.QRIS.WWW') + tlv('01', '936000091100000001')) +
      tlv('52', '5411') +
      tlv('53', '360') +
      tlv('58', 'ID') +
      tlv('59', 'TOKO SEMBAKO') +
      tlv('60', 'JAKARTA'),
  ),
  expectMcc: '5411',
  expectCountry: 'ID',
  expectCurrency: 'IDR',
});

// ── Singapore ──
add({
  id: 'sg-paynow',
  country: 'SG',
  scheme: 'PayNow',
  note: 'Singapore. Currency 702 = SGD.',
  payload: seal(
    tlv('00', '01') +
      tlv('01', '11') +
      tlv('26', tlv('00', 'SG.PAYNOW') + tlv('01', '2') + tlv('02', '201234567A')) +
      tlv('52', '5812') +
      tlv('53', '702') +
      tlv('58', 'SG') +
      tlv('59', 'HAWKER STALL 42') +
      tlv('60', 'SINGAPORE'),
  ),
  expectMcc: '5812',
  expectCountry: 'SG',
  expectCurrency: 'SGD',
});

// ── Malaysia ──
add({
  id: 'my-duitnow',
  country: 'MY',
  scheme: 'DuitNow',
  payload: seal(
    tlv('00', '01') +
      tlv('01', '11') +
      tlv('26', tlv('00', 'A000000677010111') + tlv('01', '60123456789')) +
      tlv('52', '5814') +
      tlv('53', '458') +
      tlv('58', 'MY') +
      tlv('59', 'NASI LEMAK CORNER') +
      tlv('60', 'KUALA LUMPUR'),
  ),
  expectMcc: '5814',
  expectCountry: 'MY',
  expectCurrency: 'MYR',
});

// ── Vietnam ──
add({
  id: 'vn-vietqr',
  country: 'VN',
  scheme: 'VietQR',
  payload: seal(
    tlv('00', '01') +
      tlv('01', '11') +
      tlv('38', tlv('00', 'A000000727') + tlv('01', tlv('00', '970415') + tlv('01', '113366668888'))) +
      tlv('52', '5999') +
      tlv('53', '704') +
      tlv('58', 'VN') +
      tlv('59', 'CUA HANG TIEN LOI') +
      tlv('60', 'HA NOI'),
  ),
  expectMcc: '5999',
  expectCountry: 'VN',
  expectCurrency: 'VND',
});

// ── Japan ──
add({
  id: 'jp-jpqr',
  country: 'JP',
  scheme: 'JPQR',
  note:
    'Non-ASCII merchant name in tag 59. This is the vector that breaks '
    + 'string-index TLV walkers: multi-byte characters make every subsequent '
    + 'tag offset wrong, including tag 52.',
  payload: seal(
    tlv('00', '01') +
      tlv('01', '11') +
      tlv('26', tlv('00', 'JP.OR.PAYMENTS') + tlv('01', '0000000000001')) +
      tlv('52', '5812') +
      tlv('53', '392') +
      tlv('58', 'JP') +
      tlv('59', 'ラーメン一番') +
      tlv('60', 'TOKYO'),
  ),
  expectMcc: '5812',
  expectCountry: 'JP',
  expectCurrency: 'JPY',
});

// ── Europe / UK ──
add({
  id: 'gb-emvco-generic',
  country: 'GB',
  scheme: 'EMVCo generic',
  note: 'Currency 826 = GBP. Dynamic QR carrying an amount.',
  payload: seal(
    tlv('00', '01') +
      tlv('01', '12') +
      tlv('27', tlv('00', 'GB.CO.ACQUIRER') + tlv('01', 'MERCH00012345')) +
      tlv('52', '5942') +
      tlv('53', '826') +
      tlv('54', '18.99') +
      tlv('58', 'GB') +
      tlv('59', 'DAUNT BOOKS') +
      tlv('60', 'LONDON'),
  ),
  expectMcc: '5942',
  expectCountry: 'GB',
  expectCurrency: 'GBP',
});

// ── Edge cases: these are where parsers actually fail ──

add({
  id: 'edge-mcc-absent',
  country: 'XX',
  scheme: 'EMVCo, tag 52 omitted',
  note:
    'Tag 52 is optional in the spec. SWIP must report no category rather '
    + 'than defaulting to 0000 or inventing one.',
  payload: seal(
    tlv('00', '01') + tlv('01', '11') +
      tlv('26', tlv('00', 'XX.TEST') + tlv('01', '1')) +
      tlv('53', '840') + tlv('58', 'US') + tlv('59', 'NO CATEGORY SHOP'),
  ),
  expectMcc: null,
});

add({
  id: 'edge-mcc-0000',
  country: 'XX',
  scheme: 'EMVCo, tag 52 = 0000',
  note:
    'An unprovisioned terminal writes zeros. Zero is not a category — it is '
    + 'the absence of one, and must not be shown as MCC 0000.',
  payload: seal(
    tlv('00', '01') + tlv('01', '11') +
      tlv('26', tlv('00', 'XX.TEST') + tlv('01', '1')) +
      tlv('52', '0000') + tlv('53', '840') + tlv('58', 'US') +
      tlv('59', 'UNPROVISIONED'),
  ),
  expectMcc: null,
});

add({
  id: 'edge-bad-crc',
  country: 'XX',
  scheme: 'EMVCo, corrupted checksum',
  note:
    'A damaged print or a bad camera read. The payload LOOKS valid and its '
    + 'tag 52 parses to 5812 — but the CRC fails, so those four digits are '
    + 'noise that happens to be four digits long. SWIP must refuse it.',
  payload:
    seal(
      tlv('00', '01') + tlv('01', '11') +
        tlv('26', tlv('00', 'XX.TEST') + tlv('01', '1')) +
        tlv('52', '5812') + tlv('53', '840') + tlv('58', 'US') +
        tlv('59', 'CORRUPT'),
    ).slice(0, -4) + 'DEAD',
  expectMcc: null,
  expectRejected: true,
});

add({
  id: 'edge-tag-order-unusual',
  country: 'XX',
  scheme: 'EMVCo, tags out of numeric order',
  note:
    'The spec does not guarantee ascending tag order. A parser that assumes '
    + 'it will miss tag 52 entirely.',
  payload: seal(
    tlv('00', '01') + tlv('59', 'REVERSED ORDER') + tlv('58', 'US') +
      tlv('53', '840') + tlv('52', '7011') + tlv('01', '11') +
      tlv('26', tlv('00', 'XX.TEST') + tlv('01', '1')),
  ),
  expectMcc: '7011',
});

add({
  id: 'edge-not-a-payment-qr',
  country: 'XX',
  scheme: 'Plain URL',
  note: 'Someone points SWIP at a poster. It must not crash or fabricate.',
  payload: 'https://example.com/menu',
  expectMcc: null,
});

add({
  id: 'edge-payment-link-razorpay',
  country: 'IN',
  scheme: 'Payment link',
  note:
    'An MCC is assigned by the acquirer and is not encoded in a URL. SWIP '
    + 'must identify the PSP and merchant for the graph, and return no '
    + 'category rather than inferring one.',
  payload: 'https://rzp.io/l/rentpay-aug',
  expectMcc: null,
  expectAcquirer: 'Razorpay',
});

// ── self-check ────────────────────────────────────────────────────────
//
// Byte-walk every EMVCo payload exactly the way the Dart parser does, and
// assert it yields what the vector claims. A fixture is only useful if it is
// correct; an incorrect one tunes the parser against payloads no terminal
// emits. This catches that at generation time rather than in CI.

function byteWalk(payload) {
  const buf = Buffer.from(payload, 'utf8');
  const fields = {};
  let i = 0;
  while (i + 4 <= buf.length) {
    const tag = buf.subarray(i, i + 2).toString('ascii');
    const lenStr = buf.subarray(i + 2, i + 4).toString('ascii');
    if (!/^\d{2}$/.test(tag) || !/^\d{2}$/.test(lenStr)) {
      throw new Error(`malformed TLV header at byte ${i}: "${tag}${lenStr}"`);
    }
    const len = parseInt(lenStr, 10);
    const start = i + 4;
    const end = start + len;
    if (end > buf.length) {
      throw new Error(`tag ${tag} length ${len} overruns payload at byte ${i}`);
    }
    fields[tag] = buf.subarray(start, end).toString('utf8');
    i = end;
    if (tag === '63') break; // CRC is always last
  }
  return fields;
}

let checked = 0;
for (const v of vectors) {
  if (!v.payload.startsWith('0002')) continue; // UPI / URLs are not TLV
  const fields = byteWalk(v.payload);

  // CRC must validate over everything up to and including "6304".
  if (!v.id.includes('bad-crc')) {
    const body = v.payload.slice(0, v.payload.length - 4);
    const expected = crc16(body);
    const actual = v.payload.slice(-4);
    if (expected !== actual) {
      throw new Error(`${v.id}: CRC mismatch — computed ${expected}, payload has ${actual}`);
    }
  }

  const got = fields['52'] ?? null;
  const want = v.expectMcc;
  const normalised = got === '0000' ? null : got;
  if (!v.id.includes('bad-crc') && normalised !== want) {
    throw new Error(
      `${v.id}: byte-walk found MCC ${got ?? 'none'}, vector expects ${want ?? 'none'}`,
    );
  }
  checked++;
}

// ── emit ──────────────────────────────────────────────────────────────

const out = {
  generatedBy: 'tool/build_qr_corpus.mjs',
  note:
    'Constructed from EMVCo Merchant-Presented Mode structure with real '
    + 'CRC-16/CCITT-FALSE checksums. Not scraped from live merchants — see '
    + 'the header of the generator for why.',
  count: vectors.length,
  vectors,
};

const dest = join(__dirname, '..', 'test', 'fixtures', 'qr_corpus.json');
mkdirSync(dirname(dest), { recursive: true });
writeFileSync(dest, JSON.stringify(out, null, 2) + '\n');

console.log(`✓ ${vectors.length} vectors → test/fixtures/qr_corpus.json`);
console.log(`✓ ${checked} EMVCo payloads byte-walked and CRC-verified`);
for (const v of vectors) {
  console.log(
    `  ${v.id.padEnd(30)} ${String(v.expectMcc ?? '—').padEnd(6)} ${v.scheme}`,
  );
}
