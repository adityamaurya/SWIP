#!/usr/bin/env node
/**
 * SWIP brand asset generator.
 *
 *   node brand/generate.mjs
 *
 * Emits every logo variant from a single glyph definition so the wordmark,
 * the app icon and the monochrome marks can never drift apart.
 *
 * Glyph grid
 * ----------
 *   cap height 120  (y 20 -> 140)
 *   stroke      28
 *   advance     S 92 | W 134 | I 28 | P 96,  tracking 22
 *   total box   416 x 120
 *
 * The S is the hard glyph. A modular S built from flat rectangles always reads
 * as a "5", because a 5 is exactly that: a square top-left corner over a stem.
 * What separates them is the OUTER corners -- an S is a diagonal axis with its
 * top-left and bottom-right corners cut away, a 5 is not. So those two corners
 * are chamfered at 45deg. That single move is what makes the word legible.
 */

import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const OUT = dirname(fileURLToPath(import.meta.url));

// ---------------------------------------------------------------- tokens
export const GOLD = {
  foil: [
    [0.0, '#6E4F14'], [0.14, '#A67C22'], [0.33, '#D8B252'], [0.47, '#F6E4A6'],
    [0.53, '#FFF7DB'], [0.62, '#E3C46B'], [0.78, '#B98F2C'], [0.9, '#8A6620'],
    [1.0, '#5E430F'],
  ],
  core: '#C9A227',   // SWIP Gold 500 - the single flat brand gold
  ink: '#0A0A0A',    // SWIP Ink
};

const SLANT = 12;    // degrees of forward shear
const BOX = { w: 416, h: 120, top: 20, bottom: 140 };

// Shearing about y=80 throws the mark 60*tan(12deg) either side of the glyph
// box, so the drawn width is wider than BOX.w and the naive centre is wrong.
const OVERHANG = Math.round((BOX.h / 2) * Math.tan((SLANT * Math.PI) / 180)); // 13
const SLANTED_W = BOX.w + OVERHANG * 2;                                       // 442
const OPTICAL_X = Math.round((520 - SLANTED_W) / 2) + OVERHANG;               // 52

// ---------------------------------------------------------------- glyphs
// Each entry is an SVG shape element rendered in the 416x120 glyph space.
const GLYPHS = [
  // S -- x 0..92. Top bar + upper-left stem, outer top-left corner cut.
  '<polygon points="26,20 92,20 92,48 28,48 28,94 0,94 0,46"/>',
  // middle bar
  '<rect x="0" y="66" width="92" height="28"/>',
  // lower-right stem + bottom bar, outer bottom-right corner cut.
  '<polygon points="64,66 92,66 92,114 66,140 0,140 0,112 64,112"/>',

  // W -- x 114..248. Four diagonal strokes.
  '<polygon points="114,20 142,20 166,140 138,140"/>',
  '<polygon points="138,140 166,140 195,62 167,62"/>',
  '<polygon points="167,62 195,62 224,140 196,140"/>',
  '<polygon points="196,140 224,140 248,20 220,20"/>',

  // I -- x 270..298.
  '<rect x="270" y="20" width="28" height="120"/>',

  // P -- x 320..416. Counter is 40x24; anything tighter closes up at 24px.
  '<rect x="320" y="20" width="28" height="120"/>',   // stem
  '<rect x="320" y="20" width="96" height="28"/>',    // top bar
  '<rect x="388" y="20" width="28" height="80"/>',    // bowl right
  '<rect x="320" y="72" width="96" height="28"/>',    // bowl bottom
];

const glyphs = (fill, indent = '    ') =>
  `${indent}<g fill="${fill}">\n` +
  GLYPHS.map((g) => `${indent}  ${g}`).join('\n') +
  `\n${indent}</g>`;

/**
 * CRITICAL: gradientUnits="userSpaceOnUse".
 * The SVG default is objectBoundingBox, which gives every rect and polygon its
 * own private gradient sweep -- the mark then looks like fourteen unrelated
 * shards of gold instead of one milled foil surface. Coordinates below span the
 * whole glyph box so a single sweep crosses the entire wordmark.
 */
const foilDef = (id) => `
    <linearGradient id="${id}" gradientUnits="userSpaceOnUse"
                    x1="0" y1="${BOX.bottom}" x2="${BOX.w}" y2="${BOX.top}">
${GOLD.foil.map(([o, c]) => `      <stop offset="${o}" stop-color="${c}"/>`).join('\n')}
    </linearGradient>`;

const sheenDef = (id) => `
    <linearGradient id="${id}" gradientUnits="userSpaceOnUse"
                    x1="0" y1="${BOX.bottom}" x2="${BOX.w}" y2="${BOX.top}">
      <stop offset="0.30" stop-color="#FFFFFF" stop-opacity="0"/>
      <stop offset="0.46" stop-color="#FFFFFF" stop-opacity="0.42"/>
      <stop offset="0.58" stop-color="#FFFFFF" stop-opacity="0"/>
    </linearGradient>`;

// Shear about the optical centre of the cap height so the mark stays balanced.
const slant = (extra = '') =>
  `${extra} translate(0,80) skewX(-${SLANT}) translate(0,-80)`.trim();

