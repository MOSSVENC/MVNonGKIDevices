#!/usr/bin/env python3
"""Structural guard for a Kconfig file assembled at build time.

usage: check-kconfig-structure.py <Kconfig path> [...]

The build appends a generated menu to the KernelSU fork's kernel/Kconfig.
An entry whose description block lost its 'help' keyword makes kconfig
read the indented '-' lines as options and abort the whole defconfig
step, so this guard rejects:

  * description lines ('- ...' at menu indentation) that follow a config
    entry without a 'help' keyword,
  * unbalanced menu/endmenu pairs,
  * an endmenu that closes no open menu.

Exit status is non-zero with the offending line numbers on failure.
"""
import sys


def strip_comment(line):
    return line.split('#', 1)[0].rstrip()


def check(path):
    errors = []
    depth = 0
    in_help = False
    with open(path) as fh:
        for num, raw in enumerate(fh.read().split('\n'), 1):
            line = raw.rstrip()
            text = line.strip()
            if not text:
                continue
            # help bodies are free-form text; only their keyword ends them
            if in_help:
                if line.startswith((' ', '\t')):
                    continue
                in_help = False
            if line.startswith(('menu ', 'menuconfig')):
                depth += 1
            elif line.startswith(('if ', 'choice')):
                depth += 1
            elif text == 'endmenu' or text.startswith('endif'):
                depth -= 1
                if depth < 0:
                    errors.append((num, 'endmenu without an open menu'))
                    depth = 0
                continue
            elif text.startswith('config '):
                in_help = False
                continue
            elif text == 'help' or text.startswith('help '):
                in_help = True
                continue
            if line.startswith((' ', '\t')) and text.startswith('-'):
                errors.append((num, 'description line outside a help block'))
            elif not line.startswith((' ', '\t')) and text.startswith('-'):
                errors.append((num, 'stray option starting with "-"'))
    if depth != 0:
        errors.append((0, '%d menu/if block(s) left open' % depth))
    return errors


def main(argv):
    if len(argv) < 2:
        sys.stderr.write(__doc__)
        return 2
    failed = False
    for path in argv[1:]:
        errors = check(path)
        if errors:
            failed = True
            for num, msg in errors:
                where = '%s:%d' % (path, num) if num else path
                sys.stderr.write('%s: %s\n' % (where, msg))
        else:
            print('%s: structure ok' % path)
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
