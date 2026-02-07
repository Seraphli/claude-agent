const fs = require("fs");
const path = require("path");

const homeDir = require("os").homedir();
const srcDir = path.resolve(__dirname, "..");
const targetCommandsDir = path.join(homeDir, ".claude", "commands", "ca");
const targetAgentsDir = path.join(homeDir, ".claude", "agents");
const targetHooksDir = path.join(homeDir, ".claude", "hooks");
const caConfigDir = path.join(homeDir, ".claude", "ca");
const settingsPath = path.join(homeDir, ".claude", "settings.json");

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

function copyAgents(src, dest) {
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src)) {
    if (entry.startsWith("ca-") && entry.endsWith(".md")) {
      fs.copyFileSync(path.join(src, entry), path.join(dest, entry));
    }
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
copyDir(srcCommandsDir, targetCommandsDir);
const commandCount = fs.readdirSync(targetCommandsDir).filter((f) => f.endsWith(".md")).length;
console.log(`Copied ${commandCount} commands to ${targetCommandsDir}`);

// Copy agents
const srcAgentsDir = path.join(srcDir, "agents");
copyAgents(srcAgentsDir, targetAgentsDir);
const agentFiles = fs.readdirSync(srcAgentsDir).filter((f) => f.startsWith("ca-") && f.endsWith(".md"));
console.log(`Copied ${agentFiles.length} agents to ${targetAgentsDir}`);

// Copy hooks
const srcHooksDir = path.join(srcDir, "hooks");
fs.mkdirSync(targetHooksDir, { recursive: true });
const hookFile = "ca-statusline.js";
fs.copyFileSync(path.join(srcHooksDir, hookFile), path.join(targetHooksDir, hookFile));
console.log(`Copied ${hookFile} to ${targetHooksDir}`);

// Create global config directory
fs.mkdirSync(caConfigDir, { recursive: true });
console.log(`Created ${caConfigDir}`);

// Create rules directory and install rules files
const rulesDir = path.join(homeDir, ".claude", "rules");
fs.mkdirSync(rulesDir, { recursive: true });

// Copy _rules.md as ca-rules.md
const rulesSource = path.join(srcCommandsDir, "_rules.md");
const rulesTarget = path.join(rulesDir, "ca-rules.md");
fs.copyFileSync(rulesSource, rulesTarget);
console.log(`Copied rules to ${rulesTarget}`);

// Generate ca-settings.md from existing config
const globalConfigPath = path.join(caConfigDir, "config.md");
if (fs.existsSync(globalConfigPath)) {
  const configContent = fs.readFileSync(globalConfigPath, "utf8");
  const settingsRules = generateSettingsRules(configContent);
  fs.writeFileSync(path.join(rulesDir, "ca-settings.md"), settingsRules);
  console.log("Generated ca-settings.md from existing config");
}

// Migrate old context.md to rules if exists
const oldGlobalContext = path.join(caConfigDir, "context.md");
const newGlobalContext = path.join(rulesDir, "ca-context.md");
if (fs.existsSync(oldGlobalContext) && !fs.existsSync(newGlobalContext)) {
  fs.copyFileSync(oldGlobalContext, newGlobalContext);
  console.log("Migrated global context.md to rules/ca-context.md");
}

// Migrate old errors.md to rules if exists
const oldGlobalErrors = path.join(caConfigDir, "errors.md");
const newGlobalErrors = path.join(rulesDir, "ca-errors.md");
if (fs.existsSync(oldGlobalErrors) && !fs.existsSync(newGlobalErrors)) {
  fs.copyFileSync(oldGlobalErrors, newGlobalErrors);
  console.log("Migrated global errors.md to rules/ca-errors.md");
}

// Write version file
const pkg = JSON.parse(fs.readFileSync(path.join(srcDir, "package.json"), "utf8"));
fs.writeFileSync(path.join(caConfigDir, "version"), pkg.version);
console.log(`Wrote version ${pkg.version} to ${path.join(caConfigDir, "version")}`);

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
console.log("Registered statusline in settings.json");
console.log(`Added ${readPermissions.length} Read permissions to settings.json`);

console.log("\nCA installed successfully!");
console.log("\nAvailable commands:");
console.log("  /ca:help      - Show command reference");
console.log("  /ca:settings  - Configure language settings");
console.log("  /ca:new       - Start a new requirement");
console.log("  /ca:discuss   - Discuss requirements");
console.log("  /ca:research  - Analyze codebase");
console.log("  /ca:plan      - Propose implementation plan");
console.log("  /ca:execute   - Execute confirmed plan");
console.log("  /ca:verify    - Verify and commit");
console.log("  /ca:next      - Execute next workflow step");
console.log("  /ca:status    - Show workflow status");
console.log("  /ca:fix       - Roll back to a step");
console.log("  /ca:remember  - Save to persistent context");
console.log("  /ca:context   - Show current context");
console.log("  /ca:forget    - Remove from context");
console.log("  /ca:map       - Scan project structure");
console.log("  /ca:todo      - Add a todo item");
console.log("  /ca:todos     - List all todos");
