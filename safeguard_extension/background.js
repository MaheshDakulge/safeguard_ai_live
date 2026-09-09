// SafeGuard AI Extension Background Worker

let blocklist = [
  'gambling.com',
  'bet365.com',
  'casino.com',
  'adult.com',
  'pornhub.com',
  'xvideos.com'
];

chrome.runtime.onInstalled.addListener(() => {
  console.log('SafeGuard AI Extension Installed.');
  syncBlocklist();
});

chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'CONNECT') {
    syncBlocklist();
  }
});

async function syncBlocklist() {
  const data = await chrome.storage.local.get(['apiUrl', 'pairingCode', 'isConnected']);
  if (!data.isConnected || !data.apiUrl) return;

  try {
    const res = await fetch(`${data.apiUrl}/blocklist/blocked`);
    if (res.ok) {
      const json = await res.json();
      if (Array.isArray(json)) {
        blocklist = json.map(item => typeof item === 'string' ? item : item.domain);
      }
    }
  } catch (e) {
    console.log('Blocklist fetch error (using local cache):', e);
  }
}

// Monitor tab navigation & enforce blocklist
chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  if (changeInfo.status === 'complete' && tab.url) {
    try {
      const url = new URL(tab.url);
      const host = url.hostname.toLowerCase();

      // Check if domain matches blocklist
      const isBlocked = blocklist.some(domain => host.includes(domain.toLowerCase()));

      if (isBlocked) {
        chrome.tabs.update(tabId, {
          url: chrome.runtime.getURL(`blocked.html?domain=${encodeURIComponent(host)}`)
        });
        reportIncident(host, 'HIGH', `Attempted to visit restricted domain: ${host}`);
      } else {
        // Send heartbeat activity
        reportIncident(host, 'LOW', `Visited site: ${host}`);
      }
    } catch (e) {
      // Invalid URL or extension internal page
    }
  }
});

async function reportIncident(domain, riskLevel, message) {
  const data = await chrome.storage.local.get(['apiUrl', 'pairingCode', 'isConnected']);
  if (!data.isConnected || !data.apiUrl || !data.pairingCode) return;

  try {
    await fetch(`${data.apiUrl}/incidents`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        pairing_code: data.pairingCode,
        domain: domain,
        risk_level: riskLevel,
        details: message,
        timestamp: new Date().toISOString()
      })
    });
  } catch (e) {
    console.log('Incident report error:', e);
  }
}
