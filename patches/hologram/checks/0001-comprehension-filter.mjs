// usage: node check.mjs <path-to-assets/js>
const dir = process.argv[2];
globalThis.Elixir_Enum = {"to_list/1": (x) => x, "into/2": (l) => l};
const {default: Interpreter} = await import(dir + "/interpreter.mjs");
const {default: Type} = await import(dir + "/type.mjs");
const {default: Serializer} = await import(dir + "/serializer.mjs").catch(() => ({default: null}));

// for x <- [1, 2], y = x * 2, do: {x, y}
const qualifiers = [
  {type: "generator", guards: [],
   match: Type.variablePattern("x"),
   body: () => Type.list([Type.integer(1), Type.integer(2)])},
  {type: "filter",
   filter: (ctx) => Interpreter.matchOperator(
     Type.integer(ctx.vars.x.value * 2n), Type.variablePattern("y"), ctx)},
];
const mapper = (ctx) => Type.tuple([ctx.vars.x, ctx.vars.y]);
const ctx = Interpreter.buildContext({});
try {
  const r = Interpreter.comprehension(qualifiers, Type.list(), false, mapper, ctx);
  const got = r.data.map((t) => t.data.map((i) => Number(i.value)).join(","));
  const ok = got.join(";") === "1,2;2,4";
  console.log(ok ? "PASS" : "FAIL", got.join(";"));
  process.exit(ok ? 0 : 1);
} catch (e) { console.log("FAIL threw:", e.stack.split("\n").slice(0,4).join(" | ")); process.exit(1); }
