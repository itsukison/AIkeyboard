import { execFile } from "node:child_process";
import { randomUUID } from "node:crypto";
import { existsSync } from "node:fs";
import { readdir, readFile, appendFile } from "node:fs/promises";
import { dirname, parse, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

function findRepoRoot(start: string): string {
  let current = start;
  const filesystemRoot = parse(current).root;
  while (current !== filesystemRoot) {
    if (existsSync(resolve(current, "AGENTS.md")) && existsSync(resolve(current, "docs/marketing/gtm/GTM.md"))) {
      return current;
    }
    current = dirname(current);
  }
  throw new Error("Could not locate the 敬語ボタン repository root.");
}

export const repoRoot = findRepoRoot(dirname(fileURLToPath(import.meta.url)));
const contentRoot = resolve(repoRoot, "docs/marketing/content");

export type ShareMode = "shareNow" | "addToQueue" | "customScheduled";

export interface Episode {
  slug: string;
  title: string;
  published: boolean;
  contentBankBacked: boolean;
  slideCount: number;
  ready: boolean;
  reasons: string[];
}

export interface PublishRequest {
  episode: string;
  caption: string;
  title: string;
  mode: ShareMode;
  dueAt?: string;
}

export function episodePath(slug: string): string {
  if (!/^\d{3}-[a-z0-9-]+$/.test(slug)) {
    throw new Error("Episode must look like 014-sick-day-pressure.");
  }
  return resolve(contentRoot, slug);
}

export async function listEpisodes(): Promise<Episode[]> {
  const entries = await readdir(contentRoot, { withFileTypes: true });
  const episodes = await Promise.all(entries
    .filter((entry) => entry.isDirectory() && /^\d{3}-/.test(entry.name))
    .map(async (entry) => inspectEpisode(entry.name)));
  return episodes.sort((a, b) => a.slug.localeCompare(b.slug));
}

export async function inspectEpisode(slug: string): Promise<Episode> {
  const root = episodePath(slug);
  const readme = await readFile(resolve(root, "README.md"), "utf8");
  const title = readme.match(/^#\s+(.+)$/m)?.[1] ?? slug;
  const published = /^## Published$/m.test(readme);
  const contentBankBacked = /spicy-content-bank/i.test(readme);
  let slides: string[] = [];
  try {
    slides = (await readdir(resolve(root, "render/instagram/cap")))
      .filter((name) => name.endsWith(".png"))
      .sort();
  } catch {
    slides = [];
  }

  const reasons: string[] = [];
  if (published) reasons.push("already published");
  if (!contentBankBacked) reasons.push("not linked to an approved content bank");
  if (slides.length === 0) reasons.push("no 1080 x 1350 cap slides");
  if (slides.length > 10) reasons.push(`${slides.length} slides; TikTok Photo Mode allows 10`);
  const expected = slides.map((_, index) => `${String(index + 1).padStart(2, "0")}.png`);
  if (slides.length > 0 && slides.some((name, index) => name !== expected[index])) {
    reasons.push("slides are not consecutively named");
  }

  return {
    slug,
    title,
    published,
    contentBankBacked,
    slideCount: slides.length,
    ready: reasons.length === 0,
    reasons,
  };
}

export function validatePublishRequest(request: PublishRequest): void {
  if (!request.caption.includes("※このチャットはフィクションです。")) {
    throw new Error("Caption must include: ※このチャットはフィクションです。");
  }
  const hashtags = request.caption.match(/#[^\s#]+/g) ?? [];
  if (hashtags.length > 5) {
    throw new Error(`Caption has ${hashtags.length} hashtags; the publishing runbook allows 5.`);
  }
  if (request.mode === "customScheduled") {
    if (!request.dueAt || Number.isNaN(Date.parse(request.dueAt))) {
      throw new Error("customScheduled requires a valid ISO-8601 dueAt value.");
    }
    if (Date.parse(request.dueAt) <= Date.now()) {
      throw new Error("dueAt must be in the future.");
    }
  } else if (request.dueAt) {
    throw new Error("dueAt is only valid with customScheduled mode.");
  }
}

export async function validateEpisodeAssets(slug: string): Promise<string> {
  const episode = await inspectEpisode(slug);
  if (!episode.ready) {
    throw new Error(`Episode is not publishable: ${episode.reasons.join("; ")}`);
  }
  const { stdout } = await execFileAsync(
    "python3",
    [resolve(repoRoot, "scripts/marketing/upload_buffer_slides.py"), episodePath(slug), "--validate-only"],
    { cwd: repoRoot, timeout: 120_000 },
  );
  return stdout.trim();
}

export async function uploadEpisodeAssets(slug: string): Promise<string[]> {
  const { stdout } = await execFileAsync(
    "python3",
    [resolve(repoRoot, "scripts/marketing/upload_buffer_slides.py"), episodePath(slug)],
    { cwd: repoRoot, timeout: 180_000, maxBuffer: 1024 * 1024 },
  );
  const urls = stdout.split("\n").map((line) => line.trim()).filter((line) => line.startsWith("https://"));
  if (urls.length === 0) throw new Error("The upload helper returned no public media URLs.");
  return urls;
}

interface Ticket {
  request: PublishRequest;
  phrase: string;
  expiresAt: number;
}

export class ConfirmationStore {
  private readonly tickets = new Map<string, Ticket>();

  prepare(request: PublishRequest): { token: string; phrase: string; expiresAt: string } {
    const token = randomUUID();
    const phrase = `PUBLISH ${request.episode} ${token}`;
    const expiresAt = Date.now() + 10 * 60 * 1000;
    this.tickets.set(token, { request, phrase, expiresAt });
    return { token, phrase, expiresAt: new Date(expiresAt).toISOString() };
  }

  consume(token: string, phrase: string): PublishRequest {
    const ticket = this.tickets.get(token);
    if (!ticket) throw new Error("Unknown or already-used confirmation token.");
    if (ticket.expiresAt < Date.now()) {
      this.tickets.delete(token);
      throw new Error("Confirmation token expired; prepare the post again.");
    }
    if (ticket.phrase !== phrase) throw new Error("Confirmation phrase does not match.");
    this.tickets.delete(token);
    return ticket.request;
  }
}

export async function readMarketingContext(route: "general" | "spicy" | "publishing"): Promise<string> {
  const paths = [resolve(repoRoot, "docs/marketing/gtm/GTM.md")];
  if (route === "general") paths.push(resolve(repoRoot, "docs/marketing/gtm/content-strategy.md"));
  if (route === "spicy") paths.push(resolve(repoRoot, "docs/marketing/gtm/spicy-content-bank.md"));
  if (route === "publishing") paths.push(resolve(repoRoot, "docs/marketing/gtm/buffer-publishing.md"));
  const documents = await Promise.all(paths.map(async (path) => `# Source: ${path}\n\n${await readFile(path, "utf8")}`));
  return documents.join("\n\n---\n\n");
}

export async function recordPublication(
  slug: string,
  result: { externalLink: string; sentAt: string; postId: string },
): Promise<void> {
  const path = resolve(episodePath(slug), "README.md");
  const readme = await readFile(path, "utf8");
  if (/^## Published$/m.test(readme)) return;
  const publishedAt = new Intl.DateTimeFormat("sv-SE", {
    timeZone: "Asia/Tokyo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(new Date(result.sentAt));
  await appendFile(path, `\n## Published\n\n- TikTok: ${result.externalLink}\n- Published: ${publishedAt} JST via Buffer\n- Buffer post: \`${result.postId}\`\n`);
}
