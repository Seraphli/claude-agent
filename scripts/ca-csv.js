const fs = require("fs");
const path = require("path");

const TASKS_HEADER = ["id", "phase", "title", "description", "verify_refs", "dev", "git", "notes"];
const VERIFY_HEADER = ["id", "type", "method", "criterion", "result", "last_verified_round", "notes"];
const ENUMS = {
  dev: ["pending", "done"],
  git: ["pending", "done", "skipped"],
  type: ["self_check", "test"],
  method: ["auto", "manual"],
  result: ["pass", "fail", "pending"],
};

// --- RFC4180 CSV parse/serialize ---
function parseCsv(text) {
  const rows = [];
  let row = [], field = "", i = 0, inQuotes = false;
  while (i < text.length) {
    const c = text[i];
    if (inQuotes) {
      if (c === '"') {
        if (text[i + 1] === '"') { field += '"'; i += 2; continue; }
        inQuotes = false; i++; continue;
      }
      field += c; i++; continue;
    }
    if (c === '"') { inQuotes = true; i++; continue; }
    if (c === ",") { row.push(field); field = ""; i++; continue; }
    if (c === "\r") { i++; continue; }
    if (c === "\n") { row.push(field); rows.push(row); row = []; field = ""; i++; continue; }
    field += c; i++;
  }
  if (field !== "" || row.length > 0) { row.push(field); rows.push(row); }
  return rows;
}

function serializeField(v) {
  const s = String(v == null ? "" : v);
  return /[",\n\r]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
}

function serializeCsv(rows) {
  return rows.map((r) => r.map(serializeField).join(",")).join("\n") + "\n";
}

function readTable(file) {
  if (!fs.existsSync(file)) return { header: [], rows: [] };
  const all = parseCsv(fs.readFileSync(file, "utf8")).filter((r) => r.length && !(r.length === 1 && r[0] === ""));
  if (!all.length) return { header: [], rows: [] };
  const header = all[0];
  const rows = all.slice(1).map((cells) => {
    const obj = {};
    header.forEach((h, i) => { obj[h] = cells[i] == null ? "" : cells[i]; });
    return obj;
  });
  return { header, rows };
}

function writeTable(file, header, rows) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, serializeCsv([header, ...rows.map((o) => header.map((h) => o[h] == null ? "" : o[h]))]));
}

function die(msg) { process.stderr.write(`Error: ${msg}\n`); process.exit(1); }

function getArg(args, name) {
  const i = args.indexOf(name);
  return i !== -1 ? args[i + 1] : undefined;
}

function checkEnum(field, value) {
  if (ENUMS[field] && !ENUMS[field].includes(value)) {
    die(`invalid value '${value}' for '${field}' (allowed: ${ENUMS[field].join(", ")})`);
  }
}

const args = process.argv.slice(2);
const sub = args[0];
const file = getArg(args, "--file");
if (!sub) die("no subcommand");
if (!file && sub !== "help") die("--file required");

if (sub === "init-tasks") {
  writeTable(file, TASKS_HEADER, []);
  process.stdout.write(`Initialized TASKS.csv: ${file}\n`);
} else if (sub === "init-verify") {
  writeTable(file, VERIFY_HEADER, []);
  process.stdout.write(`Initialized VERIFY.csv: ${file}\n`);
} else if (sub === "add-task") {
  const { header, rows } = readTable(file);
  if (!header.length) die("TASKS.csv not initialized; run init-tasks first");
  const verifyRefs = getArg(args, "--verify-refs") || "";
  const verifyFile = getArg(args, "--verify-file");
  if (verifyRefs && verifyFile) {
    const ids = new Set(readTable(verifyFile).rows.map((r) => r.id));
    for (const ref of verifyRefs.split(/\s+/).filter(Boolean)) {
      if (!ids.has(ref)) die(`verify_refs '${ref}' does not exist in ${verifyFile}`);
    }
  }
  const nextId = rows.reduce((m, r) => Math.max(m, parseInt(r.id, 10) || 0), 0) + 1;
  rows.push({
    id: String(nextId), phase: getArg(args, "--phase") || "1",
    title: getArg(args, "--title") || "", description: getArg(args, "--description") || "",
    verify_refs: verifyRefs, dev: "pending", git: "pending", notes: getArg(args, "--notes") || "",
  });
  writeTable(file, header, rows);
  process.stdout.write(`Added task ${nextId}\n`);
} else if (sub === "add-criterion") {
  const { header, rows } = readTable(file);
  if (!header.length) die("VERIFY.csv not initialized; run init-verify first");
  const type = getArg(args, "--type"); checkEnum("type", type);
  const method = getArg(args, "--method"); checkEnum("method", method);
  // append-only stable ids: v<max numeric suffix + 1>, never reused
  const maxN = rows.reduce((m, r) => Math.max(m, parseInt(String(r.id).replace(/^v/, ""), 10) || 0), 0);
  const id = "v" + (maxN + 1);
  rows.push({
    id, type, method, criterion: getArg(args, "--criterion") || "",
    result: "pending", last_verified_round: "", notes: getArg(args, "--notes") || "",
  });
  writeTable(file, header, rows);
  process.stdout.write(`Added criterion ${id}\n`);
} else if (sub === "update") {
  const { header, rows } = readTable(file);
  const idArg = getArg(args, "--id");
  const field = getArg(args, "--field");
  const value = getArg(args, "--value");
  if (field === "id") die("the 'id' column is append-only and cannot be changed");
  if (!header.includes(field)) die(`unknown field '${field}' (columns: ${header.join(", ")})`);
  checkEnum(field, value);
  // --id accepts a single id or a comma-separated list; every listed id must exist.
  const ids = (idArg || "").split(",").map((s) => s.trim()).filter(Boolean);
  if (!ids.length) die("--id required (one id, or comma-separated list e.g. 1,2,3)");
  const targets = ids.map((id) => {
    const row = rows.find((r) => r.id === id);
    if (!row) die(`row with id '${id}' not found`);
    return row;
  });
  targets.forEach((row) => { row[field] = value; });
  writeTable(file, header, rows);
  process.stdout.write(`Updated ${ids.join(",")}.${field}=${value}\n`);
} else if (sub === "get") {
  const { header, rows } = readTable(file);
  const id = getArg(args, "--id");
  const out = id ? rows.filter((r) => r.id === id) : rows;
  if (args.includes("--json")) process.stdout.write(JSON.stringify(out, null, 2) + "\n");
  else { process.stdout.write(header.join(",") + "\n"); out.forEach((r) => process.stdout.write(header.map((h) => r[h]).join(" | ") + "\n")); }
} else {
  die(`unknown subcommand: ${sub}`);
}
