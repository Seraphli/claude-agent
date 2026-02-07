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
  "Read(.dev/*)",
  "Read(.dev/**/*)",
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
