# 37 — Omnipresence, and the two things I handed back to you

> *"find a way to do the last two things you are asking for me first of all,
> i am not super technical about the app development, i am product designer by
> profession so, find the possible way to make it happen step by step plan it
> first and then research deepdive the solution and then make the solution"*
>
> *"also the shortcut is still not working… I want it to be present,
> omnipresent, throughout the background, no matter what, everywhere."*

Fair on both counts. This file is the plan, the research it rests on, and what
was built from it.

**The short version of the uncomfortable part:** neither of the two things I
called your decision actually was one. Both were mine, and I handed them over
because I had reasoned about them instead of checking. That is the third time
this has happened in this project and it is now the first line of
[`CLAUDE.md`](../CLAUDE.md)'s "recurring mistakes".

---

## 1. Why the floater still did not work, and it was not the permission

This is the important section, because the bug was real and it was in code I
wrote last round.

`F-158` told the service about SWIP's foreground state by **sending a
broadcast**. `signal()` dropped that broadcast if the service was not yet
`running`. And starting an Android service is asynchronous —
`startForegroundService()` returns long before `onStartCommand()` runs.

So the completely ordinary first-use sequence was:

| | What you do | What happens |
|---|---|---|
| 1 | Flip the switch | SWIP asks Android to start the service |
| 2 | Press Home | SWIP fires "I'm in the background now" |
| 3 | — | The service finally starts, a moment later |

Step 2's message arrived while there was nothing listening. It was thrown
away. The service came up believing SWIP was still on screen — and **the
bubble hides itself while SWIP is on screen**, on purpose, because a button
floating over the app it belongs to is a smudge.

Nothing ever re-sent that message. So the bubble stayed hidden until you
happened to open SWIP and leave it again. Which, from outside, is exactly "the
floater is not working".

### The fix, in one sentence

**An event you can miss is the wrong shape for a fact that is either true or
false right now.**

Foreground state and the payment-quiet deadline are no longer messages. They
are values that `MainActivity` writes and the service **reads, every single
time it decides whether to be visible**. A lost broadcast now costs a moment of
staleness instead of a permanently wrong answer.

Two smaller things fell out of that:

* **The default flipped to "SWIP is in the background".** It used to be "in the
  foreground", on the reasoning that only a foregrounded Activity can start the
  service. True — but not the only way it starts. A restart after the system
  kills it, and now a reboot, both start it with no Activity anywhere, so
  nobody would ever correct that guess and the bubble would hide forever.
* **Screen-off is now read from the system** rather than assumed, so a service
  that starts while your phone is in your pocket does not put a bubble on a
  screen nobody is looking at.

---

## 2. Omnipresent — what that can actually mean on Android

You asked for it to be there "no matter what, everywhere". Here is what is
achievable, what is not, and why.

| | Achievable? | How |
|---|---|---|
| Over every other app | **Yes** | `SYSTEM_ALERT_WINDOW` + a foreground service. Already the design |
| Surviving you leaving SWIP | **Yes** | Fixed above — this was the bug |
| Surviving a phone restart | **Yes, now** | `SwipBootReceiver` |
| Surviving an app update | **Yes, now** | Same receiver, `MY_PACKAGE_REPLACED` |
| Surviving aggressive battery saving | **Partly** | The foreground service is Doze-exempt while it runs. OEM killers are beyond that — see below |
| Surviving a **Force stop** | **No. Nothing can.** | See below |

### Reboot: allowed, and I checked rather than assumed

Android 15 forbids a `BOOT_COMPLETED` receiver from starting a foreground
service of these types:

> `dataSync`, `camera`, `mediaPlayback`, `phoneCall`, `mediaProjection`,
> `microphone`

