import { chromium } from "playwright"
import { spawn } from "node:child_process"
import { mkdir } from "node:fs/promises"
import path from "node:path"
import { fileURLToPath } from "node:url"

const here = path.dirname(fileURLToPath(import.meta.url))
const out = path.resolve(here, "../docs/web-screenshots")
const port = 8765

const server = spawn("python3", ["-m", "http.server", String(port), "--bind", "127.0.0.1"], {
  cwd: here,
  stdio: "ignore"
})

const browser = await chromium.launch()
const page = await browser.newPage({
  viewport: { width: 390, height: 844 },
  deviceScaleFactor: 2
})

async function settle(ms = 1800) {
  await page.waitForFunction(() => window.__trailsReady === true)
  await page.waitForTimeout(ms)
}

async function shot(name) {
  await page.screenshot({ path: path.join(out, name) })
  console.log("saved", name)
}

try {
  await mkdir(out, { recursive: true })
  await page.goto(`http://127.0.0.1:${port}/`, { waitUntil: "networkidle" })
  await settle(2500)
  await shot("01-map.png")

  await page.locator("#map-mode-heatmap").click()
  await page.waitForTimeout(600)
  await shot("08-heatmap.png")
  await page.locator("#map-mode-routes").click()

  await page.locator("#tab-rutter").click()
  await page.locator("#routes-list").waitFor()
  await page.waitForTimeout(500)
  await shot("02-routes-list.png")

  await page.locator("#run-Nackareservatet").click()
  await page.locator("#route-detail").waitFor()
  await page.locator("#photo-0").waitFor()
  await page.waitForTimeout(700)
  await shot("03-route-detail.png")

  await page.locator("#tab-filter").click()
  await page.locator("#filter-screen").waitFor()
  await page.waitForTimeout(400)
  await shot("04-filter.png")

  await page.locator("#tab-statistik").click()
  await page.locator("#stats-screen").waitFor()
  await page.waitForTimeout(400)
  await shot("05-statistik.png")

  await page.locator("#tab-rutter").click()
  await page.locator("#routes-list").waitFor()
  await page.locator("#select-button").click()
  await page.locator("#choose-Nackareservatet").click()
  await page.locator("#choose-Djurgården").click()
  await page.locator("#summarize-button").waitFor()
  await page.waitForTimeout(500)
  await shot("06-selection.png")

  await page.locator("#summarize-button").click()
  await page.locator("#summary-screen").waitFor()
  await page.waitForTimeout(700)
  await shot("07-summary.png")
} finally {
  await browser.close()
  server.kill()
}
