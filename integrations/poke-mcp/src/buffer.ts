import type { PublishRequest } from "./core.js";

interface GraphQLResponse<T> {
  data?: T;
  errors?: Array<{ message: string }>;
}

export interface BufferPost {
  id: string;
  status: string;
  sentAt: string | null;
  externalLink: string | null;
}

export class BufferClient {
  constructor(
    private readonly apiKey: string,
    private readonly organizationName = "My Organization",
    private readonly channelName = "keigobutton",
  ) {}

  private async request<T>(query: string, variables: Record<string, unknown> = {}): Promise<T> {
    const response = await fetch("https://api.buffer.com", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${this.apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ query, variables }),
    });
    if (!response.ok) throw new Error(`Buffer API returned HTTP ${response.status}.`);
    const payload = await response.json() as GraphQLResponse<T>;
    if (payload.errors?.length) throw new Error(payload.errors.map((error) => error.message).join("; "));
    if (!payload.data) throw new Error("Buffer API returned no data.");
    return payload.data;
  }

  async getTikTokChannel(): Promise<{ organizationId: string; channelId: string }> {
    const account = await this.request<{
      account: { organizations: Array<{ id: string; name: string }> };
    }>(`query GetOrganizations { account { organizations { id name } } }`);
    const organization = account.account.organizations.find((item) => item.name === this.organizationName);
    if (!organization) throw new Error(`Buffer organization not found: ${this.organizationName}`);

    const data = await this.request<{
      channels: Array<{ id: string; name: string; displayName: string | null; service: string; isDisconnected: boolean; isLocked: boolean }>;
    }>(
      `query GetChannels($input: ChannelsInput!) {
        channels(input: $input) { id name displayName service isDisconnected isLocked }
      }`,
      { input: { organizationId: organization.id, filter: { isLocked: false } } },
    );
    const channel = data.channels.find((item) =>
      item.service.toLowerCase() === "tiktok"
      && (item.name === this.channelName || item.displayName === this.channelName)
      && !item.isDisconnected
    );
    if (!channel) throw new Error(`Connected TikTok channel not found: ${this.channelName}`);
    return { organizationId: organization.id, channelId: channel.id };
  }

  async createTikTokPhotoPost(request: PublishRequest, urls: string[], channelId: string): Promise<BufferPost> {
    const input: Record<string, unknown> = {
      text: request.caption,
      channelId,
      schedulingType: "automatic",
      mode: request.mode,
      assets: urls.map((url) => ({ image: { url } })),
      metadata: { tiktok: { title: request.title } },
      aiAssisted: true,
    };
    if (request.dueAt) input.dueAt = request.dueAt;

    const data = await this.request<{
      createPost: { __typename: string; post?: BufferPost; message?: string };
    }>(
      `mutation CreatePost($input: CreatePostInput!) {
        createPost(input: $input) {
          __typename
          ... on PostActionSuccess { post { id status sentAt externalLink } }
          ... on MutationError { message }
        }
      }`,
      { input },
    );
    if (data.createPost.__typename !== "PostActionSuccess" || !data.createPost.post) {
      throw new Error(data.createPost.message ?? `Buffer createPost failed: ${data.createPost.__typename}`);
    }
    return data.createPost.post;
  }

  async getPost(id: string): Promise<BufferPost> {
    const data = await this.request<{ post: BufferPost }>(
      `query GetPost($input: PostInput!) { post(input: $input) { id status sentAt externalLink } }`,
      { input: { id } },
    );
    return data.post;
  }

  async waitForTerminal(post: BufferPost, seconds = 45): Promise<BufferPost> {
    const deadline = Date.now() + seconds * 1000;
    let current = post;
    while (!isTerminal(current.status) && Date.now() < deadline) {
      await new Promise((resolve) => setTimeout(resolve, 5_000));
      current = await this.getPost(current.id);
    }
    return current;
  }
}

export function isTerminal(status: string): boolean {
  return status === "sent" || status === "error";
}

