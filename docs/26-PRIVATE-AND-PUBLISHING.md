# 26 — Going private, and getting on the Play Store

---

## 1. Does Claude Code still work on a private repo?

**Yes. Nothing about our working method changes.**

Access comes from the Claude GitHub App being installed on the repository, not
from the repo being readable by the public. The App holds an installation token
scoped to `adityamaurya/swip`, and that token works identically on a private
repo. Reading files, pushing commits, reading CI logs, downloading artifacts —
all unchanged.

If a session ever *does* lose access after the switch, the cause is the App
installation being scoped to "only selected repositories" and the repo having
dropped off that list. Fix: <https://github.com/settings/installations> → Claude
→ **Repository access** → confirm SWIP is selected.

### The one thing that genuinely changes — and it will bite

GitHub Actions is free and unmetered on **public** repos. On a **private** repo,
the Free plan gives you:

| Resource | Free-plan allowance on a private repo |
|---|---|
| Linux Actions minutes | **2,000 / month** |
| Artifact + Packages storage | **500 MB total** |

> On private repositories the Free plan includes 2,000 Linux minutes per month
> plus 500 MB of artifact storage.
> — [CICDCalculator, GitHub Actions free tier](https://cicdcalculator.com/github-actions-free-tier)
> · [GitHub Docs, Actions billing](https://docs.github.com/billing/managing-billing-for-github-actions/about-billing-for-github-actions)

Do the arithmetic on this project:

* Each full run is roughly **10 minutes** → 2,000 minutes is about **200 builds
  a month**. Not a problem.
* Each debug APK is about **87 MB**, and the default retention is **90 days** →
  **the sixth build of the month fills the 500 MB quota**, and after that
  uploads fail with a quota error that looks nothing like a build failure.

**Already fixed** (`F-110`): the workflow now sets `retention-days: 5`, so the
running total stays near one build's worth instead of ninety days of them. If
you ever do hit it, clear old artifacts at
`Actions → any run → Artifacts → delete`, or bump the retention lower.

### Doing the switch

<https://github.com/adityamaurya/SWIP/settings> → **Danger Zone** →
**Change repository visibility** → **Make private** → type the repo name.

Two honest caveats:

* **It is not retroactive.** Anyone who already cloned or forked it keeps their
  copy. The repo has been public for the whole build, so treat the current code
  as having been seen.
* Forks made while it was public do **not** disappear. There is no way to recall
  them.

### What else to lock down

| Setting | Where | Why |
|---|---|---|
| Two-factor auth | Settings → Password and authentication | The account is the only real lock |
| Recovery codes saved off-inbox | same page | See [`25-CONTINUITY.md`](25-CONTINUITY.md) |
| Secret scanning + push protection | Repo → Settings → Code security | Stops an API key being committed |
| No secrets in the repo | — | Razorpay keys go in Actions **Secrets**, never in a file |
| Branch protection on `main` | Repo → Settings → Branches | Stops a bad force-push |

### One thing to keep out of the repository regardless

Your exact debt and income figures. They are in the app as a **goal and a
percentage** (see [`27-DONATIONS.md`](27-DONATIONS.md)) and that is all that is
needed for the progress bar to work. A private repo can be made public by one
mis-click; a number tied to your name cannot be un-published.

---

## 2. Getting on the Play Store

### 2.1 What you actually need to buy

| Thing | Cost | Notes |
|---|---|---|
| Google Play Developer account | **$25 once** | Personal or your OPC. Use the OPC if you want the company named as developer |
| Servers / AWS / backend | **₹0** | SWIP has no server. Nothing to host. This is worth knowing — it is the whole reason running costs are nil |
| Domain (for the privacy policy) | ~₹800/yr | Play **requires** a public privacy-policy URL. A GitHub Pages site is free if you would rather not buy one |
| Play Console verification | ₹0 | Identity documents; for an OPC, the incorporation certificate |

That is the entire bill: **$25 and a privacy-policy page.** No cloud, no
database, no monthly anything — because the ledger is local SQLite and there is
no account system.

### 2.2 What has to be built or changed before you can ship

Ordered by how much it blocks release.

**Blocking**

1. **A signed release build.** Everything so far has been a *debug* APK. Play
   needs a signed App Bundle (`.aab`). Needs a keystore generated once, stored
   as a GitHub Actions secret, and *never lost* — lose it and you can never
   update the app again.
2. **A privacy policy URL.** Non-negotiable. Ours is unusually easy to write
   honestly: no account, no server, no analytics, nothing leaves the device
   except an export the user triggers.
3. **The Data Safety form.** Declare camera (to read a code, not stored),
   approximate location (opt-in, reduced to a ~1.2 km geohash on device), NFC.
   All "not collected, not shared" — which is true and rare.
4. **Target API level.** Play enforces a floor that rises annually; the build
   must target the current requirement.
5. **App icon, feature graphic, screenshots.** The icon is done (`F-109`).

**Will get you rejected if wrong**

6. **The NFC card-emulation declaration.** SWIP registers payment AIDs and asks
   to be the default contactless app. Reviewers look closely at this. The
   listing must say plainly that SWIP *reads a category and declines* — it never
   pays. Being explicit is the defence.
7. **The donation flow.** Google's Payments policy: a *voluntary donation* to
   the developer may use an external method, but anything that unlocks features
   must use Play Billing. Ours unlocks nothing, which keeps it on the right side
   — but the copy must not imply the donor receives anything.

**Should be done, not blocking**

8. Export/import hardening + the 02:00 auto-backup (queued).
9. An internal-testing track first: 20 testers, real devices, before production.

### 2.3 The order to do it in

```
keystore  →  signed .aab  →  privacy policy page  →  Play account ($25)
   →  Data Safety form  →  internal testing (20 testers)
   →  closed testing  →  production
```

Realistically two to three weeks of calendar time, most of it Google's review
queue rather than work.

---

## Sources

- [GitHub Docs — About billing for GitHub Actions](https://docs.github.com/billing/managing-billing-for-github-actions/about-billing-for-github-actions)
- [GitHub Docs — How use of GitHub Actions is measured](https://docs.github.com/en/billing/concepts/product-billing/github-actions)
- [CICDCalculator — GitHub Actions free tier limits](https://cicdcalculator.com/github-actions-free-tier)
- [GitHub Community — artifact storage quota on the Free plan](https://nannyakore.com/en/blog/gha-storage-quota-en/)