SWIP's bubble is **`specialUse`**, which is not on that list.
([behaviour changes, Android 15](https://developer.android.com/about/versions/15/behavior-changes-15))

### Battery: the thing I deliberately did **not** build

The obvious move is to ask Android to exempt SWIP from battery optimisation.
I did not, and this is the reason:

> *"Google Play policies prohibit apps from requesting direct exemption from
> Power Management features—Doze and App Standby—in Android 6.0 and above
> unless the core function of the app is adversely affected."*

The acceptable-use list is messaging and calling apps that cannot use push,
enterprise VOIP, safety apps, task automation, and peripheral companions
holding a live connection.
([Doze and App Standby](https://developer.android.com/training/monitoring-device-state/doze-standby))

**A floating shortcut button is none of those.** Asking anyway would be a
policy violation on an app that has not shipped yet, which is a bad trade for a
feature that mostly works without it. So the wizard walks you to SWIP's own
settings page and tells you which switches to flip by hand — allowed, honest,
and on Xiaomi/Oppo/Vivo/realme it is the switch that actually matters anyway.

### Force stop: the one thing that genuinely cannot be worked around

If SWIP is force-stopped from Android's settings, Android puts it in a
"stopped" state and delivers it **nothing** — not even the signal that your
phone restarted — until you open the app once by hand.

There is no permission, flag or trick that changes this on a stock phone. Any
app that claims otherwise is mistaken. It is the red-crossed row on the
wizard's fourth screen for exactly that reason.

---

## 3. "Is there a clash where two shortcuts cannot run?"

You asked this directly. The answer has two halves, and the second is the one
that matters.

**Floating buttons do not clash.** Several apps may hold `SYSTEM_ALERT_WINDOW`
at once, and Android simply stacks them by Z-order — the newest sits on top.
Nothing disables anything. If SWIP's button is hidden behind another app's,
drag it somewhere else.

**The thing that really is one-at-a-time is the accessibility shortcut** —
holding both volume keys for three seconds. Assign more than one service to it
and Android shows a chooser menu instead (Samsung calls it "Direct access").
([Use accessibility shortcuts](https://support.google.com/accessibility/android/answer/7650693))

**That is precisely what page 12 of your Wispr Flow screenshots is about.** The
"Wispr Flow shortcut" toggle they tell you *not* to turn on is that chord.

**SWIP does not use it at all.** No accessibility service, so nothing can take
SWIP's place there and SWIP can never take anyone else's.

### Which is also why SWIP does not copy Wispr Flow's flow exactly

Wispr Flow needs an Accessibility Service because it reads the focused text
field in whatever app you are in and types into it. That is impossible without
one.

SWIP draws a circle and opens its own camera. `SYSTEM_ALERT_WINDOW` plus a
foreground service covers every capability it needs.

Adding an accessibility service would buy SWIP exactly one thing — knowing
which app is in front, so it could hide over payment apps precisely rather than
by the 90-second rule. And it would cost the single strongest privacy claim the
product has: *SWIP has no mechanism to see another app's screen.* Not a
promise — an absence. **If you want that trade, say so and I will build it.**
I am not taking it on my own.

---

## 4. Blocker one: the merchant-name lookup

**What I said:** it needs the HTTP client `docs/30` §1 forbids, and three
constants I could not verify. Your call.

**What was true:** the check exists to catch a network client arriving *by
accident*. A single deliberate one, in a named file, behind a switch that is
off by default, is not what it was written to stop. The check now has exactly
one exception, by exact path, and still fails the build on a client anywhere
else.

And the three constants were unverified only because razorpay.com is blocked
from the machine I work on. Going at it through search rather than the site
confirmed all three, and all three were already right:

```
POST https://api.razorpay.com/v1/payments/validate/vpa
  { "vpa": "gauravkumar@exampleupi" }
→ { "vpa": "…", "success": true, "customer_name": "Gaurav Kumar" }
```

([Validate VPA](https://razorpay.com/docs/payments/payment-methods/upi/vpa-validation/))

**One thing worth knowing that came out of checking.** NPCI deprecated the UPI
Collect flow on 28 February 2026 — nobody can pay by typing a VPA any more,
outside a short exemption list. This endpoint exists to validate an address
*before* a collect request, so its original reason to exist has largely gone.
It is still documented and still live, and SWIP's use was never a collect. But
an endpoint whose main customer has been deprecated is one that could be
retired, so a `404` or `410` is now handled like any other failure: a sentence
on screen, and the merchant graph carries on with the names it has.

### The part that is genuinely yours

**The key lives on your phone, and a Razorpay key pair is not read-only.** The
same credentials that resolve an address can create orders, list every payment
on the account and issue refunds. Razorpay has no read-only key.

The screen says that above the switch rather than below it, suggests a **test
key** (`rzp_test_…`, cannot move money) for anyone who just wants to see it
work, and has a Remove button that deletes the credentials rather than merely
switching the feature off.

The only design that removes the risk is a server holding the key and proxying
the call. That is a different product with a different privacy notice, and it
is a real decision rather than a technical blocker.

---

## 5. Blocker two: the in-overlay camera

**What I said:** CameraX and ML Kit are Gradle dependencies, and
`android/app/build.gradle` is regenerated by `flutter create` inside
`tool/bootstrap.sh` on every machine and in CI — so anything added by hand
works locally and vanishes on the next clean checkout.

**What was true:** all of that, and it was still my problem. The script that
destroys the file is the same script I maintain, and
[§4b2 of it](../app/tool/bootstrap.sh) has been re-injecting a `compileSdk`
override since the file_picker/AGP collision. The pattern was already there.

`SWIP_GRADLE_DEPS` in that script now does the same for app dependencies.
Add a line to the list, and it survives every bootstrap. Both Gradle dialects
are handled (Groovy `implementation 'x'`, Kotlin `implementation("x")`), and
both were dry-run before this was committed.

The list is **empty on purpose.** CameraX plus ML Kit is roughly 10 MB of APK,
and shipping them before the code that uses them exists would be paying for a
feature without having it. The lines go in with the commit that uses them.

### So what is left, and the honest sequencing

| Step | State |
|---|---|
| The mechanism to add Gradle dependencies | **Done**, and proven |
| Adding CameraX + ML Kit | One line each, whenever the next step starts |
| A second overlay window with a live camera and a barcode analyser | **Not built** |

I have not built the last one in the same round as a critical bug fix, and
that is a deliberate choice rather than an oversight. It is several hundred
lines of camera code that **I cannot run** — there is no device here and CI
only compiles — and this project's own
[`29-QR-DETECTION-FORENSICS`](29-QR-DETECTION-FORENSICS.md) is a record of how
subtle camera code has repeatedly turned out to be. Shipping it untested on top
of the commit that fixes the thing you reported twice is how you end up with
two broken things instead of one.

Today the bubble opens SWIP's existing scanner — the one that already handles
the `noDuplicates` trap, the aim detector, the resolver and the ledger. That is
one app switch instead of zero. Worse than the goal, much better than a toggle
that does nothing, and the blocker in front of the goal is now gone.
