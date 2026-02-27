const fs = require("fs");
const path = require("path");
const os = require("os");

// Parse key: value lines from a STATUS.md file with proper type coercion
function parseStatus(filePath) {
  if (!fs.existsSync(filePath)) return null;
  const lines = fs.readFileSync(filePath, "utf8").split("\n");
  const result = {};
  for (const line of lines) {
    if (line.startsWith("#")) continue;
    const match = line.match(/^(\w[\w-]*\w?):\s*(.+)$/);
    if (!match) continue;
    const [, key, rawValue] = match;
    const value = rawValue.trim();
    if (value === "true") result[key] = true;
    else if (value === "false") result[key] = false;
    else if (/^\d+$/.test(value)) result[key] = Number(value);
    else result[key] = value;
  }
  return result;
}

// Get first content line from BRIEF.md (after the heading)
function getBriefFirstLine(briefPath) {
  if (!fs.existsSync(briefPath)) return "";
  const lines = fs.readFileSync(briefPath, "utf8").split("\n");
  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed && !trimmed.startsWith("#")) return trimmed;
  }
  return "";
}

// Update specific fields in a STATUS.md file and return updated object
function updateStatus(filePath, updates) {
  if (!fs.existsSync(filePath)) {
    process.stderr.write(JSON.stringify({ error: `STATUS.md not found: ${filePath}` }) + "\n");
    process.exit(1);
  }
  const lines = fs.readFileSync(filePath, "utf8").split("\n");
  const updatedKeys = new Set();
  const newLines = lines.map((line) => {
    const match = line.match(/^(\w[\w-]*\w?):\s*(.+)$/);
    if (!match) return line;
    const [, key] = match;
    if (key in updates) {
      updatedKeys.add(key);
      return `${key}: ${updates[key]}`;
    }
    return line;
  });
  // Append any keys not found in existing file
  for (const key of Object.keys(updates)) {
    if (!updatedKeys.has(key)) {
      newLines.push(`${key}: ${updates[key]}`);
    }
  }
  fs.writeFileSync(filePath, newLines.join("\n"));
  return parseStatus(filePath);
}

const args = process.argv.slice(2);
const subcommand = args[0];

const projectRootIdx = args.indexOf("--project-root");
const projectRoot = projectRootIdx !== -1 ? args[projectRootIdx + 1] : process.cwd();

const workflowIdIdx = args.indexOf("--workflow-id");

const homeDir = os.homedir();
const caDir = path.join(projectRoot, ".ca");
const activeFile = path.join(caDir, "active.md");

function getActiveWorkflowId() {
  if (!fs.existsSync(activeFile)) return null;
  return fs.readFileSync(activeFile, "utf8").trim();
}

function getWorkflowId() {
  if (workflowIdIdx !== -1) return args[workflowIdIdx + 1];
  return getActiveWorkflowId();
}

function getStatusPath(workflowId) {
  return path.join(caDir, "workflows", workflowId, "STATUS.md");
}

if (subcommand === "active") {
  const workflowId = getActiveWorkflowId();
  process.stdout.write(JSON.stringify({ workflow_id: workflowId }) + "\n");
} else if (subcommand === "read") {
  const workflowId = getWorkflowId();
  if (!workflowId) {
    process.stderr.write(JSON.stringify({ error: "No active workflow. Run /ca:new first." }) + "\n");
    process.exit(1);
  }
  const statusPath = getStatusPath(workflowId);
  const status = parseStatus(statusPath);
  if (!status) {
    process.stderr.write(JSON.stringify({ error: `STATUS.md not found for workflow: ${workflowId}` }) + "\n");
    process.exit(1);
  }
  process.stdout.write(JSON.stringify(status, null, 2) + "\n");
} else if (subcommand === "update") {
  const workflowId = getWorkflowId();
  if (!workflowId) {
    process.stderr.write(JSON.stringify({ error: "No active workflow. Run /ca:new first." }) + "\n");
    process.exit(1);
  }
  const statusPath = getStatusPath(workflowId);
  // Parse key=value pairs from remaining args
  const updates = {};
  for (const arg of args.slice(1)) {
    if (arg.startsWith("--")) continue;
    // Skip the argument following --project-root or --workflow-id
    const eqIdx = arg.indexOf("=");
    if (eqIdx === -1) continue;
    const key = arg.slice(0, eqIdx);
    const rawValue = arg.slice(eqIdx + 1);
    if (rawValue === "true") updates[key] = true;
    else if (rawValue === "false") updates[key] = false;
    else if (/^\d+$/.test(rawValue)) updates[key] = Number(rawValue);
    else updates[key] = rawValue;
  }
  const updated = updateStatus(statusPath, updates);
  process.stdout.write(JSON.stringify(updated, null, 2) + "\n");
} else if (subcommand === "list") {
  const workflowsDir = path.join(caDir, "workflows");
  if (!fs.existsSync(workflowsDir)) {
    process.stdout.write(JSON.stringify([]) + "\n");
    process.exit(0);
  }
  const activeId = getActiveWorkflowId();
  const entries = [];
  for (const entry of fs.readdirSync(workflowsDir)) {
    const entryPath = path.join(workflowsDir, entry);
    if (!fs.statSync(entryPath).isDirectory()) continue;
    const statusPath = path.join(entryPath, "STATUS.md");
    const briefPath = path.join(entryPath, "BRIEF.md");
    const status = parseStatus(statusPath);
    if (!status) continue;
    const brief = getBriefFirstLine(briefPath);
    entries.push({
      workflow_id: entry,
      workflow_type: status.workflow_type || "",
      current_step: status.current_step || "",
      brief,
      active: entry === activeId,
    });
  }
  process.stdout.write(JSON.stringify(entries, null, 2) + "\n");
} else {
  process.stderr.write(JSON.stringify({ error: `Unknown subcommand: ${subcommand}` }) + "\n");
  process.exit(1);
}
