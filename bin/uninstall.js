const fs = require("fs");
const path = require("path");

const homeDir = require("os").homedir();
const targetSkillsDir = path.join(homeDir, ".claude", "skills");
const targetAgentsDir = path.join(homeDir, ".claude", "agents");
const targetHooksDir = path.join(homeDir, ".claude", "hooks");
const settingsPath = path.join(homeDir, ".claude", "settings.json");

// Remove skill directories
if (fs.existsSync(targetSkillsDir)) {
  let removed = 0;
  for (const entry of fs.readdirSync(targetSkillsDir)) {
    if (entry.startsWith("ca-")) {
      fs.rmSync(path.join(targetSkillsDir, entry), { recursive: true });
      removed++;
    }
  }
  console.log(`Removed ${removed} skill directories from ${targetSkillsDir}`);
} else {
  console.log("Skills directory not found, skipping.");
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

// Remove references directory
const caConfigDir = path.join(homeDir, ".claude", "ca");
const referencesDir = path.join(caConfigDir, "references");
if (fs.existsSync(referencesDir)) {
  fs.rmSync(referencesDir, { recursive: true });
  console.log(`Removed ${referencesDir}`);
} else {
  console.log("References directory not found, skipping.");
}

// Remove scripts directory
const scriptsDir = path.join(caConfigDir, "scripts");
if (fs.existsSync(scriptsDir)) {
  fs.rmSync(scriptsDir, { recursive: true });
  console.log(`Removed ${scriptsDir}`);
} else {
  console.log("Scripts directory not found, skipping.");
}

// Deregister statusline from settings.json
if (fs.existsSync(settingsPath)) {
  const settings = JSON.parse(fs.readFileSync(settingsPath, "utf8"));
  if (settings.statusLine?.command?.includes("ca-statusline")) {
    const cmd = settings.statusLine.command;
    const cleaned = cmd
      .replace(/\s*\|\s*node\s+"[^"]*ca-statusline\.js"/, "")
      .replace(/node\s+"[^"]*ca-statusline\.js"\s*\|\s*/, "")
      .replace(/^node\s+"[^"]*ca-statusline\.js"$/, "")
      .trim();
    if (cleaned) {
      settings.statusLine.command = cleaned;
      console.log("Removed CA from statusline pipe");
    } else {
      delete settings.statusLine;
      console.log("Removed statusline from settings.json");
    }
    fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + "\n");
  }
}

// Remove all CA rules files
const rulesDir = path.join(homeDir, ".claude", "rules");
if (fs.existsSync(rulesDir)) {
  let removedRules = 0;
  for (const entry of fs.readdirSync(rulesDir)) {
    if (entry.startsWith("ca-") && entry.endsWith(".md")) {
      fs.unlinkSync(path.join(rulesDir, entry));
      removedRules++;
    }
  }
  if (removedRules > 0) {
    console.log(`Removed ${removedRules} CA rules files from ${rulesDir}`);
  }
}

console.log("\nCA uninstalled successfully!");
console.log("Note: .ca/ directories and ~/.claude/ca/ config are preserved. CA rules files have been removed.");
