import { spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import { repoRoot } from "./core.js";

export type DraftKind = "concept" | "caption" | "carousel" | "video-script";
type JobStatus = "running" | "completed" | "failed";

interface Job {
  id: string;
  status: JobStatus;
  startedAt: string;
  finishedAt?: string;
  output: string;
  error?: string;
}

export class MarketingJobStore {
  private readonly jobs = new Map<string, Job>();

  start(brief: string, kind: DraftKind): Job {
    if ([...this.jobs.values()].some((job) => job.status === "running")) {
      throw new Error("A marketing draft job is already running.");
    }
    const job: Job = {
      id: randomUUID(),
      status: "running",
      startedAt: new Date().toISOString(),
      output: "",
    };
    this.jobs.set(job.id, job);
    this.run(job, brief, kind);
    return { ...job };
  }

  get(id: string): Job {
    const job = this.jobs.get(id);
    if (!job) throw new Error("Unknown marketing job ID.");
    return { ...job };
  }

  private run(job: Job, brief: string, kind: DraftKind): void {
    const prompt = [
      "You are running from the authenticated local Poke MCP bridge for the 敬語ボタン repository.",
      "Read AGENTS.md first and follow the GTM router and buffer-publish-content skill when applicable.",
      `Create a ${kind} marketing DRAFT for this request: ${brief}`,
      "This is draft/preview work only. Do not upload, schedule, publish, call Buffer, or mutate any external service.",
      "You may create a local draft artifact when useful. Never read or print secrets. Return a concise final answer with any artifact paths.",
    ].join("\n\n");
    const child = spawn("codex", [
      "exec",
      "--ephemeral",
      "--sandbox", "workspace-write",
      "--color", "never",
      "-C", repoRoot,
      prompt,
    ], { cwd: repoRoot, stdio: ["ignore", "pipe", "pipe"] });

    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk) => { stdout += String(chunk); });
    child.stderr.on("data", (chunk) => { stderr += String(chunk); });
    child.on("error", (error) => {
      job.status = "failed";
      job.error = error.message;
      job.finishedAt = new Date().toISOString();
    });
    child.on("close", (code) => {
      if (job.status === "failed") return;
      job.output = stdout.trim();
      job.finishedAt = new Date().toISOString();
      if (code === 0) {
        job.status = "completed";
      } else {
        job.status = "failed";
        job.error = stderr.trim() || `codex exited with status ${code}`;
      }
    });
  }
}

