async function currentTab() {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  return tab;
}

function domainFromUrl(url) {
  try {
    return new URL(url).hostname.replace(/^www\./, "").toLowerCase();
  } catch (_) {
    return "";
  }
}

function domainMatches(pageDomain, entryDomain) {
  const page = String(pageDomain || "")
    .toLowerCase()
    .replace(/^www\./, "");
  const entry = String(entryDomain || "")
    .toLowerCase()
    .replace(/^www\./, "");
  if (!page || !entry) return false;
  return page === entry || page.endsWith("." + entry);
}

function withTimeout(promise, ms) {
  return Promise.race([
    promise,
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error("timeout")), ms)
    ),
  ]);
}

async function main() {
  const status = document.getElementById("status");
  const list = document.getElementById("list");
  const tab = await currentTab();
  const domain = domainFromUrl(tab?.url || "");
  status.textContent = domain ? `Domaine : ${domain}` : "Aucun domaine";

  if (!domain || !tab?.id) {
    status.textContent = "Onglet non compatible (page systeme ou sans domaine).";
    return;
  }

  let response;
  try {
    response = await withTimeout(
      chrome.runtime.sendMessage({ type: "getCredentials", domain }),
      8000
    );
  } catch (e) {
    if (e.message === "timeout") {
      status.textContent =
        "Coffre ne repond pas. Verifiez qu'il est ouvert et deverrouille.";
      return;
    }
    throw e;
  }

  if (response?.error) {
    const detail = response.message || response.error;
    status.textContent =
      detail === "bridge_missing"
        ? "Coffre ferme ou verrouille - ouvrez et deverrouillez l'app."
        : `Bridge indisponible : ${detail}`;
    return;
  }
  if (response?.error === "locked" || response?.locked) {
    status.textContent = "Coffre verrouille - deverrouillez l'application.";
    return;
  }

  const entries = response?.entries || [];
  if (!entries.length) {
    status.textContent = "Aucune entree pour ce site.";
    return;
  }

  status.textContent = `${entries.length} entree(s)`;
  for (const entry of entries) {
    const li = document.createElement("li");
    const btn = document.createElement("button");
    btn.innerHTML = `<div class="title">${escapeHtml(entry.title || "Sans titre")}</div>
      <div class="sub">${escapeHtml(entry.username || "")}</div>`;
    btn.addEventListener("click", async () => {
      const latest = await currentTab();
      const latestDomain = domainFromUrl(latest?.url || "");
      if (!latest?.id || latest.id !== tab.id || latestDomain !== domain) {
        status.textContent =
          "L'onglet a change. Rouvrez le popup pour remplir en securite.";
        return;
      }
      const entryDomain = domainFromUrl(entry.url || "") || entry.domain || "";
      if (entryDomain && !domainMatches(latestDomain, entryDomain)) {
        status.textContent = "Domaine incompatible - remplissage annule.";
        return;
      }
      await chrome.tabs.sendMessage(latest.id, {
        type: "fillEntry",
        entry,
        expectedDomain: latestDomain,
      });
      window.close();
    });
    li.appendChild(btn);
    list.appendChild(li);
  }
}

function escapeHtml(s) {
  return String(s)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

main().catch((e) => {
  document.getElementById("status").textContent = String(e);
});
