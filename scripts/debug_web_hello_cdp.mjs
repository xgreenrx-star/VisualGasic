#!/usr/bin/env node
/**
 * Headless Godot web export debug via puppeteer-core + system Chrome.
 * Usage: node scripts/debug_web_hello_cdp.mjs [port] [waitMs]
 */
import puppeteer from "puppeteer-core";
import { spawn } from "child_process";
import { setTimeout as sleep } from "timers/promises";
import http from "http";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");
const exportDir = path.join(ROOT, "build/web/web_hello");
const port = parseInt(process.argv[2] || "8777", 10);
const waitMs = parseInt(process.argv[3] || "120000", 10);
const chrome =
  process.env.CHROME_PATH ||
  ["/usr/bin/google-chrome", "/usr/bin/chromium", "/usr/bin/chromium-browser"].find((p) =>
    fs.existsSync(p)
  );

function waitHttp(url, ms = 30000) {
  const deadline = Date.now() + ms;
  return new Promise((resolve, reject) => {
    const tick = () => {
      http
        .get(url, (res) => {
          res.resume();
          if (res.statusCode === 200) resolve();
          else if (Date.now() > deadline) reject(new Error(`HTTP ${res.statusCode}`));
          else setTimeout(tick, 250);
        })
        .on("error", () => {
          if (Date.now() > deadline) reject(new Error(`timeout ${url}`));
          else setTimeout(tick, 250);
        });
    };
    tick();
  });
}

const server = spawn(
  process.env.PYTHON || "python3",
  [path.join(ROOT, "scripts/serve_web_export.py"), exportDir, "-p", String(port)],
  { stdio: ["ignore", "pipe", "pipe"] }
);

const logs = [];
const url = `http://127.0.0.1:${port}/index.html`;

try {
  await waitHttp(url);
  if (!chrome) throw new Error("No Chrome/Chromium found; set CHROME_PATH");

  const browser = await puppeteer.launch({
    executablePath: chrome,
    headless: true,
    args: ["--no-sandbox", "--disable-gpu", "--enable-unsafe-swiftshader"],
  });
  const page = await browser.newPage();
  page.on("console", (msg) => logs.push(`[console.${msg.type()}] ${msg.text()}`));
  page.on("pageerror", (err) => logs.push(`[pageerror] ${err.message}`));
  page.on("requestfailed", (req) =>
    logs.push(`[requestfailed] ${req.url()} ${req.failure()?.errorText || ""}`)
  );

  console.log(`Loading ${url} (${waitMs}ms)...`);
  await page.goto(url, { waitUntil: "domcontentloaded", timeout: 60000 });
  await sleep(waitMs);

  const state = await page.evaluate(() => ({
    splash: !!document.getElementById("status-splash"),
    notice: document.getElementById("status-notice")?.innerText?.trim() || "",
    isolated: typeof crossOriginIsolated !== "undefined" && crossOriginIsolated,
    title: document.title,
  }));

  await browser.close();

  console.log("\n=== Page state ===");
  console.log(JSON.stringify(state, null, 2));
  console.log("\n=== Console (last 100) ===");
  for (const line of logs.slice(-100)) console.log(line);

  if (state.notice) {
    console.error("\nFAIL: status notice:", state.notice);
    process.exit(1);
  }
  if (state.splash) {
    console.error("\nFAIL: still on Godot splash overlay.");
    process.exit(1);
  }
  console.log("\nOK: splash dismissed.");
} catch (e) {
  console.error(e);
  process.exit(1);
} finally {
  server.kill("SIGTERM");
}
