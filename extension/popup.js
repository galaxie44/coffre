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

async function main() {
  const status = document.getElementById("status");
  const list = document.getElementById("list");
  const tab = await currentTab();
  const domain = domainFromUrl(tab?.url || "");
  status.textContent = domain ? `Domaine : ${domain}` : "Aucun domaine";

  if (!domain || !tab?.id) {
    status.textContent = "Onglet non compatible (page système ou sans domaine).";
    return;
  }

  const response = await chrome.runtime.sendMessage({
    type: "getCredentials",
    domain,
  });

  if (response?.error) {
    const detail = response.message || response.error;
    status.textContent =
      detail === "bridge_missing"
        ? "Coffre fermé ou verrouillé — ouvrez et déverrouillez l’app."
        : `Bridge indisponible : ${detail}`;
    return;
  }
  if (response?.error === "locked" || response?.locked) {
    status.textContent = "Coffre verrouillé — déverrouillez l'application.";
    return;
  }

  const entries = response?.entries || [];
  if (!entries.length) {
    status.textContent = "Aucune entrée pour ce site.";
    return;
  }

  status.textContent = `${entries.length} entrée(s)`;
  for (const entry of entries) {
    const li = document.createElement("li");
    const btn = document.createElement("button");
    btn.innerHTML = `<div class="title">${escapeHtml(entry.title || "Sans titre")}</div>
      <div class="sub">${escapeHtml(entry.username || "")}</div>`;
    btn.addEventListener("click", async () => {
      // Re-validate active tab URL to avoid filling after navigation (race).
      const latest = await currentTab();
      const latestDomain = domainFromUrl(latest?.url || "");
      if (!latest?.id || latest.id !== tab.id || latestDomain !== domain) {
        status.textContent =
          "L'onglet a changé. Rouvrez le popup pour remplir en sécurité.";
        return;
      }
      const entryDomain = domainFromUrl(entry.url || "") || entry.domain || "";
      if (entryDomain && !domainMatches(latestDomain, entryDomain)) {
        status.textContent = "Domaine incompatible — remplissage annulé.";
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
