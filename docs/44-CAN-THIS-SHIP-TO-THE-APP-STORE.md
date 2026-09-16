# 44 — Can SWIP ship to the App Store?

> *"if I had to get this whole app launched on the iOS App Store, will this be
> possible, or would there be constraints? Is this app foolproof, one-shot
> deployable on the App Store, or are there some roadblocks? In the very
> initial pitch of this application building, I had mentioned to you that we
> need to be flexible for any app store."* — prompt 49

[`31-IOS-AND-IPA.md`](31-IOS-AND-IPA.md) is the long version — the build
pipeline, the code changes, the bill. **This page is the verdict**, because you
asked twice and that usually means the answer is buried.

---

## 1. The one-line answer

**Yes, it can ship — and about half of it will not work, permanently, for
reasons Apple controls and nobody can engineer around.**

Not "one-shot deployable". Not blocked either. It is a real iOS app with two
holes in it, and both holes are in the parts you care most about.

---

## 2. What survives, what dies

| | iOS | Why |
|---|---|---|
| **Scan a QR** | ✅ Works fully | Camera access is ordinary. This is the whole capture path for ~1 in 10 shops that publish a category |
| The ledger, the exports, the encrypted backup, the recovery phrase | ✅ Works fully | All local, all Dart, nothing platform-specific |
| Merchant-name lookup | ✅ Works fully | One HTTPS call |
| Themes, onboarding, the paywall | ✅ Works | Apple's in-app purchase instead of Google's |
| **Tap a card machine** | ❌ **Impossible** | §3 |
| **The floating bubble** | ❌ **Impossible** | §4 |
| Quick Settings tile, boot restart | ❌ No equivalent | iOS has no such surfaces |

**Two of SWIP's three ways in are Android-only.** On iOS it becomes a QR
scanner with a good ledger.

---

## 3. Tap POS — not a gap we can close

This is the one worth understanding properly, because it changed recently and
the change does not help India.

Apple did open up NFC for third parties — but with three locks on it:

1. **An Apple agreement plus an "NFC & SE Platform entitlement"**, applied for
   and granted case by case.
2. **The developer must be licensed to provide payment services in the EEA**,
   or working with a licensed entity that is.
3. **It works for users located in the European Economic Area.** It arrived in
   iOS 17.4 for the EEA; iOS 18 and 18.1 widened the *use cases* (access
   control and similar) and some regions, but the payments surface remains EEA-
   anchored.

**India is not in the EEA.** And SWIP is not a licensed payment services
provider — it deliberately does not touch money at all.

So on iOS there is no route to reading a terminal. It is not a harder version
of the Android work; it is a door with no handle on our side.

* [Apple — HCE-based contactless NFC transactions for apps in the EEA](https://developer.apple.com/support/hce-transactions-in-apps)
* [Apple Developer Forums — no default contactless option outside the EEA](https://developer.apple.com/forums/thread/750252)
* [Apple Developer Forums — implementing HCE outside the EEA](https://developer.apple.com/forums/thread/760774)

---

## 4. The floating bubble — not a permission, an absence

iOS has **no overlay API at all.** There is no `SYSTEM_ALERT_WINDOW`
equivalent, no entitlement to request, no review process to pass. An app cannot
draw over another app, full stop.

The nearest things are Widgets (on the home screen, not over apps), Live
Activities (on the lock screen and Dynamic Island, and they cannot open a
camera) and Picture-in-Picture (video only, and abusing it for UI is a
rejection under Guideline 2.5.1).

There is no version of "always there, never in the way" on iOS.

---

## 5. The App Store review risks, in order of how likely they are to bite

### A. "Your app has limited functionality" — Guideline 4.2

The real risk. An iOS SWIP is a QR scanner that reports a category roughly one
time in ten and explains itself the other nine. A reviewer who scans two
stickers and sees "no category published" twice can read that as an app that
does not work.

**Manageable, and it is a writing job rather than an engineering one.** The
demo notes have to say what the app is claiming and the screens have to be
honest without looking broken — which `F-183`'s scanner guidance and the
capture sheet's copy already do.

### B. The ₹5,000 unlock must use Apple's in-app purchase — Guideline 3.1.1

Non-negotiable, and fine. `in_app_purchase` already abstracts both stores, and
it is a one-time managed product on both. **Apple takes 15–30%.**

### C. Donations — Guideline 3.2.1

Collecting donations **outside** in-app purchase is allowed only for registered
non-profits. SWIP is not one. So on iOS, donations either go through Apple's
in-app purchase — with Apple's cut, on a donation — or the donation surface is
removed from the iOS build.

**Worth deciding before submission rather than during review.** This is the
kind of thing that turns a one-week review into a month.

### D. Asking users for a Razorpay key — Guideline 5.1.1 / 4.7

A screen that asks for API credentials will get looked at. The defence is
already in the app and it is a good one: it is off by default, it is explained
before it is asked for, it recommends a test key that cannot move money, and
removing it is one tap. But expect a question.

### E. NFC entitlement on an app that does not do NFC

If the iOS build ships without the NFC code at all, this never comes up. **Do
not** ship a dormant Tap POS screen — an entitlement or capability the app does
not use is a rejection risk and there is nothing to gain.

---

## 6. So what should actually happen

**Android first, and not because iOS is hard — because iOS cannot carry the
product.**

Two of the three capture vectors, the omnipresence, the whole "check before you
pay without leaving the checkout" idea — all Android. An iOS build is a
worthwhile *companion*, and it is a bad *launch*.

The honest sequence:

1. Ship Android. It is the complete product.
2. If iOS happens, ship it as **"SWIP for iPhone — scan a code"**, with the
   feature table above in the listing rather than hidden. Under-promising is
   also how you survive Guideline 4.2.
3. Revisit if Apple's EEA arrangement ever extends to India — worth checking
   once a year, and worth nothing before then.

The pitch said *"flexible for any app store"*, and the code honours it: the
architecture is Flutter with a thin Android layer, so nothing has to be rewritten
to add iOS. **What cannot be flexible is a platform's refusal**, and that is
where two of these sit.

---

## 7. What it would cost

[`31` §5](31-IOS-AND-IPA.md) has the detail. Short version: an Apple Developer
Program membership (US$99/year), a Mac or a hosted Mac runner for CI, and the
engineering to strip and replace the two Android-only paths.

Nothing here is expensive. The expensive part is that you would be shipping a
smaller product to a smaller answer.
