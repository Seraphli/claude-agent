const readline = require("readline");
const path = require("path");

const rl = readline.createInterface({ input: process.stdin });
let input = "";

rl.on("line", (line) => {
  input += line;
});

rl.on("close", () => {
  try {
    const data = JSON.parse(input);
    const model = data.model?.display_name || "Claude";
    const dir = data.workspace?.current_dir || process.cwd();
    const remaining = data.context_window?.remaining_percentage;

    let ctx = "";
    if (remaining != null) {
      const rem = Math.round(remaining);
      const rawUsed = Math.max(0, Math.min(100, 100 - rem));
      // Scale: 80% real usage = 100% displayed (Claude Code enforces 80% limit)
      const used = Math.min(100, Math.round((rawUsed / 80) * 100));
      const filled = Math.floor(used / 10);
      const bar = "\u2588".repeat(filled) + "\u2591".repeat(10 - filled);

      if (used < 63) {
        ctx = ` \x1b[32m${bar} ${used}%\x1b[0m`;
      } else if (used < 81) {
        ctx = ` \x1b[33m${bar} ${used}%\x1b[0m`;
      } else if (used < 95) {
        ctx = ` \x1b[38;5;208m${bar} ${used}%\x1b[0m`;
      } else {
        ctx = ` \x1b[5;31m${bar} ${used}%\x1b[0m`;
      }
    }

    const dirname = path.basename(dir);
    process.stdout.write(`\x1b[2m${model}\x1b[0m \u2502 \x1b[2m${dirname}\x1b[0m${ctx}`);
  } catch {
    // Silent fail
  }
});
