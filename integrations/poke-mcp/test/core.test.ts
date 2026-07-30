import assert from "node:assert/strict";
import test from "node:test";
import { ConfirmationStore, inspectEpisode, validatePublishRequest } from "../src/core.js";

test("published episodes are not ready to republish", async () => {
  const episode = await inspectEpisode("014-sick-day-pressure");
  assert.equal(episode.published, true);
  assert.equal(episode.ready, false);
  assert.match(episode.reasons.join(" "), /already published/);
});

test("publishing requires the fiction disclosure", () => {
  assert.throws(() => validatePublishRequest({
    episode: "014-sick-day-pressure",
    caption: "caption #one",
    title: "title",
    mode: "shareNow",
  }), /フィクション/);
});

test("publishing allows no more than five hashtags", () => {
  assert.throws(() => validatePublishRequest({
    episode: "014-sick-day-pressure",
    caption: "※このチャットはフィクションです。 #1 #2 #3 #4 #5 #6",
    title: "title",
    mode: "shareNow",
  }), /allows 5/);
});

test("confirmation tickets are single-use and require the exact phrase", () => {
  const store = new ConfirmationStore();
  const request = {
    episode: "015-example",
    caption: "※このチャットはフィクションです。",
    title: "title",
    mode: "shareNow" as const,
  };
  const ticket = store.prepare(request);
  assert.throws(() => store.consume(ticket.token, "PUBLISH"), /does not match/);
  assert.deepEqual(store.consume(ticket.token, ticket.phrase), request);
  assert.throws(() => store.consume(ticket.token, ticket.phrase), /already-used/);
});

