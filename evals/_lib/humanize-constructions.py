#!/usr/bin/env python3
"""Run the same labelled construction cases against an original or candidate toolkit."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--toolkit', type=Path, required=True)
    parser.add_argument('--cases', type=Path, default=Path(__file__).with_suffix('.json'))
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--section', default='RHETORICAL SCAFFOLDING',
                        help='Report group to evaluate; other groups must stay unchanged')
    args = parser.parse_args()
    cases = json.loads(args.cases.read_text())
    results = []
    with tempfile.TemporaryDirectory(prefix='humanize-eval-') as temp:
        for case in cases:
            path = Path(temp) / (case['id'] + '.md')
            path.write_text(case['text'] + '\n')
            run = subprocess.run([sys.executable, str(args.toolkit / 'slop_report.py'), str(path)],
                                 capture_output=True, text=True, timeout=30)
            unavailable = re.search(r'^(?:slop_index: \(scorer unavailable:'
                                    r'|    \(construction_scanner unavailable:)', run.stdout, re.M)
            if run.returncode or unavailable:
                raise RuntimeError(f"{case['id']}: scanner failed: {run.stderr or run.stdout}")
            section = re.search(r'^— ' + re.escape(args.section) + r'[^\n]*\n(?:    [^\n]*\n)*', run.stdout, re.M)
            flagged = bool(section and not section.group(0).splitlines()[0].endswith(': none'))
            legacy = run.stdout[:section.start()] + run.stdout[section.end():] if section else run.stdout
            results.append(dict(id=case['id'], group=case['group'], expected=case['flag'],
                                flagged=flagged, legacy_sha256=hashlib.sha256(legacy.encode()).hexdigest(),
                                findings=section.group(0) if section else ''))
    counts = {name: sum((r['expected'], r['flagged']) == pair for r in results)
              for name, pair in {'TP': (True, True), 'TN': (False, False),
                                 'FP': (False, True), 'FN': (True, False)}.items()}
    def rate(numerator, denominator):
        return numerator / denominator if denominator else None
    metrics = dict(recall=rate(counts['TP'], counts['TP'] + counts['FN']),
                   specificity=rate(counts['TN'], counts['TN'] + counts['FP']),
                   accuracy=rate(counts['TP'] + counts['TN'], len(results)),
                   precision=rate(counts['TP'], counts['TP'] + counts['FP']))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(dict(positive_class='needs editorial review', counts=counts,
                                          metrics=metrics, cases=results), indent=2) + '\n')
    pairs = args.output.with_suffix('.labels.jsonl')
    pairs.write_text(''.join(json.dumps({'human': 'FAIL' if r['expected'] else 'PASS',
                                        'judge': 'FAIL' if r['flagged'] else 'PASS'}) + '\n'
                             for r in results))
    print(json.dumps(dict(counts=counts, metrics=metrics, output=str(args.output)), indent=2))


if __name__ == '__main__':
    main()
