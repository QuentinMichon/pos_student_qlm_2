#!/usr/bin/env python3
"""Convert a POS lab handout from LaTeX (labo/labNN/POS_labNN.tex) to reST.

The handouts use a deliberately small slice of LaTeX — sections, itemize,
enumerate, lstlisting and a handful of inline commands — so a purpose-built
converter is both shorter and more predictable here than a general tool: it
knows what \\entete means, which lstlisting style maps to which Pygments lexer,
and it stops on anything it was not taught rather than degrading silently.

    doc/tex2rst.py labo/lab01/POS_lab01.tex > doc/source/labs/lab01.rst
    doc/tex2rst.py --check labo/lab*/POS_lab*.tex     # report unknown markup

The output is meant to be read and edited afterwards: it is a starting point
that preserves the text, not a source-of-truth generator to be re-run.

Copyright (c) 2026 REDS Institute - HEIG-VD
"""

import argparse
import re
import sys

# lstlisting styles -> Pygments lexers. "console" transcripts keep their
# prompts, so the console lexer highlights them properly.
LST_STYLES = {
    'console': 'console',
    'code-c': 'c',
    None: 'text',
}

# Inline commands, applied in order. Nested braces are not used in the
# handouts (checked with --check), so a non-greedy match is enough.
INLINE = [
    (r'\\texttt\{([^{}]*)\}', r'``\1``'),
    (r'\\textbf\{([^{}]*)\}', r'**\1**'),
    (r'\\textit\{([^{}]*)\}', r'*\1*'),
    (r'\\emph\{([^{}]*)\}', r'*\1*'),
    # reST has no underline; the handouts use it for emphasis only.
    (r'\\underline\{([^{}]*)\}', r'**\1**'),
    (r'\\url\{([^{}]*)\}', r'\1'),
    (r'\\textrightarrow\s*', '→ '),
    (r'\\ldots', '…'),
    (r'\\%', '%'),
    (r'\\&', '&'),
    (r'\\_', '_'),
    (r'\\#', '#'),
    (r'\\\$', '$'),
    (r'\\,', ' '),
    (r'\\textasciitilde\s*', '~'),
    (r'\\textsuperscript\{([^{}]*)\}', r'\\ :sup:`\1`\\ '),
    (r'\\href\{([^{}]*)\}\{([^{}]*)\}', r'`\2 <\1>`_'),
    (r'\\underbar\{([^{}]*)\}', r'**\1**'),
    # \attention{...} is the class's warning box. Inline rather than a
    # directive: it appears mid-sentence inside list items, where a block
    # directive would break the item apart.
    (r'\\attention\s*\{([^{}]*)\}', r'⚠ \1'),
    # Inline math. imgmath is enabled in conf.py, so :math: renders properly;
    # $\sim$ is only ever used as a "roughly" sign, so spell it out.
    (r'\$\\sim\$\s*', '~'),
    (r'\$([^$]+)\$', r':math:`\1`'),
    # Line-break and size directives: reST has no equivalent worth keeping.
    (r'\\(linebreak|newline|break|small|normalsize|color\{[^}]*\})\s*', ' '),
]

# Dropped outright: spacing and layout directives with no reST equivalent.
DROP = re.compile(r'\\(bigskip|medskip|smallskip|newpage|clearpage|noindent|'
                  r'graphicspath\{+[^{}]*\}+|documentclass\{[^}]*\}|'
                  r'begin\{document\}|end\{document\}|usepackage(\[[^]]*\])?\{[^}]*\})\s*$')

# \attention{...} is the class's warning box (labo/images/attention.png).
ATTENTION = re.compile(r'\s*\\attention\{(.*)\}\s*$')

KNOWN_CMD = re.compile(r'\\(entete|section\*?|subsection\*?|subsubsection\*?|'
                       r'begin|end|item|texttt|textbf|textit|emph|underline|url|'
                       r'textrightarrow|ldots|bigskip|medskip|smallskip|newpage|'
                       r'clearpage|noindent|graphicspath|documentclass|mathrm|'
                       r'attention|textasciitilde|textsuperscript|href|underbar|'
                       r'linebreak|newline|break|small|normalsize|color|usepackage|'
                       r'%|&|_|#|\$|,|\\)')


def inline(text):
    # Iterate to a fixed point: the handouts nest commands (\textbf{\textit{x}},
    # \textbf{\underline{x}}), and a single pass converts only the inner one —
    # the outer pattern cannot match while braces remain inside it.
    for _ in range(8):
        before = text
        for pat, repl in INLINE:
            text = re.sub(pat, repl, text)
        if text == before:
            break
    # Escape the reST inline markup that survives, but never inside ``...``.
    parts = re.split(r'(``[^`]*``)', text)
    for i, p in enumerate(parts):
        if not p.startswith('``'):
            parts[i] = p.replace('|', r'\|')
    return ''.join(parts).rstrip()


def underline(title, char):
    return '%s\n%s' % (title, char * max(len(title), 3))