// ---------------------------------------------------------------- variants
function wordmark({ fill, sheen }) {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 520 180" width="520" height="180" role="img" aria-label="SWIP">
  <title>SWIP</title>
  <defs>${fill === 'foil' ? foilDef('foil') + (sheen ? sheenDef('sheen') : '') : ''}
  </defs>
  <g transform="${slant(`translate(${OPTICAL_X},0)`)}">
${glyphs(fill === 'foil' ? 'url(#foil)' : fill)}
${sheen ? glyphs('url(#sheen)') : ''}
  </g>
</svg>
`;
}

function appicon({ mono = false } = {}) {
  // Glyph box scaled onto the 1024 grid, centred on the SLANTED width so the
  // shear overhang is accounted for on both sides.
  const S = 1.62;
  const x = Math.round((1024 - SLANTED_W * S) / 2 + OVERHANG * S);
  const y = Math.round((1024 - BOX.h * S) / 2) - Math.round(BOX.top * S);

  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024" role="img" aria-label="SWIP">
  <title>SWIP</title>
  <defs>${mono ? '' : `
    <linearGradient id="bg" x1="0" y1="0" x2="0.6" y2="1">
      <stop offset="0" stop-color="#161616"/>
      <stop offset="0.55" stop-color="#0A0A0A"/>
      <stop offset="1" stop-color="#000000"/>
    </linearGradient>
    <radialGradient id="bloom" cx="0.5" cy="0.46" r="0.60">
      <stop offset="0" stop-color="${GOLD.core}" stop-opacity="0.18"/>
      <stop offset="0.55" stop-color="${GOLD.core}" stop-opacity="0.04"/>
      <stop offset="1" stop-color="${GOLD.core}" stop-opacity="0"/>
    </radialGradient>${foilDef('foil')}${sheenDef('sheen')}
    <linearGradient id="rim" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${GOLD.core}" stop-opacity="0.50"/>
      <stop offset="0.5" stop-color="${GOLD.core}" stop-opacity="0.10"/>
      <stop offset="1" stop-color="${GOLD.core}" stop-opacity="0.38"/>
    </linearGradient>`}
  </defs>
${mono
      ? '  <rect width="1024" height="1024" fill="none"/>'
      : `  <rect width="1024" height="1024" fill="url(#bg)"/>
  <rect width="1024" height="1024" fill="url(#bloom)"/>`}
  <g transform="translate(${x},${y}) scale(${S}) ${slant()}">
${glyphs(mono ? '#FFFFFF' : 'url(#foil)', '    ')}
${mono ? '' : glyphs('url(#sheen)', '    ')}
  </g>
${mono ? '' : `  <rect x="6" y="6" width="1012" height="1012" rx="228" fill="none" stroke="url(#rim)" stroke-width="3"/>`}
</svg>
`;
}

/**
 * Monogram. The full wordmark is legible down to ~72px on the launcher, but at
 * 48px and in notification trays it silts up. This is the alternate: the S
 * alone, at 3.4x, cropped confidently by the tile edge.
 */
function monogram() {
  const S = 5.4;
  const x = Math.round((1024 - 92 * S) / 2 + OVERHANG * S * 0.5);
  const y = Math.round((1024 - BOX.h * S) / 2) - Math.round(BOX.top * S);
  const sGlyph = GLYPHS.slice(0, 3).join('\n      ');
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024" role="img" aria-label="SWIP">
  <title>SWIP monogram</title>
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0.6" y2="1">
      <stop offset="0" stop-color="#161616"/>
      <stop offset="1" stop-color="#000000"/>
    </linearGradient>
    <linearGradient id="foil" gradientUnits="userSpaceOnUse"
                    x1="0" y1="${BOX.bottom}" x2="92" y2="${BOX.top}">
${GOLD.foil.map(([o, c]) => `      <stop offset="${o}" stop-color="${c}"/>`).join('\n')}
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#bg)"/>
  <g transform="translate(${x},${y}) scale(${S}) ${slant()}">
    <g fill="url(#foil)">
      ${sGlyph}
    </g>
  </g>
</svg>
`;
}

// ---------------------------------------------------------------- emit
const assets = {
  // Primary: gold foil on transparent. Use on Ink or on imagery.
  'swip-wordmark.svg': wordmark({ fill: 'foil', sheen: true }),
  // Flat gold, no sheen. Use below 24px, and anywhere the foil would alias.
  'swip-wordmark-flat.svg': wordmark({ fill: GOLD.core, sheen: false }),
  // Ink. The ONLY correct mark on the light app background.
  'swip-wordmark-ink.svg': wordmark({ fill: GOLD.ink, sheen: false }),
  // Knockout, for photography and dark fills.
  'swip-wordmark-white.svg': wordmark({ fill: '#FFFFFF', sheen: false }),
  // Store icon, 1024 master. Full bleed - platforms apply their own mask.
  'swip-appicon.svg': appicon(),
  // Android 13+ themed icon / iOS tinted: white on transparent, no effects.
  'swip-appicon-monochrome.svg': appicon({ mono: true }),
  // Alternate icon for <=48px surfaces: notification, favicon, watch complication.
  'swip-monogram.svg': monogram(),
};

for (const [name, svg] of Object.entries(assets)) {
  writeFileSync(join(OUT, name), svg);
  console.log('wrote brand/' + name);
}
