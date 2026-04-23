#!/usr/bin/env node
/**
 * R³ CopilotKit — Install dependencies
 * Run from R3-DASHBOARD root:
 *   node R3_LLM_ENGINE_REGISTRY/copilotkit/install.js
 */

const { execSync } = require("child_process");
const path = require("path");

const CHAT_LEGS = path.resolve(__dirname, "../../SOURCE/chat-legs");
const REGISTRY = path.resolve(__dirname, "..");

const pkgExists = (p) => {
  try {
    require.resolve(p, { paths: [CHAT_LEGS] });
    return true;
  } catch {
    return false;
  }
};

function run(cmd, cwd) {
  console.log(`\n→ ${cmd}`);
  execSync(cmd, { cwd, stdio: "inherit" });
}

console.log("\n╔══════════════════════════════════════════╗");
console.log("║   R³ CopilotKit — Dependency Installer  ║");
console.log("╚══════════════════════════════════════════╝\n");

// Backend (ChatLegs)
console.log("── Backend: SOURCE/chat-legs ──────────────");
const BE_PKGS = ["@copilotkit/runtime"];
const missingBe = BE_PKGS.filter((p) => !pkgExists(p));
if (missingBe.length) {
  run(`npm install ${missingBe.join(" ")}`, CHAT_LEGS);
} else {
  console.log("  ✓ Backend deps already installed");
}

// Frontend (SOURCE/chat-legs/src uses same package.json)
console.log("\n── Frontend (React): SOURCE/chat-legs ─────");
const FE_PKGS = ["@copilotkit/react-core", "@copilotkit/react-ui"];
const missingFe = FE_PKGS.filter((p) => !pkgExists(p));
if (missingFe.length) {
  run(`npm install ${missingFe.join(" ")}`, CHAT_LEGS);
} else {
  console.log("  ✓ Frontend deps already installed");
}

console.log("\n╔══════════════════════════════════════════╗");
console.log("║   DONE — next steps:                    ║");
console.log("║                                         ║");
console.log("║  1. In server.js (ChatLegs):            ║");
console.log("║     const { registerCopilotKit } =      ║");
console.log('║       require("../copilotkit/runtime"); ║');
console.log("║     registerCopilotKit(app);            ║");
console.log("║                                         ║");
console.log("║  2. In React App root:                  ║");
console.log("║     import R3CopilotProvider            ║");
console.log("║     Wrap <App> with <R3CopilotProvider> ║");
console.log("║                                         ║");
console.log("║  3. In any component:                   ║");
console.log("║     useR3FrontendTools()                ║");
console.log("╚══════════════════════════════════════════╝\n");
