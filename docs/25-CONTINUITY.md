# 25 — Continuity: surviving the loss of this account

> *"currently the Claude code which I'm operating as of now is logging in via
> email, and the email is of the past organization … if by any chance the thing
> goes … I cannot get an email OTP for logging into this Claude code account"*

This document is the answer. Read section 1 now — it takes ten minutes and it is
the part that actually saves you. Section 4 is the block you paste into every
other project.

---

## 1. Do these five things today

### 1.1 Stop the account being a single point of failure

The Claude account is **not** where your project lives. The repository is. The
account is only the tool that edits it. So the goal is: *any* future account, on
*any* email, can pick this up cold.

That is already 80 % true, because of two files that have been maintained from
the beginning:

| File | What it preserves |
|---|---|
| [`21-PROMPT-LEDGER.md`](21-PROMPT-LEDGER.md) | **Every prompt you have written, verbatim**, with its to-dos and their status |
| [`CHANGELOG.md`](CHANGELOG.md) | Every change, why it was made, and what was rejected |

Those two are the reason a new account is a handover and not a restart.

### 1.2 Add a recovery email to the Claude account — before you need to

Do this while you still have inbox access. In Claude, go to settings and add a
personal email as a second sign-in method, then verify it. An account with two
verified addresses does not die when one mailbox does.

**This is the single highest-value action in this document.** Everything else
here is a fallback for having skipped it.

### 1.3 Get GitHub off the work email too

If the repository is under a GitHub account tied to the same work address, it has
the same problem. GitHub → **Settings → Emails** → add a personal address → make
it primary. Then **Settings → Password and authentication** → save the recovery
codes somewhere that is not that inbox.

### 1.4 Export the transcripts you cannot regenerate

The prompt ledger has your prompts. It does not have the *full* replies — the
long research answers, the reasoning about 3-D Secure, the P2PM explanation.
Those live only in the session transcripts.

In Claude Code on the web, each session has its own page. Save the ones that
matter as PDF (browser → Print → Save as PDF) into a folder in your own Drive.
The sessions worth keeping are the ones where a *decision* was made rather than
code written — you will recognise them, they are the long ones.

### 1.5 Clone the repository to your own machine

```bash
git clone https://github.com/adityamaurya/SWIP.git
```

One copy that is not on GitHub and not in a Claude container. Do it once a month.

---

## 2. What survives, and what does not

| Asset | Where it lives | Survives account loss? |
|---|---|---|
| All code | GitHub | **Yes** |
| Every prompt, verbatim | `docs/21-PROMPT-LEDGER.md` | **Yes** |
| Every decision and its reasoning | `docs/CHANGELOG.md` | **Yes** |
| The research (P2PM, 3DS, card rails) | `docs/22`, `23`, `24` | **Yes** |
| Build history and APKs | GitHub Actions | **Yes** (APKs expire; see `F-110`) |
| Full text of AI replies | Session transcripts only | **No — export them (1.4)** |
| The model's memory of this session | Nowhere | **No. It never did.** |

That last row is the important one and it is worth being blunt about: a new
Claude session does not remember anything. Not even the same account. Continuity
has never come from the model's memory — it comes from the files. Which is why
the ledger and changelog have been maintained so obsessively; they *are* the
memory.

---

## 3. Restarting on a new account, step by step

1. Sign in to Claude with the new email.
2. Connect the new account's GitHub App to `adityamaurya/SWIP` (an admin grant
   at <https://claude.ai/admin-settings> if the repo is under an org; personal
   repos just need the App installed).
3. Start a session on the repo.
4. **Paste the block in section 4 as your first message.**

That is it. The first reply should be the assistant telling you what it has
read and what the open items are. If it does not do that, the block did not
land — paste it again.

---

## 4. The handover block — copy this verbatim

Paste this as the **first message** of a session on any new account, and into any
other project after adapting the two lines marked `«adapt»`.

---

