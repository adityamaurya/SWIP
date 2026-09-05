# Find `const` expressions containing a method call that cannot be constant.
# Deliberately crude: it looks for `const X(` blocks and flags `.withValues(`,
# `.withOpacity(`, `.copyWith(` inside them.
import re, glob, sys
bad = 0
for f in glob.glob('lib/**/*.dart', recursive=True):
    src = open(f).read()
    for m in re.finditer(r'\bconst\s+[A-Za-z_][\w.]*\s*\(', src):
        i = m.end() - 1
        depth = 0
        j = i
        while j < len(src):
            if src[j] == '(': depth += 1
            elif src[j] == ')':
                depth -= 1
                if depth == 0: break
            j += 1
        block = src[i:j+1]
        for meth in ('.withValues(', '.withOpacity(', '.copyWith(', '.lerp('):
            if meth in block:
                line = src[:m.start()].count('\n') + 1
                print(f'{f}:{line}: `const` block contains {meth}')
                bad = 1
print('CONST OK' if not bad else 'CONST PROBLEMS')
sys.exit(bad)
