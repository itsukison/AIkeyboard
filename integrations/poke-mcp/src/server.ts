import { timingSafeEqual } from "node:crypto";
import { createMcpExpressApp } from "@modelcontextprotocol/express";
import { toNodeHandler } from "@modelcontextprotocol/node";
import { createMcpHandler, McpServer } from "@modelcontextprotocol/server";
import * as z from "zod/v4";
import {
  ConfirmationStore,
  inspectEpisode,
  listEpisodes,
  readMarketingContext,
  recordPublication,
  uploadEpisodeAssets,
  validateEpisodeAssets,
  validatePublishRequest,
} from "./core.js";
import { BufferClient } from "./buffer.js";
import { MarketingJobStore } from "./jobs.js";

const confirmationStore = new ConfirmationStore();
const marketingJobs = new MarketingJobStore();
const authMode = process.env.POKE_AUTH_MODE?.trim() || "api-key";

function requiredEnvironment(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required.`);
  return value;
}

function equalSecrets(actual: string, expected: string): boolean {
  const actualBuffer = Buffer.from(actual);
  const expectedBuffer = Buffer.from(expected);
  return actualBuffer.length === expectedBuffer.length && timingSafeEqual(actualBuffer, expectedBuffer);
}

function createServer(): McpServer {
  const server = new McpServer({ name: "keigobutton-poke", version: "0.1.0" });

  server.registerTool(
    "get_marketing_context",
    {
      description: "Read the live 敬語ボタン GTM guidance before drafting general, spicy, or publishing content.",
      inputSchema: z.object({ route: z.enum(["general", "spicy", "publishing"]) }),
    },
    async ({ route }) => ({ content: [{ type: "text", text: await readMarketingContext(route) }] }),
  );

  server.registerTool(
    "list_tiktok_episodes",
    {
      description: "List local TikTok Photo Mode episodes and explain which are ready for publishing.",
      inputSchema: z.object({}),
    },
    async () => ({ content: [{ type: "text", text: JSON.stringify(await listEpisodes(), null, 2) }] }),
  );

  server.registerTool(
    "start_marketing_draft",
    {
      description: "Start a sandboxed Codex draft-only job. This never uploads, schedules, or publishes content.",
      inputSchema: z.object({
        brief: z.string().min(10).max(4_000),
        kind: z.enum(["concept", "caption", "carousel", "video-script"]),
      }),
    },
    async ({ brief, kind }) => ({ content: [{ type: "text", text: JSON.stringify(marketingJobs.start(brief, kind), null, 2) }] }),
  );

  server.registerTool(
    "get_marketing_job",
    {
      description: "Check a Codex marketing draft job and return its result when complete.",
      inputSchema: z.object({ jobId: z.string().uuid() }),
    },
    async ({ jobId }) => ({ content: [{ type: "text", text: JSON.stringify(marketingJobs.get(jobId), null, 2) }] }),
  );

  server.registerTool(
    "prepare_tiktok_publish",
    {
      description: "Validate an approved local photo episode and create a short-lived confirmation phrase. This does not upload or publish.",
      inputSchema: z.object({
        episode: z.string(),
        caption: z.string().min(1),
        title: z.string().min(1),
        mode: z.enum(["shareNow", "addToQueue", "customScheduled"]),
        dueAt: z.string().optional(),
      }),
    },
    async (request) => {
      validatePublishRequest(request);
      const validation = await validateEpisodeAssets(request.episode);
      const ticket = confirmationStore.prepare(request);
      return {
        content: [{
          type: "text",
          text: JSON.stringify({
            validation,
            episode: await inspectEpisode(request.episode),
            caption: request.caption,
            title: request.title,
            mode: request.mode,
            dueAt: request.dueAt,
            ...ticket,
            instruction: `Show this summary to the user. Call publish_tiktok_episode only if the user explicitly replies with the exact phrase: ${ticket.phrase}`,
          }, null, 2),
        }],
      };
    },
  );

  server.registerTool(
    "publish_tiktok_episode",
    {
      description: "Publish a prepared TikTok episode. Call only after the user explicitly sends the exact confirmation phrase returned by prepare_tiktok_publish.",
      inputSchema: z.object({ token: z.string().uuid(), confirmationPhrase: z.string() }),
    },
    async ({ token, confirmationPhrase }) => {
      const request = confirmationStore.consume(token, confirmationPhrase);
      const urls = await uploadEpisodeAssets(request.episode);
      const buffer = new BufferClient(requiredEnvironment("BUFFER_API_KEY"));
      const { channelId } = await buffer.getTikTokChannel();
      const created = await buffer.createTikTokPhotoPost(request, urls, channelId);
      const post = await buffer.waitForTerminal(created);
      if (post.status === "sent" && post.sentAt && post.externalLink) {
        await recordPublication(request.episode, { postId: post.id, sentAt: post.sentAt, externalLink: post.externalLink });
      }
      return {
        content: [{
          type: "text",
          text: JSON.stringify({
            episode: request.episode,
            post,
            result: post.status === "sent" ? "published" : post.status === "error" ? "failed" : "pending; do not report success yet",
            next: post.status === "sent" || post.status === "error"
              ? null
              : "Call get_tiktok_post_status with this post ID and episode until status is sent or error.",
          }, null, 2),
        }],
      };
    },
  );

  server.registerTool(
    "get_tiktok_post_status",
    {
      description: "Check a Buffer TikTok post. Only status sent counts as successful publication.",
      inputSchema: z.object({ postId: z.string(), episode: z.string() }),
    },
    async ({ postId, episode }) => {
      const buffer = new BufferClient(requiredEnvironment("BUFFER_API_KEY"));
      const post = await buffer.getPost(postId);
      if (post.status === "sent" && post.sentAt && post.externalLink) {
        await recordPublication(episode, { postId: post.id, sentAt: post.sentAt, externalLink: post.externalLink });
      }
      return {
        content: [{
          type: "text",
          text: JSON.stringify({
            post,
            result: post.status === "sent" ? "published" : post.status === "error" ? "failed" : "pending; do not report success yet",
          }, null, 2),
        }],
      };
    },
  );

  return server;
}

const handler = createMcpHandler(createServer);
const app = createMcpExpressApp(authMode === "api-key" ? { host: "0.0.0.0" } : {});

app.get("/health", (_request, response) => {
  response.json({ ok: true, service: "keigobutton-poke-mcp" });
});

app.use((request, response, next) => {
  if (authMode === "api-key") {
    let expected: string;
    try {
      expected = requiredEnvironment("POKE_MCP_API_KEY");
    } catch (error) {
      response.status(503).json({ error: error instanceof Error ? error.message : String(error) });
      return;
    }
    const authorization = request.header("authorization") ?? "";
    const actual = authorization.startsWith("Bearer ") ? authorization.slice(7) : "";
    if (!equalSecrets(actual, expected)) {
      response.status(401).json({ error: "Unauthorized" });
      return;
    }
  } else if (authMode !== "tunnel") {
    response.status(503).json({ error: "POKE_AUTH_MODE must be tunnel or api-key" });
    return;
  }
  const allowedUser = process.env.POKE_ALLOWED_USER_ID?.trim();
  if (allowedUser && request.header("x-poke-user-id") !== allowedUser) {
    response.status(403).json({ error: "Poke user is not allowed" });
    return;
  }
  next();
});

const nodeHandler = toNodeHandler(handler);
app.all("/mcp", (request, response) => void nodeHandler(request, response, request.body));

const port = Number(process.env.PORT ?? "3000");
app.listen(port, "127.0.0.1", () => {
  console.log(`KeigoButton Poke MCP listening on http://127.0.0.1:${port}/mcp`);
});
