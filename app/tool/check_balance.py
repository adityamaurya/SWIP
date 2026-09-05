import sys, glob, re

def strip(src):
    out=[]; i=0; n=len(src)
    while i<n:
        c=src[i]
        if c=='/' and i+1<n and src[i+1]=='/':
            while i<n and src[i]!='\n': i+=1
        elif c=='/' and i+1<n and src[i+1]=='*':
            i+=2
            while i+1<n and not (src[i]=='*' and src[i+1]=='/'): i+=1
            i+=2
        elif c in "'\"":
            # triple quoted?
            q=c
            if src[i:i+3]==q*3:
                i+=3
                while i<n and src[i:i+3]!=q*3:
                    if src[i]=='\\': i+=1
                    i+=1
                i+=3
            else:
                i+=1
                depth=0
                while i<n:
                    if src[i]=='\\': i+=2; continue
                    if src[i]=='$' and i+1<n and src[i+1]=='{':
                        # keep interpolation content so brackets inside still count
                        out.append('{')
                        i+=2; d=1
                        while i<n and d>0:
                            if src[i]=='{': d+=1
                            elif src[i]=='}': d-=1
                            out.append(src[i]); i+=1
                        continue
                    if src[i]==q: i+=1; break
                    if src[i]=='\n': break
                    i+=1
        else:
            out.append(c); i+=1
    return ''.join(out)

bad=0
for f in sorted(glob.glob('lib/**/*.dart', recursive=True)+glob.glob('test/**/*.dart', recursive=True)):
    s=strip(open(f).read())
    stack=[]; pairs={')':'(',']':'[','}':'{'}
    line=1; ok=True
    for ch in s:
        if ch=='\n': line+=1
        elif ch in '([{': stack.append((ch,line))
        elif ch in ')]}':
            if not stack or stack[-1][0]!=pairs[ch]:
                print(f'{f}:{line}: unbalanced {ch}'); ok=False; bad=1; break
            stack.pop()
    if ok and stack:
        print(f'{f}:{stack[-1][1]}: unclosed {stack[-1][0]}'); bad=1
print('BALANCE OK' if not bad else 'BALANCE FAILED')
sys.exit(bad)
