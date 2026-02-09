#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const homeDir = require("os").homedir();
const srcDir = path.resolve(__dirname, "..");
const targetCommandsDir = path.join(homeDir, ".claude", "commands", "ca");
const targetAgentsDir = path.join(homeDir, ".claude", "agents");
const targetHooksDir = path.join(homeDir, ".claude", "hooks");
const caConfigDir = path.join(homeDir, ".claude", "ca");
const settingsPath = path.join(homeDir, ".claude", "settings.json");

const pkg = JSON.parse(fs.readFileSync(path.join(srcDir, "package.json"), "utf8"));

const args = process.argv.slice(2);
const hasUninstall = args.includes('--uninstall') || args.includes('-u');

// Colors
const cyan = '\x1b[36m';
const green = '\x1b[32m';
const dim = '\x1b[2m';
const reset = '\x1b[0m';

const banner = '\n' +
  cyan + '   ██████╗ █████╗\n' +
  '  ██╔════╝██╔══██╗\n' +
  '  ██║     ███████║\n' +
  '  ██║     ██╔══██║\n' +
  '  ╚██████╗██║  ██║\n' +
  '   ╚═════╝╚═╝  ╚═╝' + reset + '\n\n' +
  '  Claude Agent ' + dim + 'v' + pkg.version + reset + '\n';

console.log(banner);

if (hasUninstall) {
  require('./uninstall');
  process.exit(0);
}

function copyDir(src, dest) {
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src)) {
    const srcPath = path.join(src, entry);
    const destPath = path.join(dest, entry);
    if (fs.statSync(srcPath).isDirectory()) {
      copyDir(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

function syncDir(src, dest) {
  if (fs.existsSync(dest)) {
    fs.rmSync(dest, { recursive: true });
  }
  copyDir(src, dest);
}

function syncAgents(src, dest) {
  fs.mkdirSync(dest, { recursive: true });
  const srcFiles = fs.readdirSync(src).filter(f => f.startsWith("ca-") && f.endsWith(".md"));
  const destFiles = fs.readdirSync(dest).filter(f => f.startsWith("ca-") && f.endsWith(".md"));
  for (const f of destFiles) {
    if (!srcFiles.includes(f)) {
      fs.unlinkSync(path.join(dest, f));
    }
  }
  for (const f of srcFiles) {
    fs.copyFileSync(path.join(src, f), path.join(dest, f));
  }
}

function generateSettingsRules(configContent) {
  const lines = configContent.split("\n");
  const rules = ["# CA Settings Rules\n"];
  for (const line of lines) {
    const match = line.match(/^(\w+):\s*(.+)$/);
    if (!match) continue;
    const [, key, value] = match;
    if (key === "interaction_language") {
      rules.push(`- Always communicate in ${value}`);
    } else if (key === "comment_language") {
      rules.push(`- Write all code comments in ${value}`);
    } else if (key === "code_language") {
      rules.push(`- Use ${value} for code strings (logs, error messages, etc.)`);
    }
  }
  return rules.join("\n") + "\n";
}

// Copy commands
const srcCommandsDir = path.join(srcDir, "commands", "ca");
syncDir(srcCommandsDir, targetCommandsDir);
const commandCount = fs.readdirSync(targetCommandsDir).filter((f) => f.endsWith(".md")).length;
console.log(`  ${green}✓${reset} Installed ${commandCount} commands`);

// Copy agents
const srcAgentsDir = path.join(srcDir, "agents");
syncAgents(srcAgentsDir, targetAgentsDir);
const agentFiles = fs.readdirSync(srcAgentsDir).filter((f) => f.startsWith("ca-") && f.endsWith(".md"));
console.log(`  ${green}✓${reset} Installed ${agentFiles.length} agents`);

// Copy hooks
const srcHooksDir = path.join(srcDir, "hooks");
fs.mkdirSync(targetHooksDir, { recursive: true });
const hookFile = "ca-statusline.js";
fs.copyFileSync(path.join(srcHooksDir, hookFile), path.join(targetHooksDir, hookFile));
console.log(`  ${green}✓${reset} Installed statusline hook`);

// Create global config directory
fs.mkdirSync(caConfigDir, { recursive: true });
console.log(`  ${green}✓${reset} Created config directory`);

// Copy references
const srcReferencesDir = path.join(srcDir, "references");
const targetReferencesDir = path.join(caConfigDir, "references");
syncDir(srcReferencesDir, targetReferencesDir);
const refCount = fs.readdirSync(targetReferencesDir).filter((f) => f.endsWith(".md")).length;
console.log(`  ${green}✓${reset} Installed ${refCount} references`);

// Create rules directory and install rules files
const rulesDir = path.join(homeDir, ".claude", "rules");
fs.mkdirSync(rulesDir, { recursive: true });

// Copy rules.md as ca-rules.md
const rulesSource = path.join(srcDir, "memories", "rules.md");
const rulesTarget = path.join(rulesDir, "ca-rules.md");
fs.copyFileSync(rulesSource, rulesTarget);
console.log(`  ${green}✓${reset} Installed rules`);

// Generate ca-settings.md from existing config
const globalConfigPath = path.join(caConfigDir, "config.md");
if (fs.existsSync(globalConfigPath)) {
  const configContent = fs.readFileSync(globalConfigPath, "utf8");
  const settingsRules = generateSettingsRules(configContent);
  fs.writeFileSync(path.join(rulesDir, "ca-settings.md"), settingsRules);
  console.log(`  ${green}✓${reset} Generated settings from config`);
}

// Migrate old context.md to rules if exists
const oldGlobalContext = path.join(caConfigDir, "context.md");
const newGlobalContext = path.join(rulesDir, "ca-context.md");
if (fs.existsSync(oldGlobalContext) && !fs.existsSync(newGlobalContext)) {
  fs.copyFileSync(oldGlobalContext, newGlobalContext);
  console.log(`  ${green}✓${reset} Migrated context to rules`);
}

// Migrate old errors.md to rules if exists
const oldGlobalErrors = path.join(caConfigDir, "errors.md");
const newGlobalErrors = path.join(rulesDir, "ca-errors.md");
if (fs.existsSync(oldGlobalErrors) && !fs.existsSync(newGlobalErrors)) {
  fs.copyFileSync(oldGlobalErrors, newGlobalErrors);
  console.log(`  ${green}✓${reset} Migrated errors to rules`);
}

// Write version file
fs.writeFileSync(path.join(caConfigDir, "version"), pkg.version);
console.log(`  ${green}✓${reset} Wrote version (${pkg.version})`);

// Register statusline in settings.json
let settings = {};
if (fs.existsSync(settingsPath)) {
  settings = JSON.parse(fs.readFileSync(settingsPath, "utf8"));
}
const hookPath = path.join(targetHooksDir, hookFile);
settings.statusLine = { type: "command", command: `node "${hookPath}"` };

// Add Read permissions for CA config files
if (!settings.permissions) settings.permissions = {};
if (!Array.isArray(settings.permissions.allow)) settings.permissions.allow = [];
const readPermissions = [
  "Read(.ca/*)",
  "Read(.ca/**/*)",
  "Read(~/.claude/ca/*)"
];
for (const perm of readPermissions) {
  if (!settings.permissions.allow.includes(perm)) {
    settings.permissions.allow.push(perm);
  }
}

fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + "\n");
console.log(`  ${green}✓${reset} Configured statusline`);
console.log(`  ${green}✓${reset} Added Read permissions`);

console.log(`\n  ${green}Done!${reset} Launch Claude Code and run ${cyan}/ca:help${reset}.\n`);
