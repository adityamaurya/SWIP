import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/swip_tokens.dart';

/// `F-148` — the screen that shows the twelve words.
///
/// ## What this screen has to achieve, and it is only one thing
///
/// The user must **leave it having actually recorded the phrase**. Everything
/// else is decoration. A screen that shows twelve words and a Continue button
/// gets tapped through in a second and a half, and the failure shows up months
/// later as an unopenable backup — at which point nothing can be done, by
/// anybody, ever.
///
/// So three decisions, all pulling the same way:
///
/// 1. **There is no Continue until the words have been on screen.** Not a
///    timer — a deliberate act: the copy button, or the acknowledgement
///    checkbox. Tapping through without touching either is not possible.
/// 2. **The consequence is stated in the second person and in full**, above
///    the words rather than below them, because nobody reads what is under the
///    thing they came for.
/// 3. **The words are numbered and in a grid**, not a sentence. A paragraph of
///    twelve words gets transcribed with two of them swapped; a numbered grid
///    does not.
///
/// There is no screenshot suppression. `FLAG_SECURE` would block one, and it
/// would also block the single most likely way this actually gets recorded on
/// a phone with no pen nearby. Blocking the realistic path to protect against
/// an attacker who already has the screen is the wrong trade — the phrase is
/// in `SharedPreferences` on the same device anyway.
class RecoveryPhrasePage extends StatefulWidget {
  const RecoveryPhrasePage({
    super.key,
    required this.phrase,
    this.isFirstTime = true,
  });

  final String phrase;

  /// First time through, the user must acknowledge. When they are merely
  /// looking the phrase up again, they may simply leave.
  final bool isFirstTime;

  @override
  State<RecoveryPhrasePage> createState() => _RecoveryPhrasePageState();
}

class _RecoveryPhrasePageState extends State<RecoveryPhrasePage> {
  bool _acknowledged = false;
  bool _copied = false;

  List<String> get _words => widget.phrase.split(RegExp(r'\s+'));