def convert(tex, title_fallback):
    out, list_stack = [], []
    verbatim = None          # pending code-block lines
    meta = {}

    lines = tex.replace('\r\n', '\n').split('\n')
    i = 0
    while i < len(lines):
        line = lines[i].rstrip()
        i += 1

        # --- verbatim ---------------------------------------------------
        if verbatim is not None:
            if re.match(r'\s*\\end\{lstlisting\}', line):
                body = verbatim['body']
                # strip the common indentation the handouts use inside listings
                strip = min((len(l) - len(l.lstrip()) for l in body if l.strip()),
                            default=0)
                # Indent the directive to the current list level. At column 0
                # inside a list, EVERY indented line that follows — the next
                # nested item included — is read as part of the literal block.
                pad = '  ' * len(list_stack) + ('  ' if list_stack else '')
                out.append('')
                out.append(pad + '.. code-block:: %s' % verbatim['lang'])
                out.append('')
                out.extend(pad + '   ' + l[strip:] if l.strip() else '' for l in body)
                out.append('')
                verbatim = None
            else:
                verbatim['body'].append(line)
            continue

        m = re.match(r'\s*\\begin\{lstlisting\}(?:\[style=([^\]]*)\])?', line)
        if m:
            verbatim = {'lang': LST_STYLES.get(m.group(1), 'text'), 'body': []}
            continue

        # --- comments, dropped directives -------------------------------
        if re.match(r'\s*%', line) or DROP.match(line.strip()):
            continue

        # --- header -----------------------------------------------------
        m = re.match(r'\s*\\entete\{(.*?)\}\{(.*?)\}\{(.*?)\}\s*$', line)
        if m:
            meta['title'], meta['authors'], meta['ref'] = (inline(x) for x in m.groups())
            continue

        m = re.match(r'\s*\$\$(.+)\$\$\s*$', line)
        if m:
            # Indent from the list nesting, not from the LaTeX source: the
            # handouts indent display math cosmetically, which reST reads as a
            # block quote.
            pad = '  ' * len(list_stack) + ('  ' if list_stack else '')
            out += ['', pad + '.. math::', '', pad + '   ' + m.group(1), '']
            continue

        m = ATTENTION.match(line)
        if m:
            out += ['', '.. warning::', '', '   ' + inline(m.group(1)), '']
            continue

        # --- sections ---------------------------------------------------
        m = re.match(r'\s*\\(sub)?(sub)?section\*?\{(.*)\}\s*$', line)
        if m:
            depth = len([g for g in m.groups()[:2] if g])
            out += ['', underline(inline(m.group(3)), '-=~'[min(depth, 2)] if depth else '='), '']
            continue

        # --- lists ------------------------------------------------------
        m = re.match(r'\s*\\begin\{(itemize|enumerate)\}', line)
        if m:
            list_stack.append('#.' if m.group(1) == 'enumerate' else '*')
            out.append('')
            continue
        if re.match(r'\s*\\end\{(itemize|enumerate)\}', line):
            if list_stack:
                list_stack.pop()
            out.append('')
            continue

        # \item[\textrightarrow] uses a custom bullet glyph; reST draws its own,
        # so the marker is dropped rather than carried into the text.
        m = re.match(r'\s*\\item\s*(?:\[[^\]]*\])?\s*(.*)$', line)
        if m and list_stack:
            indent = '  ' * (len(list_stack) - 1)
            out.append('%s%s %s' % (indent, list_stack[-1], inline(m.group(1))))
            continue

        # --- plain text -------------------------------------------------
        if not line.strip():
            out.append('')
            continue
        indent = '  ' * len(list_stack) + ('  ' if list_stack else '')
        out.append(indent + inline(line.strip()) if list_stack else inline(line))

    title = meta.get('title') or title_fallback
    head = ['.. _%s:' % title_fallback.lower().replace(' ', '-'), '',
            '=' * len(title), title, '=' * len(title), '']
    if meta:
        head += [':Laboratoire: %s' % meta.get('ref', ''),
                 ':Enseignants: %s' % meta.get('authors', ''), '']

    body = '\n'.join(head + out)
    return re.sub(r'\n{3,}', '\n\n', body).strip() + '\n'


def check(paths):
    bad = {}
    for p in paths:
        for m in re.finditer(r'\\[a-zA-Z]+', open(p, encoding='utf-8', errors='replace').read()):
            if not KNOWN_CMD.match(m.group(0)):
                bad.setdefault(m.group(0), []).append(p.split('/')[-1])
    for cmd, files in sorted(bad.items(), key=lambda kv: -len(kv[1])):
        print('%-24s %d occurrence(s), e.g. %s' % (cmd, len(files), files[0]))
    return 1 if bad else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('tex', nargs='+')
    ap.add_argument('--check', action='store_true',
                    help='only report LaTeX commands the converter does not know')
    args = ap.parse_args()

    if args.check:
        sys.exit(check(args.tex))

    for path in args.tex:
        name = re.sub(r'.*?(lab\d+).*', r'\1', path)
        sys.stdout.write(convert(open(path, encoding='utf-8', errors='replace').read(), name))


if __name__ == '__main__':
    main()
