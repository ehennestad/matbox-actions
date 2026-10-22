import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import {
  LABEL_COLOR,
  SEVERITIES,
  ZERO_COUNT_COLOR,
  layoutSegments,
  main,
  parseCounts,
  renderSegmentedBadge,
} from './render-segmented-badge.mjs';

const severityColor = Object.fromEntries(SEVERITIES.map(({ key, color }) => [key, color]));

function writeTempFile(name, content) {
  const path = join(mkdtempSync(join(tmpdir(), 'segmented-badge-')), name);
  writeFileSync(path, content);
  return path;
}

test('segments sit side by side and widen with multi-digit counts', () => {
  const counts = { error: 1, warning: 1234, info: 56 };
  const segments = layoutSegments('code issues', counts);

  assert.equal(segments.length, 4);
  assert.equal(segments[0].x, 0);
  for (let i = 1; i < segments.length; i++) {
    assert.equal(segments[i].x, segments[i - 1].x + segments[i - 1].width);
  }

  const [, oneDigit, fourDigits, twoDigits] = segments;
  assert.ok(fourDigits.width > twoDigits.width);
  assert.ok(twoDigits.width > oneDigit.width);

  const svg = renderSegmentedBadge('code issues', counts);
  const outerWidth = Number(svg.match(/^<svg [^>]*?width="([\d.]+)"/)[1]);
  const last = segments.at(-1);
  assert.equal(outerWidth, last.x + last.width);
  for (const { x } of segments) {
    assert.ok(svg.includes(`<g transform="translate(${x})">`));
  }
});

test('segments use severity colors and grey for zero counts', () => {
  const nonZero = layoutSegments('code issues', { error: 2, warning: 3, info: 4 });
  assert.deepEqual(
    nonZero.map((s) => s.color),
    [LABEL_COLOR, severityColor.error, severityColor.warning, severityColor.info],
  );

  const someZero = layoutSegments('code issues', { error: 0, warning: 3, info: 0 });
  assert.deepEqual(
    someZero.map((s) => s.color),
    [LABEL_COLOR, ZERO_COUNT_COLOR, severityColor.warning, ZERO_COUNT_COLOR],
  );

  // Each background starts at its segment and runs to the right edge
  const svg = renderSegmentedBadge('code issues', { error: 0, warning: 3, info: 0 });
  const width = someZero.at(-1).x + someZero.at(-1).width;
  for (const { x, color } of someZero) {
    assert.ok(svg.includes(`<rect x="${x}" width="${width - x}" height="20" fill="${color}"/>`));
  }
});

test('only the outer badge is clipped and rounded', () => {
  const svg = renderSegmentedBadge('code issues', { error: 0, warning: 3, info: 5 });
  assert.equal([...svg.matchAll(/<clipPath/g)].length, 1);
  assert.equal([...svg.matchAll(/clip-path=/g)].length, 1);
  assert.deepEqual([...svg.matchAll(/ rx="([\d.]+)"/g)].map((m) => m[1]), ['3']);
});

test('ids are unique and every reference resolves', () => {
  const svg = renderSegmentedBadge('code issues', { error: 0, warning: 3, info: 5 });
  const ids = [...svg.matchAll(/ id="([^"]+)"/g)].map((m) => m[1]);
  assert.equal(new Set(ids).size, ids.length);
  for (const [, ref] of svg.matchAll(/url\(#([^)]+)\)/g)) {
    assert.ok(ids.includes(ref), `Unresolved reference #${ref}`);
  }
});

test('the outer badge carries the accessible name', () => {
  const svg = renderSegmentedBadge('code issues', { error: 1, warning: 0, info: 5 });
  assert.match(svg, /^<svg [^>]*aria-label="code issues: 1 error, 0 warnings, 5 info"/);
  assert.equal([...svg.matchAll(/role="img"/g)].length, 1);
  assert.equal([...svg.matchAll(/<title>/g)].length, 1);
});

test('parseCounts returns null without a counts field and rejects invalid counts', () => {
  assert.equal(parseCounts({ label: 'code issues', message: '3', color: 'yellow' }), null);
  assert.deepEqual(
    parseCounts({ counts: { error: 0, warning: 3, info: 5 } }),
    { error: 0, warning: 3, info: 5 },
  );
  assert.throws(() => parseCounts({ counts: { error: 0, warning: 3 } }));
  assert.throws(() => parseCounts({ counts: { error: -1, warning: 3, info: 5 } }));
  assert.throws(() => parseCounts({ counts: { error: 1.5, warning: 3, info: 5 } }));
});

test('main writes the segmented badge when the JSON holds counts', () => {
  const jsonFile = writeTempFile('code_issues.json', JSON.stringify({
    schemaVersion: 1, label: 'code issues', message: '8', color: 'yellow',
    counts: { error: 0, warning: 3, info: 5 },
  }));
  const svgFile = writeTempFile('code_issues.svg', '<svg>single</svg>');

  assert.equal(main([jsonFile, svgFile]), true);
  assert.match(readFileSync(svgFile, 'utf8'), /aria-label="code issues: 0 errors, 3 warnings, 5 info"/);
});

test('main keeps the single badge when counts are missing or invalid', () => {
  const singleBadge = '<svg>single</svg>';
  const badgeJsons = [
    { schemaVersion: 1, label: 'code issues', message: '8', color: 'yellow' },
    { schemaVersion: 1, label: 'code issues', message: '8', color: 'yellow', counts: { error: 0 } },
  ];
  for (const badgeJson of badgeJsons) {
    const jsonFile = writeTempFile('code_issues.json', JSON.stringify(badgeJson));
    const svgFile = writeTempFile('code_issues.svg', singleBadge);

    assert.equal(main([jsonFile, svgFile]), false);
    assert.equal(readFileSync(svgFile, 'utf8'), singleBadge);
  }
});
