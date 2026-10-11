#!/usr/bin/env python3
"""Check local links in the public documentation entry points, without network."""
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
PAGES = [
    'README.md', 'CONTRIBUTING.md', 'CONTRIBUTORS.md', 'CHANGELOG.md',
    'SECURITY.md', 'NOTICE.md', 'third_party/README.md',
    'docs/quick-start.md', 'docs/cli.md', 'docs/repository-map.md',
    'docs/release-checklist.md', 'docs/assets/README.md',
]


def anchors(text):
    counts = {}
    result = set()
    for heading in re.findall(r'^#{1,6}\s+(.+?)\s*#*$', text, re.M):
        heading = re.sub(r'[^\w\-\s]', '', heading.lower()).replace(' ', '-')
        count = counts.get(heading, 0)
        result.add(heading if not count else f'{heading}-{count}')
        counts[heading] = count + 1
    return result


def main():
    errors = []
    for name in PAGES:
        page = ROOT / name
        if not page.is_file():
            errors.append(f'{name}: missing document')
            continue
        source = re.sub(r'```.*?```', '', page.read_text(), flags=re.S)
        targets = re.findall(r'!?\[[^\]]*\]\(([^)]+)\)', source)
        targets += re.findall(r'(?:src|href)="([^"]+)"', source)
        for target in targets:
            parsed = urlsplit(target.strip('<>'))
            if parsed.scheme or parsed.netloc:
                continue
            dest = page.parent / unquote(parsed.path) if parsed.path else page
            if not dest.exists():
                errors.append(f'{name}: missing link target {target}')
            elif parsed.fragment and dest.suffix == '.md':
                if unquote(parsed.fragment) not in anchors(dest.read_text()):
                    errors.append(f'{name}: missing heading {target}')
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        return 1
    print(f'Public documentation links OK ({len(PAGES)} entry points; offline).')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
