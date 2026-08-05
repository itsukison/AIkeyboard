import fs from "node:fs/promises";
import { createRequire } from "node:module";
import path from "node:path";

const require = createRequire(import.meta.url);
const sharp = require("sharp");

const outputDir = process.argv[2];
await fs.mkdir(outputDir, { recursive: true });

const captions = [
  {
    file: "opener-junior.png",
    lines: ["先輩、これ部長に送って", "大丈夫ですか？"],
    y: 860,
  },
  {
    file: "opener-senior.png",
    lines: ["その確認、今日3回目。"],
    y: 900,
  },
];

const escapeXml = (value) =>
  value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");

for (const caption of captions) {
  const lineHeight = 54;
  const lineGap = 0;
  const boxHeight = 54;
  const paddingX = 25;
  const visualUnits = (line) =>
    [...line].reduce((total, character) => {
      if (character === " ") return total + 0.35;
      if (/[\u0000-\u007f]/.test(character)) return total + 0.6;
      return total + 1;
    }, 0);
  const lineElements = caption.lines
    .map((line, index) => {
      const width = Math.min(680, Math.ceil(visualUnits(line) * 40 + paddingX * 2));
      const x = (720 - width) / 2;
      const y = caption.y + index * (lineHeight + lineGap);
      return `
        <rect x="${x}" y="${y}" width="${width}" height="${boxHeight}" rx="17"
              fill="#08080A" fill-opacity="0.95"/>
        <text x="360" y="${y + 40}" text-anchor="middle"
              font-family="Hiragino Sans, sans-serif" font-size="40"
              font-weight="700" fill="#FFFFFF">${escapeXml(line)}</text>
      `;
    })
    .join("");

  const svg = `
    <svg width="720" height="1280" xmlns="http://www.w3.org/2000/svg">
      ${lineElements}
    </svg>
  `;

  await sharp(Buffer.from(svg))
    .png()
    .toFile(path.join(outputDir, caption.file));
}
