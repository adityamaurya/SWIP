# Getting an APK out of any project — the reusable recipe

> This is what we just did for SWIP, written so you can hand it to any Claude
> session, on any project, and get the same result: **a downloadable `.apk`
> built by GitHub, with no software installed on your machine.**
>
> Copy §1 verbatim into a new session. Everything after that explains why it
> works and how to handle the variations.

---

## 1. The prompt to paste

> **Set up GitHub Actions CI for this project so that every push builds a debug
> APK and uploads it as a downloadable artifact.**
>
> Requirements:
> 1. If the project has no Android build scaffold (no Gradle files, no `ios/`),
>    create a `tool/bootstrap.sh` that generates it **without destroying any
>    hand-written platform sources** — back them up, run `flutter create`, then
>    restore them over the generated files.
> 2. The workflow must run: bootstrap → analyze → test → **build APK** →
>    **upload the APK as an artifact**.
> 3. Let analyze and test each fail independently so both produce output in one
>    run, then a final step that makes the job status honest.
> 4. **Use the GitHub MCP tools to read the CI logs yourself after each push,
>    fix what failed, push again, and repeat until green.** Do not ask me to
>    paste logs.
> 5. Tell me plainly, after each round, what failed and why.
>
> Expect several rounds. Build-configuration failures surface one at a time
> because each masks the next.

**That's it.** Point five is the one that matters — it is the difference between
you copy-pasting errors for an hour and the agent iterating on its own.

---

## 2. Why this works, and what it costs

| | |
|---|---|
| **Cost** | ₹0. GitHub Actions is free for public repos, and 2,000 min/month free for private |
| **On your machine** | Nothing. No Android Studio, no Flutter, no Java |
| **Time per round** | ~2 min for analyze/test, ~5 min when the APK builds |
| **APK availability** | 90 days on the run page, then it expires |

The agent can read its own CI logs through the GitHub MCP tools, so the loop is
**write → push → read failure → fix → push** with no human in it.

---

## 3. Copy these two files

### `.github/workflows/flutter.yml`

Take SWIP's verbatim:
**[`.github/workflows/flutter.yml`](../.github/workflows/flutter.yml)**

The parts that matter:

```yaml
      - name: Analyze
        id: analyze
        continue-on-error: true     # ← so Test still runs
      - name: Test
        id: test
        continue-on-error: true     # ← so both errors appear in one round
      - name: Report
        run: |                      # ← makes the job status honest again
          if [ "${{ steps.analyze.outcome }}" != "success" ] \
          || [ "${{ steps.test.outcome }}" != "success" ]; then exit 1; fi
```

and the artifact upload, which is the whole point:

```yaml
      - name: Upload the APK
        uses: actions/upload-artifact@v4
        with:
          name: myapp-debug-apk
          path: app/build/app/outputs/flutter-apk/app-debug.apk
          if-no-files-found: error   # ← fail loudly rather than upload nothing
```

### `app/tool/bootstrap.sh`

**[`app/tool/bootstrap.sh`](../app/tool/bootstrap.sh)** — only needed if the
project has hand-written Android sources to protect. If the project was created
with `flutter create` normally, skip it and call `flutter pub get` instead.

---

## 4. Downloading the APK

1. Repo → **Actions** tab
2. Click the newest **green** run
3. Scroll to **Artifacts**
4. Download → it arrives as a `.zip`
5. Unzip → `app-debug.apk`
6. Move to your phone, tap, allow "install from unknown source"

---

## 5. The failures you will hit, and what they mean

These are the eight rounds SWIP took, generalised. Yours will be a subset.

| Symptom | What it really is | Fix |
|---|---|---|
| `library directive must appear before all other directives` | Dart file ordering | Move `library;` to line 1 |
| `X isn't defined for the type Y` | An API that moved or was removed in this Flutter version | Check the current API; prefer deleting the call over chasing imports |
| `The name 'MyApp' isn't a class` | `flutter create` wrote a placeholder `test/widget_test.dart` | Delete it in bootstrap |
| `asset directory doesn't exist` | `pubspec.yaml` declares assets nobody created | Create them, or remove the declaration |
| `unable to locate asset entry` | The file exists locally but **is not committed** | **Check `.gitignore` first** — see §6 |
| `AAPT: resource X not found` | The manifest references a drawable/string that doesn't exist | Create it under `res/` |
| `requires compileSdk 36 or later` | A plugin's pinned SDK is behind its own dependency | Force `compileSdk` across subprojects — see §7 |
| `Cannot run Project.afterEvaluate` | A Gradle block registered too late | It must go **before** Flutter's `subprojects { evaluationDependsOn(":app") }` |
| Gradle fails in **<2 min** | Build-script/config error | Read the script |
| Gradle fails in **~5 min** | Real compile error | Read the compiler output |

