"use strict";

import Bitstring from "../bitstring.mjs";
import Type from "../type.mjs";

// shortcut: the browser has no PubSub; subscribe/3 only records the topic (ignoring the pubsub name)
// for the page to forward to the server, which bridges it. No unsubscribe, no per-pubsub scoping.
// Upgrade: port unsubscribe/2 and key topics by pubsub name when a second PubSub matters.
const Elixir_Phoenix_PubSub = {
  "subscribe/3": (_pubsub, topic, _opts) => {
    (globalThis.__lvTopics ??= new Set()).add(Bitstring.toText(topic));
    return Type.atom("ok");
  },
};

export default Elixir_Phoenix_PubSub;
