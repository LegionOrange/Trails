const EARTH = 6_371_000
const PHOTOS = ["photos/SampleTrail.png", "photos/SampleOverlook.png", "photos/SampleWater.png"]
const MONTHS = ["jan.", "feb.", "mars", "apr.", "maj", "juni", "juli", "aug.", "sep.", "okt.", "nov.", "dec."]

const hav = (a, b) => {
  const lat1 = a[0] * Math.PI / 180
  const lat2 = b[0] * Math.PI / 180
  const dLat = (b[0] - a[0]) * Math.PI / 180
  const dLon = (b[1] - a[1]) * Math.PI / 180
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2
  return 2 * EARTH * Math.asin(Math.min(1, Math.sqrt(h)))
}
const project = (lat, lon, north, east) => [
  lat + north / 111_320,
  lon + east / (111_320 * Math.cos(lat * Math.PI / 180))
]
const distanceOf = (coords) => coords.slice(1).reduce((sum, _, index) => sum + hav(coords[index], coords[index + 1]), 0)

function loop(lat, lon, radius, points = 72) {
  const count = Math.max(points, 8)
  const coords = []
  for (let index = 0; index < count; index += 1) {
    const angle = index / count * 2 * Math.PI
    const wobble = 1 + 0.16 * Math.sin(angle * 3) + 0.06 * Math.cos(angle * 5)
    coords.push(project(lat, lon, radius * wobble * Math.cos(angle), radius * wobble * 0.78 * Math.sin(angle)))
  }
  coords.push(coords[0])
  return coords
}

function outAndBack(lat, lon, length, points = 48) {
  const half = Math.max(Math.floor(points / 2), 4)
  const coords = []
  for (let index = 0; index <= half; index += 1) {
    const progress = index / half
    coords.push(project(lat, lon, length * progress, 90 * Math.sin(progress * Math.PI * 2.5)))
  }
  for (let index = half - 1; index >= 0; index -= 1) {
    const progress = index / half
    coords.push(project(lat, lon, length * progress, 90 * Math.sin(progress * Math.PI * 2.5) + 22))
  }
  return coords
}

function stockholmDate(year, month, day, hour, minute) {
  const utcGuess = Date.UTC(year, month - 1, day, hour - 1, minute)
  const offset = stockholmOffset(new Date(utcGuess))
  return new Date(Date.UTC(year, month - 1, day, hour, minute) - offset)
}

function stockholmOffset(date) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "Europe/Stockholm",
    year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit", second: "2-digit",
    hourCycle: "h23"
  }).formatToParts(date)
  const get = (type) => Number(parts.find((part) => part.type === type).value)
  const asUTC = Date.UTC(get("year"), get("month") - 1, get("day"), get("hour"), get("minute"), get("second"))
  return asUTC - date.getTime()
}

function stockholmParts(date) {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Europe/Stockholm",
    year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit",
    hourCycle: "h23"
  }).formatToParts(date)
  return Object.fromEntries(parts.map((part) => [part.type, part.value]))
}

function formatDateTime(date) {
  const parts = stockholmParts(date)
  return `${Number(parts.day)} ${MONTHS[Number(parts.month) - 1]} ${parts.year} ${parts.hour}:${parts.minute}`
}

function formatDate(date) {
  const parts = stockholmParts(date)
  return `${Number(parts.day)} ${MONTHS[Number(parts.month) - 1]} ${parts.year}`
}

function ymd(date) {
  const parts = stockholmParts(date)
  return `${parts.year}-${parts.month}-${parts.day}`
}

function formatDistance(meters) {
  if (meters >= 1000) {
    return `${(meters / 1000).toLocaleString("sv-SE", { minimumFractionDigits: 2, maximumFractionDigits: 2 })} km`
  }
  return `${Math.round(meters).toLocaleString("sv-SE")} m`
}

function formatDuration(seconds) {
  const total = Math.max(0, Math.round(seconds))
  const hours = Math.floor(total / 3600)
  const minutes = Math.floor((total % 3600) / 60)
  const secs = total % 60
  if (hours > 0) return `${hours}:${String(minutes).padStart(2, "0")}:${String(secs).padStart(2, "0")}`
  return `${minutes}:${String(secs).padStart(2, "0")}`
}