That last row is the most useful diagnostic in the table.

---

## 6. The trap that cost us a round

**A stale `.gitignore` rule silently dropped a file from every commit.**

The repo had `app/assets/fonts/*.ttf` from an old "fetch fonts at build time"
policy. When that policy was reversed and the font was vendored, `git add -A`
skipped it **without a word**. The commit looked complete. CI failed two minutes
later with a missing asset.

> **Whenever a file "is there" locally but CI says it is missing, run
> `git check-ignore -v <path>` before anything else.**

---

## 7. The compileSdk override

Plugins pin their own `compileSdk` and they drift out of date. When one plugin's
dependency demands a newer SDK than the plugin itself targets, nothing in your
module can fix it.

**Don't upgrade the plugins to satisfy Gradle** — newer majors bring API changes
and you end up rewriting working, tested code to fix a build-config problem.
Override it for every subproject instead. See the block in
[`bootstrap.sh`](../app/tool/bootstrap.sh); it must be **prepended** to
`android/build.gradle.kts`, not appended.

`compileSdk` only selects which APIs are available at compile time. `targetSdk`
(runtime behaviour) and `minSdk` (device support) are untouched.

---

## 8. Your other projects — the three cases

### Case A: already a Flutter/native Android app
§1 as written. Nothing else.

### Case B: a project that was specced as a **web app**, but you want an APK

Two honest routes.

| | **Rewrite native (Flutter)** | **Wrap the web app** |
|---|---|---|
| Effort | Weeks | Hours |
| Feel | Native, fast, offline | A website in a frame |
| Camera / NFC / GPS | Full access | Limited or none |
| Play Store | Fine | **Risky** — Google rejects apps that are only a website wrapper |
| Works offline | Yes | Usually no |

> **My recommendation, which matches your instinct: go native.**
>
> Wrapping is genuinely fine for one thing — *seeing your web app on a phone
> tonight*. It is a poor foundation for a product you intend to put on the Play
> Store, because Google's [minimum functionality
> policy](https://support.google.com/googleplay/android-developer/answer/9898820)
> treats a bare webview wrapper as spam.

**If you want the quick wrapper anyway**, the prompt is:

> Create a minimal Flutter app that loads `<my URL>` in a full-screen WebView,
> with pull-to-refresh, back-button handling, and an offline error screen. Then
> set up the CI from `docs/17-BUILD-ANY-APK.md` so I get an APK.

Use `webview_flutter` (Google-maintained). Budget an afternoon.

**If you go native**, tell the session:

> This project was originally specced as a web app. I want a native Android app
> instead. Re-read the spec, tell me which parts assume a browser and cannot
> carry over, propose the native architecture, and **wait for my go-ahead
> before writing code.**

That last sentence matters — it stops a rewrite starting from the wrong premise.

### Case C: a brand-new idea, no code yet

> Build this as a native Flutter app for Android. Before writing code, produce a
> short spec and a screen list and wait for my approval. Then set up the CI from
> `docs/17-BUILD-ANY-APK.md` **first**, so the very first commit produces an APK
> and stays green from there.

**Do this one.** SWIP took eight rounds precisely because ~2,000 lines were
written before anything could compile. **CI first, then code** turns eight
serial rounds into one failure at a time, caught the moment it's introduced.

---

## 9. Going from APK to the Play Store

The APK here is a **debug** build — fine for testing, cannot be published. For
the store you need a **release AAB**, signed with a key you own.

Full walkthrough, with fees and timelines:
**[13-PLAY-STORE-LAUNCH](13-PLAY-STORE-LAUNCH.md)**

The one thing to do early: **decide personal vs organisation account.** A
personal account must run a closed test with 12 people for 14 unbroken days
before it can even apply for production. Organisation accounts are exempt, and
you cannot convert later.

---

## 10. Checklist for a new project

- [ ] Repo on GitHub, agent has access
- [ ] Paste §1
- [ ] Let it iterate — expect 2–8 rounds
- [ ] Download the APK from the Actions tab
- [ ] Install, try it, report what breaks
- [ ] Only then: [13-PLAY-STORE-LAUNCH](13-PLAY-STORE-LAUNCH.md)
