# SWIP — Product Requirements Document

**Version** 1.0 · **Date** 08 Aug 2026 · **Owner** Aditya Maurya
**Status** Approved for v1 build

> This PRD is the spine. It is deliberately short, because the detail lives in the
> documents it links to. Nothing here originates with me — every requirement traces to an
> ID in the [Ideation Ledger](02-IDEATION-LEDGER.md), which is the record of what you asked
> for and the guarantee that none of it was lost.

---

## 1. What SWIP is

> **SWIP tells you the merchant category code of a purchase — before you pay for it.**

Four digits decide whether a transaction earns 10× points, 1×, or nothing. They are invisible
at the point of sale. SWIP makes them visible, anywhere in the world, in under two seconds,
with no account.

## 2. The problem `C-11`

Today, a person who cares about this has three options, and all three are bad:

1. **Guess** from a static online directory that says what a brand *usually* codes as.
2. **Transact and wait** two days for it to post, then read the statement.
3. **Disable the card, tap it deliberately to force a decline, then phone customer support
   and ask an agent what the merchant category code was.**

Option 3 is not a hypothetical — it is the documented state of the art, and it is the
sentence in your brief that defines this company. Anything that replaces a phone call to a
bank's contact centre with a two-second tap is worth building.

## 3. Who it is for

| | Primary | Secondary | Later |
|---|---|---|---|
| Who | Indian credit-card optimisers — points, miles, category bonuses | Anyone with a rewards card in an EMVCo-QR market | SMEs verifying their own MCC; issuers licensing the graph |
| Size | ~2–4 M highly engaged in India | ~100 M+ | B2B |
| Behaviour | Checks before spending, reads issuer T&Cs, active in communities | Occasional | — |
| Willing to pay | **Yes** — for Pro | Rarely | Yes |

The primary user is small, loud, technical, and unforgiving of imprecision. That shapes
everything: show your working, mark confidence, never fake a number.

## 4. Goals and non-goals

**Goals — v1**
1. Read the MCC from any merchant-presented QR, worldwide, offline. `C-02` `C-03` `C-14`
2. Read the MCC from a physical POS terminal by tapping the phone. `C-04` `C-05`
3. Infer the MCC for a payment link, with honest confidence. `C-07` `C-08`
4. Keep a simple, interlinked ledger of every capture. `D-01`–`D-10`
5. Build the merchant graph as a by-product of ordinary use.