function formatPace(secondsPerKm) {
  const total = Math.max(0, Math.round(secondsPerKm))
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, "0")} /km`
}

function makeRun(id, title, when, pace, coords) {
  const distance = distanceOf(coords)
  const duration = distance / 1000 * pace
  return {
    id, title, coords, distance, duration, pace,
    start: when,
    end: new Date(when.getTime() + duration * 1000),
    gpx: false
  }
}

const demoRuns = [
  makeRun("nacka", "Nackareservatet", stockholmDate(2026, 10, 18, 9, 15), 355, outAndBack(59.2965, 18.163, 4200)),
  makeRun("djurgarden", "Djurgården", stockholmDate(2026, 10, 12, 8, 40), 325, loop(59.326, 18.118, 1450)),
  makeRun("sodermalm", "Södermalm", stockholmDate(2026, 10, 4, 17, 5), 315, loop(59.3155, 18.071, 900, 64)),
  makeRun("hagaparken", "Hagaparken", stockholmDate(2026, 9, 27, 10, 0), 340, loop(59.3625, 18.033, 780, 60))
]

const state = {
  runs: demoRuns,
  marked: new Set(demoRuns.slice(0, 2).map((run) => run.id)),
  mode: "routes",
  selecting: false,
  chosen: new Set(),
  summary: false,
  focusedId: null,
  panel: null,
  large: false,
  status: "",
  filter: {
    markedOnly: false,
    selectedOnly: false,
    usesDateRange: false,
    start: ymd(demoRuns[demoRuns.length - 1].start),
    end: ymd(demoRuns[0].start),
    usesDistanceRange: false,
    minKm: 0,
    maxKm: 40
  }
}

function allows(run) {
  const filter = state.filter
  if (filter.markedOnly && !state.marked.has(run.id)) return false
  if (filter.selectedOnly && !state.chosen.has(run.id)) return false
  if (filter.usesDateRange) {
    const day = ymd(run.start)
    const start = filter.start < filter.end ? filter.start : filter.end
    const end = filter.start < filter.end ? filter.end : filter.start
    if (day < start || day > end) return false
  }
  if (filter.usesDistanceRange) {
    const km = run.distance / 1000
    const lower = Math.min(filter.minKm, filter.maxKm)
    const upper = Math.max(filter.minKm, filter.maxKm)
    if (km < lower || km > upper) return false
  }
  return true
}

const visibleRuns = () => state.runs.filter(allows)
const chosenRuns = () => state.runs.filter((run) => state.chosen.has(run.id))
const mapRuns = () => (state.summary ? chosenRuns() : visibleRuns())
const focusedRun = () => state.runs.find((run) => run.id === state.focusedId) || null

function summarize(runs) {
  const count = runs.length
  const totalDistance = runs.reduce((sum, run) => sum + run.distance, 0)
  const totalDuration = runs.reduce((sum, run) => sum + run.duration, 0)
  return {
    count,
    totalDistance,
    totalDuration,
    averageDistance: count ? totalDistance / count : 0,
    pace: totalDistance >= 1 ? totalDuration / (totalDistance / 1000) : null
  }
}

function timelineTitle() {
  const filter = state.filter
  if (filter.selectedOnly) return "Endast valda"
  if (filter.markedOnly) return "Markerade"
  if (filter.usesDateRange) return `${formatDate(dateFromYmd(filter.start))} – ${formatDate(dateFromYmd(filter.end))}`
  if (filter.usesDistanceRange) return "Distansfilter"
  return "Alla rutter"
}

function dateFromYmd(value) {
  const [year, month, day] = value.split("-").map(Number)
  return stockholmDate(year, month, day, 12, 0)
}

function emphasis(run) {
  if (state.summary) return "hot"
  if (state.focusedId) return state.focusedId === run.id ? "hot" : "dim"
  if (state.selecting) return state.chosen.has(run.id) ? "hot" : "dim"
  return "normal"
}

let map
function bootMap() {
  map = new maplibregl.Map({
    container: "map",
    style: "https://tiles.openfreemap.org/styles/dark",
    center: [18.09, 59.33],
    zoom: 11,
    attributionControl: false,
    pitchWithRotate: false,
    dragRotate: false
  })
  map.touchZoomRotate.disableRotation()
  map.addControl(new maplibregl.AttributionControl({ compact: true }), "top-left")
  map.on("load", () => {
    const attrib = document.querySelector(".maplibregl-ctrl-attrib")
    attrib?.classList.add("maplibregl-compact")
    attrib?.classList.remove("maplibregl-compact-show")
    tintBasemap()
    map.addSource("routes", { type: "geojson", data: emptyCollection() })
    const lineLayout = { "line-cap": "round", "line-join": "round" }
    map.addLayer({
      id: "route-glow",
      type: "line",
      source: "routes",
      layout: lineLayout,
      paint: {
        "line-color": "#ff610a",
        "line-width": ["match", ["get", "emphasis"], "hot", 12, "dim", 7, 8],
        "line-blur": 1.4,
        "line-opacity": ["match", ["get", "emphasis"], "dim", 0.22, "hot", 0.72, 0.55]
      }
    })
    map.addLayer({
      id: "route-core",
      type: "line",
      source: "routes",
      layout: lineLayout,
      paint: {
        "line-color": "#ffbc4d",
        "line-width": ["match", ["get", "emphasis"], "hot", 5.2, "dim", 2.6, 3.4],
        "line-opacity": ["match", ["get", "emphasis"], "dim", 0.28, 1]
      }
    })
    syncRoutes()
    fitMap()
    window.__trailsMap = map
    window.__trailsReady = true
    document.getElementById("map").dataset.ready = "true"
  })
  map.on("click", (event) => {
    const run = nearestRun(event.lngLat)
    if (!run || state.summary) return
    if (state.selecting) toggleChosen(run.id)
    else focus(run.id)
  })
}

function tintBasemap() {
  for (const layer of map.getStyle().layers) {
    const id = layer.id
    if (layer.type === "background") map.setPaintProperty(id, "background-color", "#1a2c30")
    if (layer.type === "fill" && /water/.test(id)) map.setPaintProperty(id, "fill-color", "#1d5c86")
    if (layer.type === "fill" && /park|wood|grass|forest|landcover/.test(id)) map.setPaintProperty(id, "fill-color", "#23483a")
    if (layer.type === "line" && /waterway/.test(id)) map.setPaintProperty(id, "line-color", "#1d5c86")
  }
}

function emptyCollection() {
  return { type: "FeatureCollection", features: [] }
}

function syncRoutes() {
  if (!map?.getSource("routes")) return
  const heatmap = state.mode === "heatmap"
  map.setPaintProperty("route-glow", "line-width", ["match", ["get", "emphasis"], "hot", heatmap ? 18 : 12, "dim", heatmap ? 10 : 7, heatmap ? 16 : 8])
  map.setPaintProperty("route-glow", "line-opacity", ["match", ["get", "emphasis"], "dim", heatmap ? 0.28 : 0.22, "hot", heatmap ? 0.8 : 0.72, heatmap ? 0.62 : 0.55])
  map.setPaintProperty("route-glow", "line-blur", heatmap ? 2.4 : 1.4)
  map.setPaintProperty("route-core", "line-width", ["match", ["get", "emphasis"], "hot", heatmap ? 8 : 5.2, "dim", heatmap ? 4 : 2.6, heatmap ? 6.5 : 3.4])
  map.setPaintProperty("route-core", "line-opacity", ["match", ["get", "emphasis"], "dim", heatmap ? 0.35 : 0.28, heatmap ? 0.9 : 1])
  map.getSource("routes").setData({
    type: "FeatureCollection",
    features: mapRuns().map((run) => ({
      type: "Feature",
      properties: { id: run.id, emphasis: emphasis(run) },
      geometry: { type: "LineString", coordinates: run.coords.map(([lat, lon]) => [lon, lat]) }
    }))
  })
  document.querySelectorAll(".focus-marker").forEach((node) => node.remove())
  const focused = focusedRun()
  if (focused && !state.summary) {
    const start = focused.coords[0]
    const marker = document.createElement("div")
    marker.className = "focus-marker"
    marker.style.cssText = "width:14px;height:14px;border-radius:99px;background:#ffbc4d;border:2px solid white;box-shadow:0 0 10px #ff610a"
    new maplibregl.Marker({ element: marker, anchor: "center" }).setLngLat([start[1], start[0]]).addTo(map)
  }
}

function nearestRun(lngLat) {
  const click = map.project(lngLat)
  let best = null
  let bestPx = 36
  for (const run of mapRuns()) {
    for (let index = 0; index < run.coords.length - 1; index += 2) {
      const a = map.project([run.coords[index][1], run.coords[index][0]])
      const b = map.project([run.coords[index + 1][1], run.coords[index + 1][0]])
      const px = pointToSegment(click.x, click.y, a.x, a.y, b.x, b.y)
      if (px < bestPx) {
        bestPx = px
        best = run
      }
    }
  }
  return best
}

function pointToSegment(px, py, ax, ay, bx, by) {
  const dx = bx - ax
  const dy = by - ay
  const length = dx * dx + dy * dy
  const t = length === 0 ? 0 : Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / length))
  const x = ax + t * dx
  const y = ay + t * dy
  return Math.hypot(px - x, py - y)
}

function fitMap() {
  if (!map) return
  const runs = mapRuns()
  const coords = (state.focusedId && !state.summary ? focusedRun()?.coords : null) || runs.flatMap((run) => run.coords)
  if (!coords?.length) return
  const bounds = new maplibregl.LngLatBounds()
  coords.forEach(([lat, lon]) => bounds.extend([lon, lat]))
  const panel = state.panel ? (state.large ? 0.74 : 0.56) : 0
  const height = window.innerHeight
  map.fitBounds(bounds, {
    padding: { top: 96, bottom: panel ? height * panel + 24 : 168, left: 36, right: 36 },
    duration: 0,
    maxZoom: 14.2
  })
}

function badge(coords) {
  const lats = coords.map((coord) => coord[0])
  const lons = coords.map((coord) => coord[1])
  const minLat = Math.min(...lats)
  const maxLat = Math.max(...lats)
  const minLon = Math.min(...lons)
  const maxLon = Math.max(...lons)
  const points = coords.map(([lat, lon]) => {
    const x = 6 + ((lon - minLon) / Math.max(maxLon - minLon, 1e-6)) * 32
    const y = 6 + ((maxLat - lat) / Math.max(maxLat - minLat, 1e-6)) * 32
    return `${x.toFixed(1)},${y.toFixed(1)}`
  }).join(" ")
  return `<svg class="badge" viewBox="0 0 44 44"><polyline points="${points}" fill="none" stroke="#ffbc4d" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>`
}

function render() {
  const open = Boolean(state.panel)
  document.documentElement.style.setProperty("--panel-h", open ? (state.large ? "74%" : "56%") : "0px")
  document.getElementById("panel").hidden = !open
  document.getElementById("above-panel").hidden = !open
  document.getElementById("closed-controls").hidden = open
  document.getElementById("timeline-pill").textContent = ""
  document.getElementById("timeline-open").textContent = ""
  for (const id of ["timeline-pill", "timeline-open"]) {
    const button = document.getElementById(id)
    button.replaceChildren(pillContent())
  }
  document.getElementById("summarize-button").hidden = !(state.selecting && state.chosen.size)
  const select = document.getElementById("select-button")
  select.setAttribute("aria-label", state.selecting ? "Klar" : "Välj")
  select.classList.toggle("text-btn", state.selecting)
  select.classList.toggle("icon-btn", !state.selecting)
  select.innerHTML = state.selecting ? "Klar" : `<span class="dashed" aria-hidden="true"></span>`
  for (const [id, page] of [["tab-rutter", "routes"], ["tab-filter", "filter"], ["tab-statistik", "statistics"]]) {
    const active = state.panel ? state.panel === page : page === "routes"
    document.getElementById(id).classList.toggle("on", active)
  }
  document.getElementById("map-mode-routes").classList.toggle("on", state.mode === "routes")
  document.getElementById("map-mode-heatmap").classList.toggle("on", state.mode === "heatmap")
  if (open) document.getElementById("panel").innerHTML = panelHTML()
  syncRoutes()
}

function pillContent() {
  const fragment = document.createDocumentFragment()
  const icon = document.createElement("span")
  icon.innerHTML = `<svg width="16" height="16" viewBox="0 0 24 24" aria-hidden="true"><rect x="4" y="5" width="16" height="15" rx="2" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="M4 10h16M8 3.5v4M16 3.5v4" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>`
  const label = document.createElement("span")
  label.textContent = timelineTitle()
  const chevron = document.createElement("span")
  chevron.textContent = "⌃"
  chevron.style.fontSize = "12px"
  fragment.append(icon, label, chevron)
  return fragment
}

function panelHTML() {
  if (state.panel === "filter") return filterHTML()
  if (state.panel === "statistics") return statsHTML(summarize(visibleRuns()), "Statistik", "Baserat på rutterna som filtret visar.", "stats-screen", true)
  if (state.summary) return summaryHTML()
  if (state.focusedId && focusedRun()) return detailHTML(focusedRun())
  return listHTML()
}

function listHTML() {
  const runs = visibleRuns()
  const title = state.selecting ? "Välj rutter" : "Rutter"
  const rows = runs.map((run) => {
    const id = state.selecting ? `choose-${run.title}` : `run-${run.title}`
    return `<div class="row-wrap">
      ${state.selecting ? `<button class="check ${state.chosen.has(run.id) ? "on" : ""}" data-choose="${run.id}" aria-label="Välj ${run.title}">${state.chosen.has(run.id) ? "✓" : ""}</button>` : ""}
      <button class="row" id="${id}" data-open="${run.id}">
        ${badge(run.coords)}
        <span class="meta"><strong>${run.title}</strong><span>${formatDateTime(run.start)}</span><span>${formatDistance(run.distance)} · ${formatDuration(run.duration)}</span></span>
      </button>
      <button class="star ${state.marked.has(run.id) ? "on" : ""}" data-mark="${run.id}" aria-label="${state.marked.has(run.id) ? "Ta bort markering" : "Markera rutt"}">${state.marked.has(run.id) ? "★" : "☆"}</button>
    </div>`
  }).join("")
  return `<div id="routes-list">
    <div class="sheet-title"><h1>${title}</h1><span class="count">${runs.length}</span></div>
    ${state.status ? `<p class="status">${state.status}</p>` : ""}
    ${rows || `<p class="note">Inga rutter matchar filtret.</p>`}
  </div>`
}

function detailHTML(run) {
  const pace = formatPace(run.duration / (run.distance / 1000))
  const photos = PHOTOS.map((src, index) => `<button type="button" id="photo-${index}" data-photo="${src}"><img src="${src}" alt="Foto från ${run.title}"></button>`).join("")
  const marked = state.marked.has(run.id)
  return `<div id="route-detail">
    <button class="back" id="detail-back" type="button">‹ Rutter</button>
    <h1 style="font-size:34px;margin:0 0 6px">${run.title}</h1>
    <p class="sub">${formatDateTime(run.start)}</p>
    <h2 style="font-size:20px;margin:8px 0">Foton från passet</h2>
    <div class="photos">${photos}</div>
    <div class="grid" style="margin-top:12px">
      ${tile("Distans", formatDistance(run.distance))}
      ${tile("Tid", formatDuration(run.duration))}
      ${tile("Tempo", pace)}
    </div>
    <button class="mark" id="detail-mark" type="button">${marked ? "★ Ta bort markering" : "☆ Markera rutt"}</button>
  </div>`
}

function filterHTML() {
  const filter = state.filter
  const selectedDisabled = state.chosen.size === 0 && !filter.selectedOnly
  return `<div id="filter-screen">
    <div class="sheet-title"><h1>Filter</h1></div>
    <p class="sub">${visibleRuns().length} rutter visas på kartan</p>
    ${toggle("Endast markerade", "filter-marked", filter.markedOnly, "markedOnly")}
    ${toggle("Visa endast valda", "filter-selected", filter.selectedOnly, "selectedOnly", selectedDisabled)}
    ${state.chosen.size === 0 ? `<p class="note">Välj rutter med Välj för att kunna filtrera på urvalet.</p>` : ""}
    ${toggle("Datumintervall", "filter-dates", filter.usesDateRange, "usesDateRange")}
    ${filter.usesDateRange ? `<label class="field"><span>Från</span><input id="date-start" type="date" value="${filter.start}"></label><label class="field"><span>Till</span><input id="date-end" type="date" value="${filter.end}"></label>` : ""}
    ${toggle("Distans", "filter-distance", filter.usesDistanceRange, "usesDistanceRange")}
    ${filter.usesDistanceRange ? `<p class="note">Minst ${formatDistance(filter.minKm * 1000)}</p><input id="min-km" type="range" min="0" max="40" step="0.5" value="${filter.minKm}"><p class="note">Högst ${formatDistance(filter.maxKm * 1000)}</p><input id="max-km" type="range" min="0" max="40" step="0.5" value="${filter.maxKm}">` : ""}
    <div class="seg" id="source-picker"><button type="button" class="on" id="source-sample">Exempel</button><button type="button" id="source-health">Hälsa</button></div>
    <button class="gpx" id="gpx-button" type="button">Öppna GPX-fil</button>
    <p class="note">GPX läses bara i den här webbläsaren och skickas inte vidare.</p>
    ${state.status ? `<p class="status">${state.status}</p>` : ""}
  </div>`
}

function statsHTML(stats, title, subtitle, id, showMarked) {
  return `<div id="${id}">
    <div class="sheet-title"><h1>${title}</h1></div>
    ${subtitle ? `<p class="sub">${subtitle}</p>` : `<p class="sub">${stats.count} valda rutter</p>`}
    <div class="grid two">
      ${title === "Statistik" ? tile("Antal", String(stats.count)) : ""}
      ${tile("Total distans", formatDistance(stats.totalDistance))}
      ${tile("Total tid", formatDuration(stats.totalDuration))}
      ${tile("Snittempo", stats.pace == null ? "–" : formatPace(stats.pace))}
      ${tile("Snittdistans", formatDistance(stats.averageDistance))}
      ${showMarked ? tile("Markerade", String(visibleRuns().filter((run) => state.marked.has(run.id)).length)) : ""}
    </div>
  </div>`
}

function summaryHTML() {
  const stats = summarize(chosenRuns())
  const names = chosenRuns().map((run) => `<div style="font-weight:700;margin-top:6px">${run.title}</div>`).join("")
  return `<div id="summary-screen">
    <div class="sheet-title"><h1>Sammanfattning</h1></div>
    <p class="sub">${stats.count} valda rutter</p>
    <div class="grid two">
      ${tile("Total distans", formatDistance(stats.totalDistance))}
      ${tile("Total tid", formatDuration(stats.totalDuration))}
      ${tile("Snittempo", stats.pace == null ? "–" : formatPace(stats.pace))}
      ${tile("Snittdistans", formatDistance(stats.averageDistance))}
    </div>
    <div style="margin:14px 0">${names}</div>
    <button class="mark" id="apply-selected-filter" type="button">Visa endast valda</button>
  </div>`
}

function tile(label, value) {
  return `<div class="tile"><small>${label}</small><b>${value}</b></div>`
}

function toggle(label, id, on, key, disabled = false) {
  return `<label class="toggle"><span>${label}</span><input id="${id}" data-filter="${key}" type="checkbox" ${on ? "checked" : ""} ${disabled ? "disabled" : ""}></label>`
}

function openPanel(page) {
  state.panel = page
  state.large = page !== "routes"
  if (page === "routes") {
    state.summary = false
    state.focusedId = null
    state.large = false
  }
  if (page !== "routes") state.summary = false
  render()
  fitMap()
}

function focus(id) {
  state.focusedId = id
  state.summary = false
  state.panel = "routes"
  state.large = true
  render()
  fitMap()
}

function toggleChosen(id) {
  if (state.chosen.has(id)) state.chosen.delete(id)
  else state.chosen.add(id)
  render()
}

function wire() {
  document.getElementById("map-mode-routes").onclick = () => { state.mode = "routes"; render() }
  document.getElementById("map-mode-heatmap").onclick = () => { state.mode = "heatmap"; render() }
  document.getElementById("select-button").onclick = () => {
    if (state.selecting) {
      state.selecting = false
    } else {
      state.selecting = true
      state.summary = false
      state.focusedId = null
      state.panel = "routes"
      state.large = false
    }
    render()
    fitMap()
  }
  document.getElementById("summarize-button").onclick = () => {
    if (!state.chosen.size) return
    state.summary = true
    state.selecting = false
    state.focusedId = null
    state.panel = "routes"
    state.large = true
    render()
    fitMap()
  }
  for (const id of ["recenter-button", "recenter-open"]) {
    document.getElementById(id).onclick = () => fitMap()
  }
  for (const id of ["timeline-pill", "timeline-open"]) {
    document.getElementById(id).onclick = () => openPanel("filter")
  }
  document.getElementById("tab-rutter").onclick = () => openPanel("routes")
  document.getElementById("tab-filter").onclick = () => openPanel("filter")
  document.getElementById("tab-statistik").onclick = () => openPanel("statistics")
  document.getElementById("panel").addEventListener("click", onPanelClick)
  document.getElementById("panel").addEventListener("change", onPanelChange)
  document.getElementById("photo-close").onclick = () => { document.getElementById("photo-modal").hidden = true }
  document.getElementById("gpx-input").onchange = (event) => {
    const file = event.target.files?.[0]
    if (file) importGpx(file)
    event.target.value = ""
  }
}

function onPanelClick(event) {
  const mark = event.target.closest("[data-mark]")
  if (mark) {
    const id = mark.dataset.mark
    if (state.marked.has(id)) state.marked.delete(id)
    else state.marked.add(id)
    render()
    return
  }
  const choose = event.target.closest("[data-choose]")
  if (choose && state.selecting) {
    toggleChosen(choose.dataset.choose)
    return
  }
  const open = event.target.closest("[data-open]")
  if (open) {
    if (state.selecting) toggleChosen(open.dataset.open)
    else focus(open.dataset.open)
    return
  }
  if (event.target.closest("#detail-back")) {
    state.focusedId = null
    state.large = false
    render()
    fitMap()
    return
  }
  if (event.target.closest("#detail-mark") && state.focusedId) {
    if (state.marked.has(state.focusedId)) state.marked.delete(state.focusedId)
    else state.marked.add(state.focusedId)
    render()
    return
  }
  const photo = event.target.closest("[data-photo]")
  if (photo) {
    document.getElementById("photo-full").src = photo.dataset.photo
    document.getElementById("photo-modal").hidden = false
    return
  }
  if (event.target.closest("#apply-selected-filter")) {
    state.filter.selectedOnly = true
    state.summary = false
    state.selecting = false
    state.focusedId = null
    state.panel = "routes"
    state.large = false
    render()
    fitMap()
    return
  }
  if (event.target.closest("#source-health")) {
    state.status = "Hälsa finns bara i iOS-appen. Exempelrutter visas här."
    render()
    return
  }
  if (event.target.closest("#gpx-button")) document.getElementById("gpx-input").click()
}

function onPanelChange(event) {
  const key = event.target.dataset.filter
  if (key) {
    state.filter[key] = event.target.checked
    render()
    fitMap()
    return
  }
  if (event.target.id === "date-start" || event.target.id === "date-end") {
    state.filter.start = document.getElementById("date-start").value
    state.filter.end = document.getElementById("date-end").value
    render()
    fitMap()
    return
  }
  if (event.target.id === "min-km" || event.target.id === "max-km") {
    state.filter.minKm = Number(document.getElementById("min-km").value)
    state.filter.maxKm = Number(document.getElementById("max-km").value)
    if (state.filter.minKm > state.filter.maxKm) {
      const swap = state.filter.minKm
      state.filter.minKm = state.filter.maxKm
      state.filter.maxKm = swap
    }
    render()
    fitMap()
  }
}

function importGpx(file) {
  const reader = new FileReader()
  reader.onload = () => {
    const xml = new DOMParser().parseFromString(String(reader.result), "application/xml")
    const points = [...xml.querySelectorAll("trkpt, rtept")]
    const coords = points.map((point) => [Number(point.getAttribute("lat")), Number(point.getAttribute("lon"))]).filter((pair) => Number.isFinite(pair[0]) && Number.isFinite(pair[1]))
    if (coords.length < 2) {
      state.status = "GPX-filen innehöll ingen rutt."
      render()
      return
    }
    const times = points.map((point) => point.querySelector("time")?.textContent).filter(Boolean).map((value) => new Date(value))
    const start = times[0] && !Number.isNaN(times[0].getTime()) ? times[0] : new Date()
    const end = times.at(-1) && !Number.isNaN(times.at(-1).getTime()) ? times.at(-1) : new Date(start.getTime() + 30 * 60 * 1000)
    const distance = distanceOf(coords)
    const duration = Math.max(60, (end - start) / 1000)
    const name = xml.querySelector("trk name, rte name")?.textContent?.trim() || file.name.replace(/\.gpx$/i, "")
    state.runs = [{
      id: `gpx-${Date.now()}`,
      title: name || "GPX",
      coords, distance, duration,
      pace: duration / (distance / 1000),
      start, end, gpx: true
    }, ...state.runs]
    state.panel = "routes"
    state.large = false
    state.focusedId = null
    state.summary = false
    state.status = ""
    render()
    fitMap()
  }
  reader.readAsText(file)
}

wire()
render()
bootMap()
