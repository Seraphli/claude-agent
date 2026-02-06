const fs = require("fs");
const path = require("path");

const homeDir = require("os").homedir();
const targetCommandsDir = path.join(homeDir, ".claude", "commands", "ca");
const targetAgentsDir = path.join(homeDir, ".claude", "agents");

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

console.log("\nCA uninstalled successfully!");
console.log("Note: .dev/ directories in your projects are preserved.");