**Non-goals — v1**
- Moving money. No wallet, no payments, no card issuing. `E-01`
- Accounts, logins, cloud sync by default. `Q-2`
- Reading SMS or bank statements automatically. See [03-RESEARCH §8](03-RESEARCH-MCC-CAPTURE.md#8-vector-5--statements-sms-and-email-and-why-swip-does-not-lead-with-it)
- Dark theme. `A-06`
- Web. `B-03`

## 5. The six capture vectors

Full technical treatment: **[03-RESEARCH-MCC-CAPTURE](03-RESEARCH-MCC-CAPTURE.md)**.

| # | Vector | Mechanism | v1 |
|---|---|---|---|
| 1 | QR | EMVCo MPM **tag 52**, or UPI intent `mc=` | ✅ |
| 2 | **NFC tap** | **EMV tag `9F15`, demanded from the terminal via the card's PDOL** | ✅ Android |
| 3 | Link | Merchant-key extraction + graph inference | ✅ heuristic |
| 4 | Probe Card | ISO 8583 **field 18** on a declined authorization | v2 |
| 5 | Statements | Manual confirmation only | ✅ manual |
| 6 | **Merchant graph** | Every capture, from every user, keyed by merchant | ✅ |

**Vector 2 is the differentiator.** A card is entitled to demand terminal data via the PDOL,
and `9F15` — Merchant Category Code — is terminal data. SWIP presents itself as a card that
asks for it, captures the answer, and then refuses to transact. No payment is created.
As far as I can find, no consumer app ships this.

**Vector 6 is the business.** It answers the case that has no live capture path — *"no QR,
I just have to hand over my card"* (`C-06`) — because somebody else already captured it.

## 6. Functional requirements

| ID | Requirement | Traces to | Priority |
|---|---|---|---|
| FR-01 | Parse EMVCo MPM TLV; extract tag 52; validate CRC-16/CCITT | `C-03` | P0 |
| FR-02 | Parse UPI intent URIs; extract `mc` | `C-03` | P0 |
| FR-03 | Handle `mc=0000` / absent tag 52 as a distinct, explained state | `C-03` | P0 |
| FR-04 | Resolve any 4-digit MCC against a bundled offline table with national / international / RuPay publications | `D-05` | P0 |
| FR-05 | HCE service presenting a PDOL requesting `9F15`, `9F16`, `9F1C`, `9F4E`, `9F1A`, `5F2A`, `9F02`, `9A`, `9F21` | `C-04` | P0 |
| FR-06 | Terminate the EMV exchange after GPO with SW `6985`; never complete a transaction | `C-13` | P0 |
| FR-07 | Persist every capture from every vector to one ledger | `D-02` | P0 |
| FR-08 | Ledger row: MCC · category · publication · merchant · time, per S-04.1 | `D-04` `D-05` | P0 |
| FR-09 | Time cell defaults to absolute stack; tap toggles to relative; global and persisted | `D-06` `D-07` | P0 |
| FR-10 | Row interlinks to capture, MCC, merchant, and card | `D-08` | P0 |
| FR-11 | Last 5 captures shown on the dashboard | `D-03` | P0 |
| FR-12 | Every MCC displayed carries a confidence level and label | — | P0 |
| FR-13 | Resolve payment links to a merchant key; infer with visible confidence and a non-dismissible disclosure | `C-07` | P1 |
| FR-14 | Store user cards locally with reward rules; surface earn rate per capture | `E-02` | P1 |
| FR-15 | Full app function offline, with no account | `Q-2` | P0 |
| FR-16 | Opt-in, merchant-keyed, coarse-geohash contribution to the graph | — | P1 |
| FR-17 | Export all data; delete all data | — | P0 |
| FR-18 | iOS: Tap replaced by an explanation, never hidden | `B-02` | P0 |

## 7. Non-functional

| | Target |
|---|---|
| Cold start → camera ready | < 1.2 s on a mid-range Android |
| QR decode → MCC on screen | < 400 ms |
| NFC tap → capture | < 800 ms from field entry |
| Offline | 100 % of v1 core |
| Install size | < 25 MB Android |
| Crash-free sessions | > 99.5 % |
| Accessibility | WCAG AA; AAA on MCC and amounts |
| Min OS | Android 8.0 (API 26) · iOS 15 |

## 8. Success metrics

| Horizon | Metric | Target |
|---|---|---|
| Activation | First capture within 5 min of install | > 60 % |
| Habit | Captures / weekly-active user / week | > 4 |
| **Vector 2** | **Terminals returning a non-zero `9F15`** | **Measure first — see the field test.** Gate at 40 % / 15 % |
| Graph | Merchants with ≥ 1 verified capture, day 90 | > 25,000 |
| Retention | D30 | > 35 % |
| Revenue (v1.5) | Pro conversion | > 3 % |

> **The `9F15` hit rate is the single most important unknown in this product.** It is not
> knowable from any specification — it depends on how acquirers provision terminals in the
> field. The [field-test protocol](03-RESEARCH-MCC-CAPTURE.md#34-what-is-verified-and-what-must-be-field-tested)
> is a week-1 task, ahead of all polish, and its result decides the marketing position.

## 9. Phasing `E-01`

| | v1 — **Know** | v1.5 | v2 — **Pay** | v3 |
|---|---|---|---|---|
| | QR · Tap · Link · Ledger · Graph | Pro, insights, dark theme | Travel Credit, Coins, Probe Card | India card programme, licensing |
| Licence | **None** | None | Travel MoR / PPI | PPI, AA |
| Revenue | ₹0 | Subscription | Float + travel + graph | Interchange |

Detail: [10-ROADMAP](10-ROADMAP.md) · economics: [04-BUSINESS-MODEL](04-BUSINESS-MODEL.md) ·
loyalty: [05-LOYALTY](05-LOYALTY-ALLIANCES.md).

## 10. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| `9F15` rarely provisioned in the field | Kills the headline feature | Field test in week 1. Vector 2 still returns `9F16`/`9F1C`/`9F1A` — the feature has a floor |
| Play Store rejects a payment-AID HCE app | No Android launch | Non-payment AID category where routing allows; explicit store-listing disclosure; no PAN, no payment capability in the binary |
| Apple never opens HCE outside the EEA | No iOS parity | Positioned and communicated from day one (`S-22`) |
| Terminal vendors block the AID | Vector 2 degrades over time | Graph is the durable asset, by design |
| Issuers change MCC exclusion lists | v2 economics move | Never build on arbitrage — [04 §5.4](04-BUSINESS-MODEL.md#54--correction-3--mcc-arbitrage-is-not-a-moat-at-any-scale) |
| RBI PPI Directions 2026 finalise unfavourably | v2 structure changes | Travel-MoR structure; lawyer sign-off before any load |
| Trademark conflict on "SWIP" | Rebrand cost | Clear classes 36 & 42 before launch spend |

## 11. Open decisions

Four, all in [02-IDEATION-LEDGER § Open questions](02-IDEATION-LEDGER.md#open-questions-back-to-you):
launch market (assumed India), accounts in v1 (assumed none), `SWIP` vs `SWIIP` (assumed
SWIP), default time format (assumed absolute).

---

## Document map

| | |
|---|---|
| [00-INDEX](00-INDEX.md) | Start here |
| [02-IDEATION-LEDGER](02-IDEATION-LEDGER.md) | **Every idea you gave, ID'd** |
| [03-RESEARCH-MCC-CAPTURE](03-RESEARCH-MCC-CAPTURE.md) | How MCC capture actually works |
| [04-BUSINESS-MODEL](04-BUSINESS-MODEL.md) | Money, float, MDR, guardrails |
| [05-LOYALTY-ALLIANCES](05-LOYALTY-ALLIANCES.md) | Coins, airlines, alliances |
| [06-DESIGN-SYSTEM](06-DESIGN-SYSTEM.md) | Tokens, logo, motion |
| [07-SCREEN-SPEC](07-SCREEN-SPEC.md) | Every screen and state |
| [08-ARCHITECTURE](08-ARCHITECTURE.md) | Code structure |
| [09-BUILD-AND-RUN](09-BUILD-AND-RUN.md) | **Zero-to-running, for a first-time mobile dev** |
| [10-ROADMAP](10-ROADMAP.md) | Sequence |
| [11-FIGMA](11-FIGMA.md) | The design file |
| [12-COMPLIANCE-RISK](12-COMPLIANCE-RISK.md) | Legal and store risk |
| [CHANGELOG](CHANGELOG.md) | Per-prompt change record |