  @override
  Widget build(BuildContext context) {
    final canContinue = !widget.isFirstTime || _acknowledged || _copied;

    return Scaffold(
      backgroundColor: SwipColors.bg,
      appBar: AppBar(
        title: const Text('Your recovery phrase'),
        backgroundColor: SwipColors.bg,
        foregroundColor: SwipColors.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  SwipSpace.xl, SwipSpace.md, SwipSpace.xl, SwipSpace.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'These twelve words are the only way to open your '
                    'backups.',
                    style:
                        SwipType.titleM.copyWith(color: SwipColors.textPrimary),
                  ),
                  const SizedBox(height: SwipSpace.md),
                  Text(
                    'SWIP has no server and no account, so there is nobody to '
                    'ask for a reset — not you, not us. Write them down '
                    'somewhere that is not this phone. If you uninstall SWIP '
                    'and you still have these words, every backup you have '
                    'ever made still opens. If you do not, none of them ever '
                    'will again.',
                    style: SwipType.bodyM
                        .copyWith(color: SwipColors.textSecondary),
                  ),
                  const SizedBox(height: SwipSpace.xl),

                  // ── the words ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(SwipSpace.lg),
                    decoration: BoxDecoration(
                      color: SwipColors.surfaceRaised,
                      borderRadius: SwipRadius.cardAll,
                      border: Border.all(color: SwipColors.hairline),
                    ),
                    child: Wrap(
                      spacing: SwipSpace.md,
                      runSpacing: SwipSpace.md,
                      children: [
                        for (var i = 0; i < _words.length; i++)
                          _Word(index: i + 1, word: _words[i]),
                      ],
                    ),
                  ),
                  const SizedBox(height: SwipSpace.lg),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: widget.phrase));
                        HapticFeedback.selectionClick();
                        if (mounted) setState(() => _copied = true);
                      },
                      icon: Icon(
                        _copied
                            ? Icons.check_rounded
                            : Icons.copy_rounded,
                        size: 16,
                      ),
                      label: Text(_copied ? 'Copied' : 'Copy the words'),
                    ),
                  ),
                  const SizedBox(height: SwipSpace.xs),
                  Text(
                    'Copying puts them on your clipboard, which other apps can '
                    'read. Paste them into a password manager and clear it, '
                    'rather than leaving them there.',
                    style: SwipType.bodyS
                        .copyWith(color: SwipColors.textTertiary),
                  ),

                  if (widget.isFirstTime) ...[
                    const SizedBox(height: SwipSpace.lg),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _acknowledged,
                      onChanged: (v) =>
                          setState(() => _acknowledged = v ?? false),
                      title: Text(
                        'I have written these down somewhere safe',
                        style: SwipType.bodyM
                            .copyWith(color: SwipColors.textPrimary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── the way out ──
          Container(
            decoration: BoxDecoration(
              color: SwipColors.bg,
              border: Border(top: BorderSide(color: SwipColors.hairline)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(SwipSpace.xl),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    // Disabled until the words have actually been dealt with.
                    // This is the single most consequential screen in the app
                    // and the only one where a disabled button is the right
                    // answer.
                    onPressed: canContinue
                        ? () => Navigator.of(context).pop(true)
                        : null,
                    child: Text(widget.isFirstTime
                        ? 'Continue to the backup'
                        : 'Done'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Word extends StatelessWidget {
  const _Word({required this.index, required this.word});

  final int index;
  final String word;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: SwipSpace.md, vertical: SwipSpace.sm),
        decoration: BoxDecoration(
          color: SwipColors.bg,
          borderRadius: SwipRadius.inputAll,
          border: Border.all(color: SwipColors.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // Numbered, because order is part of the secret and a grid without
            // numbers gets transcribed with two words swapped.
            SizedBox(
              width: 18,
              child: Text(
                '$index',
                style: SwipType.bodyS.copyWith(
                  color: SwipColors.textTertiary,
                  fontFeatures: SwipType.tabular,
                ),
              ),
            ),
            Text(
              word,
              style: SwipType.mono.copyWith(color: SwipColors.textPrimary),
            ),
          ],
        ),
      );
}

/// `F-148` — asking for the phrase back, on import.
///
/// Separate from [RecoveryPhrasePage] because the two are opposite jobs: that
/// one is about getting words *out* of the app and onto paper, this one is
/// about getting them back in with as little friction as possible after the
/// user has already found the file.
class RecoveryPhrasePrompt extends StatefulWidget {
  const RecoveryPhrasePrompt({super.key, this.problem, this.suggested});

  /// What went wrong last time, when this is a second attempt.
  final String? problem;

  /// The phrase this install already holds, offered as a one-tap fill.
  ///
  /// Present whenever a backup is being restored onto the **same** install
  /// that made it — reinstalling onto a phone that still has its preferences,
  /// or importing a file you exported ten minutes ago. It is the common case
  /// and it should not cost twelve words of typing.
  final String? suggested;

  @override
  State<RecoveryPhrasePrompt> createState() => _RecoveryPhrasePromptState();
}

class _RecoveryPhrasePromptState extends State<RecoveryPhrasePrompt> {
  late final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: SwipColors.surfaceRaised,
        title: const Text('Your recovery phrase'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.problem != null) ...[
              Text(
                widget.problem!,
                style: SwipType.bodyS.copyWith(color: SwipColors.danger),
              ),
              const SizedBox(height: SwipSpace.md),
            ],
            Text(
              'Twelve words, in order. Capitals and extra spaces do not '
              'matter.',
              style:
                  SwipType.bodyS.copyWith(color: SwipColors.textSecondary),
            ),
            const SizedBox(height: SwipSpace.md),
            TextField(
              controller: _controller,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                hintText: 'word one, word two…',
              ),
              style: SwipType.mono.copyWith(color: SwipColors.textPrimary),
            ),
            if (widget.suggested != null) ...[
              const SizedBox(height: SwipSpace.sm),
              TextButton(
                onPressed: () => _controller.text = widget.suggested!,
                child: Text(
                  'Use this phone\'s phrase',
                  style: SwipType.bodyS
                      .copyWith(color: SwipColors.textSecondary),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_controller.text),
            child: const Text('Open backup'),
          ),
        ],
      );
}
