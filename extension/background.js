const NATIVE_HOST = "com.coffre.bridge";

function domainFromUrl(url) {
  try {
    const u = new URL(url);
    return u.hostname.replace(/^www\./, "").toLowerCase();
  } catch (_) {
    return "";
  }
}

async function fetchViaNative(domain) {
  return fetchNative({ type: "credentials", domain });
}

async function fetchAllViaNative() {
  return fetchNative({ type: "allEntries" });
}

async function fetchNative(payload) {
  return new Promise((resolve) => {
    try {
      chrome.runtime.sendNativeMessage(NATIVE_HOST, payload, (response) => {
        if (chrome.runtime.lastError) {
          resolve({
            error: "native_messaging",
            message: chrome.runtime.lastError.message,
          });
          return;
        }
        resolve(response || { error: "empty" });
      });
    } catch (e) {
      resolve({ error: String(e) });
    }
  });
}

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message?.type === "getCredentials") {
    fetchViaNative(message.domain || "").then(sendResponse);
    return true;
  }
  if (message?.type === "getAllEntries") {
    fetchAllViaNative().then(sendResponse);
    return true;
  }
  if (message?.type === "saveCredential") {
    fetchNative({
      type: "saveCredential",
      username: message.username || "",
      password: message.password || "",
      url: message.url || "",
      domain: message.domain || "",
    }).then(sendResponse);
    return true;
  }
  return false;
});

chrome.action.onClicked.addListener(async (tab) => {
  // popup handles UI; keep for completeness
});

function disableChromePasswordSaving() {
  try {
    if (chrome.privacy?.services?.passwordSavingEnabled) {
      chrome.privacy.services.passwordSavingEnabled.set({ value: false });
    }
  } catch (_) {}
}

disableChromePasswordSaving();
chrome.runtime.onInstalled.addListener(disableChromePasswordSaving);
chrome.runtime.onStartup.addListener(disableChromePasswordSaving);
