const fs = require("fs");
const path = require("path");

const homeDir = require("os").homedir();
const targetCommandsDir = path.join(homeDir, ".claude", "commands", "ca");
const targetAgentsDir = path.join(homeDir, ".claude", "agents");
const targetHooksDir = path.join(homeDir, ".claude", "hooks");
const settingsPath = path.join(homeDir, ".claude", "settings.json");

// Remove commands directory
if (fs.existsSync(targetCommandsDir)) {
  fs.rmSync(targetCommandsDir, { recursive: true });
  console.log(`Removed ${targetCommandsDir}`);
} else {
  console.log("Commands directory not found, skipping.");
}

// Remove agent files
if (fs.existsSync(targetAgentsDir)) {
  let removed = 0;
  for (const entry of fs.readdirSync(targetAgentsDir)) {
    if (entry.startsWith("ca-") && entry.endsWith(".md")) {
      fs.unlinkSync(path.join(targetAgentsDir, entry));
      removed++;
    }
  }
  console.log(`Removed ${removed} agent files from ${targetAgentsDir}`);
} else {
  console.log("Agents directory not found, skipping.");
}

// Remove hook file
const hookFile = path.join(targetHooksDir, "ca-statusline.js");
if (fs.existsSync(hookFile)) {
  fs.unlinkSync(hookFile);
  console.log(`Removed ${hookFile}`);
} else {
  console.log("Hook file not found, skipping.");
}

// Deregister statusline from settings.json
if (fs.existsSync(settingsPath)) {
  const settings = JSON.parse(fs.readFileSync(settingsPath, "utf8"));
  if (settings.statusLine?.command?.includes("ca-statusline")) {
    delete settings.statusLine;
    fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + "\n");
    console.log("Removed statusline from settings.json");
  }
}

console.log("\nCA uninstalled successfully!");
console.log("Note: .ca/ directories and ~/.claude/ca/ config are preserved.");
