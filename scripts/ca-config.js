const fs = require("fs");
const path = require("path");
const os = require("os");

// Parse key: value lines from a markdown config file
function parseConfigFile(filePath) {
  if (!fs.existsSync(filePath)) return {};
  const lines = fs.readFileSync(filePath, "utf8").split("\n");
  const result = {};
  for (const line of lines) {
    // Skip comment and heading lines
    if (line.startsWith("#") || line.startsWith("//")) continue;
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

const args = process.argv.slice(2);
const projectRootIdx = args.indexOf("--project-root");
const projectRoot = projectRootIdx !== -1 ? args[projectRootIdx + 1] : process.cwd();

const claudeDir = process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), ".claude");
const workspaceConfig = path.join(projectRoot, ".ca", "config.md");
const globalConfig = path.join(claudeDir, "ca", "config.md");
const defaultsConfig = path.join(claudeDir, "ca", "references", "config-defaults.md");

const defaults = parseConfigFile(defaultsConfig);
const global_ = parseConfigFile(globalConfig);
const workspace = parseConfigFile(workspaceConfig);

// Workspace > global > defaults priority
const resolved = Object.assign({}, defaults, global_, workspace);

// Model resolution: embed profile table, resolve per-agent model names
const PROFILES = {
  quality: { "ca-executor": "opus", "ca-researcher": "opus", "ca-verifier": "sonnet" },
  balanced: { "ca-executor": "sonnet", "ca-researcher": "sonnet", "ca-verifier": "sonnet" },
  budget: { "ca-executor": "sonnet", "ca-researcher": "haiku", "ca-verifier": "haiku" },
};
const profile = PROFILES[resolved.model_profile] || PROFILES.balanced;
for (const agent of ["ca-executor", "ca-researcher", "ca-verifier"]) {
  const key = `${agent}_model`;
  if (!resolved[key]) {
    resolved[key] = profile[agent];
  }
}

process.stdout.write(JSON.stringify(resolved, null, 2) + "\n");