```
CONTEXT HANDOVER — READ BEFORE DOING ANYTHING ELSE

You are picking up a project mid-flight from a previous Claude account that I
have lost access to. I am not technical: I cannot read code, so I rely entirely
on you being accurate and on the written record being complete.

STEP 1 — READ THESE, IN THIS ORDER, BEFORE REPLYING
  1. docs/00-INDEX.md          — what every document is
  2. docs/21-PROMPT-LEDGER.md  — every prompt I have ever written, verbatim,
                                 with its to-dos and their status
  3. docs/CHANGELOG.md         — every change made, why, and what was rejected
  4. The three most recent docs/2*.md files    «adapt: research docs»
  5. git log --oneline -40     — the shape of recent work

STEP 2 — TELL ME, IN YOUR FIRST REPLY
  a. The last five things that were done, and their commit hashes
  b. Every open item, from the ledger's "📋" and "🔍" rows
  c. Anything the record says was DELIBERATELY REJECTED, so you do not
     helpfully rebuild it
  d. Anything the record contradicts itself about
  e. What you believe the next task is
Do not write any code in that first reply. If the documents are missing or thin,
say so plainly rather than guessing.

STANDING RULES — these carry over and are not negotiable

BRANCH
  • Work only on the branch named in my first task, or ask which one.
  • Never push to a different branch without asking.
  • Never open a pull request unless I explicitly ask for one.

THE WRITTEN RECORD — the most important rule in this list
  • After EVERY prompt of mine, append to docs/21-PROMPT-LEDGER.md:
      - my prompt, VERBATIM, in a blockquote, however long or rambling
      - a numbered table of every to-do it contains
      - the status of each: built / partial / rejected / held / blocked
  • After every batch of work, append to docs/CHANGELOG.md: what changed,
    WHY, and what you chose not to do.
  • NEVER delete or rewrite a row in either file. They are append-only. If
    something turns out to be wrong, add a correction below it; do not edit
    history.
  • If I give you ten requests and you do six, the ledger must say four are
    outstanding. Silently dropping a request is the worst thing you can do to
    me, because I cannot see the code to notice.

HONESTY
  • CI passing means "it compiles", not "it works". Never report a green build
    as a working feature. Say which claims are verified and which are not.
  • If something is broken, blocked, or impossible, say so in one sentence and
    then say what IS possible. Do not soften it and do not pad it.
  • If I ask for something that will not work, tell me once, plainly, with the
    reason — then if I say do it anyway, do it and note my decision in the
    ledger.
  • Never invent a requirement I did not give. If a prompt of mine is cut off
    or ambiguous, leave it as an open row and ask.

WORKING METHOD
  • Read the CI logs yourself after every push and fix until green. Do not ask
    me to paste logs.
  • Before pushing, verify the code parses — do not rely on reading it back.
  • Hyperlink everything. Whenever you tell me something exists — a file, a
    document, a commit, a build — give me the link. Never leave me with a claim
    I cannot go and look at.
  • Prefer deleting a feature that does not work over leaving it in looking
    like it does.

WHAT THIS PROJECT IS                                        «adapt this block»
  SWIP — an Android-first Flutter app that shows a merchant category code (MCC)
  BEFORE you pay, so a cardholder knows which card to use. Three capture routes
  work today: QR SCAN (EMVCo tag 52 / UPI mc), POS TAP (EMV tag 9F15 over NFC
  host card emulation), APP DIRECT (the merchant's own upi:// intent). The
  ledger is local-only SQLite; there is no account and no server.
  Design direction: near-black #060507, brand gold #C9A227.

Start with STEP 1 now.
```

---

## 5. Making it impossible to lose again

Two habits, both cheap:

**Every time you finish a working session, ask for one thing:**

> *"Update the prompt ledger and the changelog with everything from this
> session, then push."*

If the answer is anything other than a commit link, the record is not saved.

**Once a month:**

```bash
git clone https://github.com/adityamaurya/SWIP.git swip-backup-$(date +%Y-%m)
```

A repository you hold a copy of cannot be taken from you by an email address.

---

## 6. Keeping the code private

The repository was **public** until you changed it. What that means and what to
do is in [`26-PRIVATE-AND-PUBLISHING.md`](26-PRIVATE-AND-PUBLISHING.md),
including the artifact-storage trap that bites the moment a repo goes private.
