const fs = require("fs");
const path = require("path");

const homeDir = require("os").homedir();
const srcDir = path.resolve(__dirname, "..");
const targetCommandsDir = path.join(homeDir, ".claude", "commands", "ca");
const targetAgentsDir = path.join(homeDir, ".claude", "agents");

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

console.log("\nCA installed successfully!");
console.log("\nAvailable commands:");
console.log("  /ca:help      - Show command reference");
console.log("  /ca:init      - Initialize workspace");
console.log("  /ca:discuss   - Discuss requirements");
console.log("  /ca:research  - Analyze codebase");
console.log("  /ca:plan      - Propose implementation plan");
console.log("  /ca:execute   - Execute confirmed plan");
console.log("  /ca:verify    - Verify and commit");
console.log("  /ca:status    - Show workflow status");
console.log("  /ca:fix       - Roll back to a step");
console.log("  /ca:remember  - Save to persistent context");
console.log("  /ca:context   - Show current context");
console.log("  /ca:forget    - Remove from context");
console.log("  /ca:todo      - Add a todo item");
console.log("  /ca:todos     - List all todos");
