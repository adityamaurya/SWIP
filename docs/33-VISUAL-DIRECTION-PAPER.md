# 33 — Visual direction: Paper

> *"given are some ui inspirations for which we need to seriously consider the
> look and feel, lets pick and make it as beautiful as the above"*

Supersedes [14-VISUAL-DIRECTION-FOIL](14-VISUAL-DIRECTION-FOIL.md), which
supersedes the original light interior. Third direction, and the reasoning for
the change is below rather than assumed.

---

## 1. What the references actually have in common

Six apps were sent: **Ramp**, **CRED Circle**, **Atlys**, **Plum**, and two
health flows. They look nothing alike on the surface — Ramp is austere, Plum is
illustrated, Atlys is a black card on grey. Four things are true of all of them.

### 1.1 A paper ground, and one dark object on it

Every reference is light. And every screen has **exactly one** thing that is
near-black and heavy: Ramp's card, Atlys's worldpass, Plum's `Next` button,
Circle's `Add ₹250`. Everything else is grey, hairline, or illustration.

That is the rule SWIP was missing. The foil direction made *everything*
important-looking, so nothing was. On paper, **the MCC can be the one dark
object** and needs no colour at all to dominate — which is the argument for
monochrome stated visually rather than in a token file.

### 1.2 Type does the work that colour used to

Plum sets its headlines in a **serif** — "Thanks for putting your health
first.", "Your daily habits tell an important story" — at a size that would be a
poster. Atlys uses a dot-matrix face for the pass number, which is doing the
job a metallic gradient does elsewhere: saying *this is a document, not a label*.

SWIP already has the equivalent and under-uses it: `SwipType.mcc`, tabular,
w700. **Four digits at 56 px on white is the whole design.**

### 1.3 Generous, almost wasteful, vertical space

Count the empty rows in the Plum weight-picker or the Atlys pass. Roughly half
of each screen is nothing. SWIP's dashboard, by contrast, stacks header, camera,
dots, two tiles, a section header and five rows before the fold.

### 1.4 One accent, and it means something

Plum's crimson `Next`. Ramp's acid-yellow `+`. Circle's green online dot. Each
app allows itself **one** saturated colour, used for **one** job.

---

## 2. What SWIP takes, and what it does not

| Take | Leave |
|---|---|
| Paper ground, near-black type, hairline borders | Illustration. Plum's are beautiful and cost an illustrator; SWIP's equivalent budget goes into the numbers |
| One dark object per screen — the MCC | Gradient meshes. They date fast and they fight a live camera feed |
| A serif for the two or three lines that carry the story | Serif body copy. A ledger is read at a counter, in a hurry |
| Much more vertical space | Cards inside cards. Ramp has none |
| One accent, one job | Colour-coded categories. The whole product is about *not* guessing from colour |

### The one thing deliberately not copied

**Atlys and Circle both use a dark hero card on a light ground.** It is
gorgeous and SWIP should not do it, for a specific reason: the dashboard's hero
slot is a **live camera feed**, which is already a dark rectangle. A second dark
card next to it makes the feed look like a UI element rather than a window.

---

## 3. The system, concretely

### 3.1 Ground and ink

Already shipped in `swip_tokens.dart` (`F-130`):

| Token | Value | Use |
|---|---|---|
| `bg` | `#FFFFFF` | The ground. Pure white, so cards on it read as cards |
| `surfaceRaised` | `#F6F6F7` | Cards, rows, wells |
| `hairline` | `#E3E3E7` | Every border. **No shadows** |
| `textPrimary` | `#0B0B0D` | 18.4:1 |
| `textSecondary` | `#5B5B63` | 7.1:1 |
| `textTertiary` | `#8C8C95` | 3.2:1 — large or non-essential only |
| `gold500` | `#0B0B0D` | The accent, which is now ink. The name is kept because 95 call sites mean "the accent" by it |

### 3.2 Type — the change still to make

Add a display serif for headlines only. Three places: the capture sheet's
verdict line, the story panel's title, and the empty states. Everything else
stays Inter.

The candidate is a variable serif with a real Devanagari companion, since
merchant names arrive in Devanagari and a headline face that cannot set
"शॉप" is a face that breaks on the second real merchant.

**Not yet done.** It is a font file, a licence check and a `pubspec` entry, and
it should be one commit on its own so it can be reverted cleanly if it reads as
costume rather than voice.

### 3.3 Space

| Where | Now | Target |
|---|---|---|
| Above a section header | `xxl` (24) | `xxxl` (32) |
| Between the hero and the tiles | `section` (24) | `huge` (40) |
| Sheet top padding | `xl` (20) | `xxxl` (32) |
| Around the MCC in the sheet | `md` | `giant` (56) below it |

### 3.4 Motion

Ramp and Circle share one habit worth stealing: **nothing moves unless it is
telling you something changed.** No decorative loops. SWIP currently runs a
repeating shimmer on the camera sweep and a repeating bounce on the pull chevron
— both justified (liveness, discoverability), both worth capping so they stop
after a few cycles rather than running forever.

---

## 4. The one screen that stays dark, and why

**The scanner.** Both the inline viewfinder and the full-screen scanner.

The feed is an arbitrary image — a marble counter, a black terminal, a moving
hand — and the only overlay treatment that survives all of them is light on
dark. This is not a style exception, it is a contrast requirement, and it is
enforced by `onCameraScrim` / `onCameraInk` / `onCameraAccent`, which
deliberately do not follow the app's ground.

`F-130` records what happens when that is forgotten: flipping the ground turned
the scrim into a **white fog over the viewfinder**.

Gold survives in exactly one place — `onCameraAccent` — because over the feed,
the old "gold on black, always" rule is still true.

---

## 5. Order of work

| # | Change | Size | Status |
|---|---|---|---|
| 1 | Paper palette, camera surfaces protected | large | ✅ `F-130` |
| 2 | MCC crop on the flash card | small | ✅ `F-133` |
| 3 | Space pass — §3.3 | medium | 📋 |
| 4 | Display serif for headlines — §3.2 | medium, own commit | 📋 |
| 5 | Cap the decorative loops — §3.4 | small | 📋 |
| 6 | Sheet redesign around one big number | medium | 📋 |

Items 3–6 are deliberately not bundled with the palette change. A palette flip
is already the largest visual diff this project has taken, and stacking a type
change on top of it would make a bad outcome impossible to bisect.
