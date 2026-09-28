/*
 * Generates public/og-image.png (1200x630 social/link-preview card) from
 * ../Portfolio.Server/profile.json using the site's colors.
 *
 * Not part of `npm run build`; re-run only if the name/headline/location change:
 *   cd client
 *   npm install --no-save sharp
 *   node scripts/generate-og-image.cjs
 */
const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

const profile = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', '..', 'Portfolio.Server', 'profile.json'), 'utf8'),
);
const out = path.join(__dirname, '..', 'public', 'og-image.png');

const esc = (s) =>
  String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

const W = 1200;
const H = 630;
const font = "Inter, 'Helvetica Neue', Arial, sans-serif";

let grid = '';
for (let x = 64; x < W; x += 64) grid += `<line x1="${x}" y1="0" x2="${x}" y2="${H}"/>`;
for (let y = 64; y < H; y += 64) grid += `<line x1="0" y1="${y}" x2="${W}" y2="${y}"/>`;

const initials = profile.name
  .split(/\s+/)
  .map((p) => p[0])
  .join('')
  .slice(0, 2)
  .toUpperCase();

const svg = `
<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
  <defs>
    <radialGradient id="glowF" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#d946ef" stop-opacity="0.35"/>
      <stop offset="1" stop-color="#d946ef" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="glowC" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#06b6d4" stop-opacity="0.28"/>
      <stop offset="1" stop-color="#06b6d4" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="glowE" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0" stop-color="#10b981" stop-opacity="0.22"/>
      <stop offset="1" stop-color="#10b981" stop-opacity="0"/>
    </radialGradient>
  </defs>

  <rect width="${W}" height="${H}" fill="#070A12"/>
  <g stroke="#ffffff" stroke-opacity="0.035" stroke-width="1">${grid}</g>

  <ellipse cx="760" cy="40" rx="420" ry="330" fill="url(#glowF)"/>
  <ellipse cx="1000" cy="170" rx="380" ry="300" fill="url(#glowC)"/>
  <ellipse cx="880" cy="330" rx="360" ry="260" fill="url(#glowE)"/>

  <rect x="88" y="88" width="72" height="72" rx="20" fill="#ffffff" fill-opacity="0.10"
        stroke="#ffffff" stroke-opacity="0.15" stroke-width="1.5"/>
  <text x="124" y="134" text-anchor="middle" font-family="${font}" font-size="26" font-weight="600"
        fill="#ffffff">${esc(initials)}</text>

  <text x="88" y="330" font-family="${font}" font-size="88" font-weight="600" letter-spacing="-2"
        fill="#ffffff">${esc(profile.name)}</text>
  <text x="88" y="400" font-family="${font}" font-size="40" font-weight="400"
        fill="#ffffff" fill-opacity="0.72">${esc(profile.headline)}</text>

  <line x1="88" y1="486" x2="${W - 88}" y2="486" stroke="#ffffff" stroke-opacity="0.10" stroke-width="1"/>
  <circle cx="96" cy="535" r="7" fill="#34d399"/>
  <text x="116" y="544" font-family="${font}" font-size="28" fill="#ffffff" fill-opacity="0.62">${esc(profile.location)}</text>
  <text x="${W - 88}" y="544" text-anchor="end" font-family="${font}" font-size="28" font-weight="500"
        fill="#ffffff" fill-opacity="0.80">socha3.com</text>
</svg>`;

sharp(Buffer.from(svg))
  .png({ compressionLevel: 9 })
  .toFile(out)
  .then((info) => console.log(`Wrote ${out} (${info.width}x${info.height}, ${info.size} bytes)`))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
