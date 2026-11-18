// Pregunta a la app de Block (servidor local en 127.0.0.1) si hay una sesion
// activa y que webs bloquear, y lo traduce a reglas de redireccion.
const BRIDGE = 'http://127.0.0.1:47613/state';
const POLL_SECONDS = 3;

async function fetchState() {
  try {
    const res = await fetch(BRIDGE, { cache: 'no-store' });
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null; // Block no esta abierto: no se bloquea nada.
  }
}

function rulesFor(sites) {
  return sites.map((domain, i) => ({
    id: i + 1,
    priority: 1,
    action: { type: 'redirect', redirect: { extensionPath: `/blocked.html?site=${encodeURIComponent(domain)}` } },
    condition: { requestDomains: [domain], resourceTypes: ['main_frame', 'sub_frame'] },
  }));
}

let lastKey = '';

async function sync() {
  const state = await fetchState();
  const sites = state && state.active ? state.sites : [];
  const key = JSON.stringify(sites);
  if (key === lastKey) return;
  lastKey = key;
  const existing = await chrome.declarativeNetRequest.getDynamicRules();
  await chrome.declarativeNetRequest.updateDynamicRules({
    removeRuleIds: existing.map((r) => r.id),
    addRules: rulesFor(sites),
  });
  await chrome.storage.session.set({ remainingMs: state ? state.remainingMs : 0, at: Date.now() });
  if (sites.length) closeOpenTabs(sites);
}

// Las pestanas ya abiertas no pasan por las reglas: se redirigen a mano.
async function closeOpenTabs(sites) {
  const tabs = await chrome.tabs.query({});
  for (const tab of tabs) {
    let host;
    try {
      host = new URL(tab.url).hostname.replace(/^www\./, '');
    } catch {
      continue;
    }
    const match = sites.find((d) => host === d || host.endsWith(`.${d}`));
    if (match) {
      chrome.tabs.update(tab.id, { url: chrome.runtime.getURL(`blocked.html?site=${encodeURIComponent(match)}`) });
    }
  }
}

chrome.alarms.create('block-sync', { periodInMinutes: 0.5 });
chrome.alarms.onAlarm.addListener(sync);
chrome.runtime.onStartup.addListener(sync);
chrome.runtime.onInstalled.addListener(sync);

// Las alarmas de MV3 van como minimo cada 30 s; mientras el service worker
// este vivo se sondea mas a menudo para que el bloqueo empiece enseguida.
setInterval(sync, POLL_SECONDS * 1000);
sync();
