// Renders the code issues badge with one segment per severity.
//
// Usage: node render-segmented-badge.mjs <badge-json-file> <output-svg-file>
//
// MatBox writes the badge JSON with label, message and color fields, and
// adds a "counts" field with the error, warning and info counts. With valid
// counts this script writes a badge made of a label segment followed by one
// segment per severity. Without them it leaves the output file untouched, so
// the single badge rendered from label, message and color stays in place.
//
// badge-maker draws two-part badges only. Each segment's text therefore comes
// from a separate message-only badge, which sets the segment width and the
// text styling for its background color. The backgrounds, the gradient and
// the rounded corners are drawn once for the whole badge, in badge-maker's
// flat style.

import { readFileSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { makeBadge } from 'badge-maker';

export const LABEL_COLOR = '#555';
export const ZERO_COUNT_COLOR = '#9f9f9f';
export const SEVERITIES = [
  { key: 'error', color: '#e05d44', singular: 'error', plural: 'errors' },
  { key: 'warning', color: '#dfb317', singular: 'warning', plural: 'warnings' },
  { key: 'info', color: '#3b99dc', singular: 'info', plural: 'info' },
];

const BADGE_HEIGHT = 20;
const CORNER_RADIUS = 3;
// The gradient that badge-maker's flat style lays over a badge's background
const FLAT_GRADIENT = '<linearGradient id="s" x2="0" y2="100%">'
  + '<stop offset="0" stop-color="#bbb" stop-opacity=".1"/><stop offset="1" stop-opacity=".1"/>'
  + '</linearGradient>';

// Returns the counts in badgeInfo, or null when it has no counts field.
// Throws when the counts field is present but not usable.
export function parseCounts(badgeInfo) {
  if (badgeInfo.counts === undefined) {
    return null;
  }
  const counts = {};
  for (const { key } of SEVERITIES) {
    const value = badgeInfo.counts?.[key];
    if (!Number.isInteger(value) || value < 0) {
      throw new Error(`Badge counts must hold a non-negative integer "${key}" count.`);
    }
    counts[key] = value;
  }
  return counts;
}

// Returns each segment with its color, x offset, width and text content, in
// drawing order: the label, then one segment per severity.
export function layoutSegments(label, counts) {
  const segments = [
    { text: label, color: LABEL_COLOR },
    ...SEVERITIES.map(({ key, color }) => ({
      text: String(counts[key]),
      color: counts[key] === 0 ? ZERO_COUNT_COLOR : color,
    })),
  ];

  let x = 0;
  return segments.map((segment, index) => {
    const { content, width } = renderSegmentText(segment, `s${index}-`);
    const placed = { ...segment, x, width, content };
    x += width;
    return placed;
  });
}

export function renderSegmentedBadge(label, counts) {
  const segments = layoutSegments(label, counts);
  const lastSegment = segments.at(-1);
  const width = lastSegment.x + lastSegment.width;

  // Each background runs to the right edge of the badge, and the next
  // segment's background covers the rest. No join then depends on two
  // anti-aliased edges lining up.
  const backgrounds = segments
    .map(({ x, color }) => `<rect x="${x}" width="${width - x}" height="${BADGE_HEIGHT}" fill="${color}"/>`)
    .join('');
  const texts = segments
    .map(({ x, content }) => `<g transform="translate(${x})">${content}</g>`)
    .join('');

  const description = escapeXml(describeCounts(label, counts));
  return [
    `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${BADGE_HEIGHT}" role="img" aria-label="${description}">`,
    `<title>${description}</title>`,
    FLAT_GRADIENT,
    `<clipPath id="r"><rect width="${width}" height="${BADGE_HEIGHT}" rx="${CORNER_RADIUS}" fill="#fff"/></clipPath>`,
    `<g clip-path="url(#r)">${backgrounds}<rect width="${width}" height="${BADGE_HEIGHT}" fill="url(#s)"/></g>`,
    texts,
    '</svg>',
  ].join('');
}

export function describeCounts(label, counts) {
  const parts = SEVERITIES.map(({ key, singular, plural }) =>
    `${counts[key]} ${counts[key] === 1 ? singular : plural}`);
  return `${label}: ${parts.join(', ')}`;
}

// Renders text as a message-only flat badge and keeps only its text drawing
// and the shadow filter that the text uses.
function renderSegmentText({ text, color }, idPrefix) {
  const svg = makeBadge({ label: '', message: text, color, style: 'flat' });
  const width = Number(svg.match(/^<svg [^>]*?width="([\d.]+)"/)[1]);

  const content = svg
    .replace(/^<svg[^>]*>/, '')
    .replace(/<\/svg>$/, '')
    .replace(/<title>[^<]*<\/title>/, '')
    .replace(/<linearGradient[^>]*>.*?<\/linearGradient>/, '')
    .replace(/<clipPath[^>]*>.*?<\/clipPath>/, '')
    // The background group holds only rects, so the first closing tag ends it
    .replace(/<g clip-path="[^"]*">.*?<\/g>/, '')
    // Every segment defines the same filter id, and ids must be unique
    // across the whole document.
    .replace(/ id="([^"]+)"/g, ` id="${idPrefix}$1"`)
    .replace(/url\(#([^)]+)\)/g, `url(#${idPrefix}$1)`);

  return { content, width };
}

function escapeXml(text) {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// Writes the segmented badge and returns true, or returns false and leaves
// svgFile untouched when the badge JSON holds no usable counts.
export function main([jsonFile, svgFile]) {
  if (!jsonFile || !svgFile) {
    throw new Error('Usage: node render-segmented-badge.mjs <badge-json-file> <output-svg-file>');
  }

  const badgeInfo = JSON.parse(readFileSync(jsonFile, 'utf8'));
  let counts;
  try {
    counts = parseCounts(badgeInfo);
  } catch (error) {
    console.log(`::warning::${jsonFile}: ${error.message} Keeping the single badge.`);
    return false;
  }
  if (counts === null) {
    console.log(`${jsonFile} has no counts field; keeping the single badge.`);
    return false;
  }

  writeFileSync(svgFile, renderSegmentedBadge(badgeInfo.label, counts));
  console.log(`Rendered segmented badge to ${svgFile}`);
  return true;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main(process.argv.slice(2));
}
