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

function formatOutput(cfg) {
  const lines = [];
  lines.push("# CA Configuration");
  lines.push("");
  lines.push("## Language");
  lines.push(`interaction_language: ${cfg.interaction_language}`);
  lines.push(`  → Communicate with the user in ${cfg.interaction_language}. All markdown headings, AskUserQuestion headers/questions/options, and table headers in user-facing output MUST use this language.`);
  lines.push(`  Exception: Headings inside file templates (PLAN.md, CRITERIA.md, SUMMARY.md, etc.) MUST remain in English as structural keys for cross-command parsing.`);
  lines.push(`comment_language: ${cfg.comment_language}`);
  lines.push(`  → Write all code comments in ${cfg.comment_language}.`);
  lines.push(`code_language: ${cfg.code_language}`);
  lines.push(`  → Write code strings (logs, error messages) in ${cfg.code_language}.`);
  lines.push("");
  lines.push("## Models");
  lines.push(`model_profile: ${cfg.model_profile}`);
  lines.push(`ca-executor_model: ${cfg["ca-executor_model"]}`);
  lines.push(`ca-researcher_model: ${cfg["ca-researcher_model"]}`);
  lines.push(`ca-verifier_model: ${cfg["ca-verifier_model"]}`);
  lines.push(`  → When launching agents, pass the resolved model name above to each agent.`);
  lines.push("");
  lines.push("## Workflow");
  lines.push(`auto_proceed_to_plan: ${cfg.auto_proceed_to_plan}`);
  if (cfg.auto_proceed_to_plan) {
    lines.push(`  → After discuss/quick completes, automatically proceed to plan without asking the user.`);
  } else {
    lines.push(`  → After discuss/quick completes, suggest /ca:plan but do NOT auto-proceed.`);
  }
  lines.push(`auto_proceed_to_verify: ${cfg.auto_proceed_to_verify}`);
  if (cfg.auto_proceed_to_verify) {
    lines.push(`  → After execute completes, automatically proceed to verify without asking the user.`);
  } else {
    lines.push(`  → After execute completes, suggest /ca:verify but do NOT auto-proceed.`);
  }
  lines.push(`max_concurrency: ${cfg.max_concurrency}`);
  lines.push(`  → Maximum number of parallel agents. If more agents needed, split into batches of ${cfg.max_concurrency}.`);
  lines.push(`auto_fix: ${cfg.auto_fix}`);
  if (cfg.auto_fix) {
    lines.push(`  → When verify fails with implementation bugs, automatically trigger plan→execute→verify fix loop.`);
  } else {
    lines.push(`  → When verify fails, suggest /ca:plan for manual fix. Do NOT auto-trigger fix loop.`);
  }
  lines.push(`max_fix_rounds: ${cfg.max_fix_rounds}`);
  lines.push(`  → Maximum number of auto-fix rounds before requiring manual intervention.`);
  lines.push("");
  lines.push("## Git");
  lines.push(`use_branches: ${cfg.use_branches}`);
  if (cfg.use_branches) {
    lines.push(`  → Create a dedicated git branch (ca/<workflow-id>) for each workflow. Commit after execution, squash-merge on finish.`);
  } else {
    lines.push(`  → Do NOT create git branches for workflows. Work on the current branch.`);
  }
  lines.push(`merge_strategy: ${cfg.merge_strategy}`);
  lines.push(`  → Use ${cfg.merge_strategy} merge when finishing a workflow.`);
  lines.push(`auto_delete_branch: ${cfg.auto_delete_branch}`);
  if (cfg.auto_delete_branch) {
    lines.push(`  → Automatically delete the workflow branch after merge.`);
  } else {
    lines.push(`  → Keep the workflow branch after merge.`);
  }
  lines.push("");
  lines.push("## Display");
  lines.push(`show_tg_commands: ${cfg.show_tg_commands}`);
  if (cfg.show_tg_commands) {
    lines.push(`  → When suggesting next commands, show BOTH colon and underscore formats.`);
    lines.push(`  Example: "/ca:plan (/ca_plan) or /ca:next (/ca_next)"`);
    lines.push(`  Note: Built-in commands like /clear are excluded — never show underscore format for those.`);
  } else {
    lines.push(`  → When suggesting next commands, show only the colon format.`);
    lines.push(`  Example: "/ca:plan or /ca:next"`);
  }
  lines.push("");
  lines.push("## Other");
  lines.push(`track_ca_files: ${cfg.track_ca_files}`);
  if (cfg.track_ca_files === "none") {
    lines.push(`  → CA files (.ca/) are NOT version controlled. On finish, check .gitignore includes .ca/.`);
  } else {
    lines.push(`  → CA files (.ca/) are version controlled (${cfg.track_ca_files}).`);
  }
  return lines.join("\n") + "\n";
}

process.stdout.write(formatOutput(resolved));
