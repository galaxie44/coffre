/** Affichage des versions par plateforme depuis GitHub Releases. */
const REPO = "galaxie44/coffre";
const RELEASES_ALL_API = `https://api.github.com/repos/${REPO}/releases`;
const RELEASES_PAGE = `https://github.com/${REPO}/releases/latest`;

const PLATFORM_ASSETS = {
  windows: {
    file: "Coffre-Setup-Windows.exe",
    label: "Windows",
  },
  android: {
    file: "Coffre.apk",
    label: "Android",
  },
  macos: {
    file: "Coffre-macOS.zip",
    label: "macOS",
  },
  linux: {
    file: "Coffre-Linux-x64.tar.gz",
    label: "Linux",
  },
  ios: {
    file: "Coffre-iOS-unsigned.zip",
    label: "iOS",
  },
};

const MIN_ARCHIVE_VERSION = "1.0.8";

function normalizeVersion(tag) {
  return String(tag || "").replace(/^v/i, "").trim();
}

function compareVersions(a, b) {
  const pa = normalizeVersion(a).split(".").map((n) => parseInt(n, 10) || 0);
  const pb = normalizeVersion(b).split(".").map((n) => parseInt(n, 10) || 0);
  for (let i = 0; i < 3; i++) {
    if ((pa[i] || 0) !== (pb[i] || 0)) return (pa[i] || 0) - (pb[i] || 0);
  }
  return 0;
}

function sortReleases(releases) {
  return [...releases]
    .filter((r) => !r.draft)
    .sort((a, b) => compareVersions(b.tag_name, a.tag_name));
}

function releaseHasAsset(release, fileName) {
  return (release.assets || []).some((a) => a.name === fileName);
}

function downloadUrl(release, fileName) {
  const asset = (release.assets || []).find((a) => a.name === fileName);
  return asset?.browser_download_url || "";
}

function findLatestForAsset(releases, fileName) {
  for (const release of sortReleases(releases)) {
    if (releaseHasAsset(release, fileName)) return release;
  }
  return null;
}

async function fetchJson(url) {
  const res = await fetch(url, {
    headers: { Accept: "application/vnd.github+json" },
  });
  if (!res.ok) throw new Error("HTTP " + res.status);
  return res.json();
}

function updateLatestBanner(release) {
  const version = normalizeVersion(release.tag_name);
  const published = release.published_at
    ? new Date(release.published_at).toLocaleDateString("fr-FR", {
        day: "numeric",
        month: "long",
        year: "numeric",
      })
    : "";

  document.querySelectorAll("[data-latest-version]").forEach((el) => {
    el.textContent = version ? "Dernière version : " + version : "Dernière version";
    el.classList.add("loaded");
    if (el.tagName === "A") el.href = RELEASES_PAGE;
  });

  document.querySelectorAll("[data-release-date]").forEach((el) => {
    if (published) {
      el.textContent = "Publiée le " + published;
      el.hidden = false;
    }
  });
}

function updatePlatformEntry(key, cfg, release) {
  const badge = document.querySelector(`[data-platform-badge="${key}"]`);
  const btn = document.querySelector(`[data-download-btn="${key}"]`);
  const note = document.querySelector(`[data-download-note="${key}"]`);

  if (!release) {
    if (badge) {
      badge.textContent = "Bientôt disponible";
      badge.classList.add("soon");
      badge.classList.remove("ready");
    }
    if (btn) {
      btn.href = "#";
      btn.classList.add("disabled");
      btn.setAttribute("aria-disabled", "true");
    }
    if (note) note.textContent = "Aucune release GitHub pour cette plateforme";
    return;
  }

  const version = normalizeVersion(release.tag_name);
  const url = downloadUrl(release, cfg.file);

  if (badge) {
    badge.textContent = "Disponible — v" + version;
    badge.classList.add("ready");
    badge.classList.remove("soon");
  }

  if (btn && url) {
    btn.href = url;
    btn.classList.remove("disabled");
    btn.setAttribute("aria-disabled", "false");
  }

  if (note) {
    note.textContent = "Version " + version + " — " + cfg.label;
  }
}

async function loadLatestVersion() {
  try {
    const releases = await fetchJson(RELEASES_ALL_API);
    const sorted = sortReleases(releases);
    if (sorted.length) updateLatestBanner(sorted[0]);

    Object.entries(PLATFORM_ASSETS).forEach(([key, cfg]) => {
      const release = findLatestForAsset(releases, cfg.file);
      updatePlatformEntry(key, cfg, release);
    });
  } catch {
    document.querySelectorAll("[data-latest-version]").forEach((el) => {
      el.textContent = "Voir les releases";
      if (el.tagName === "A") el.href = RELEASES_PAGE;
    });
  }
}

async function loadArchivedVersions(containerId) {
  const container = document.getElementById(containerId);
  if (!container) return;

  try {
    const releases = await fetchJson(RELEASES_ALL_API);
    const filtered = sortReleases(releases).filter(
      (r) => compareVersions(r.tag_name, MIN_ARCHIVE_VERSION) >= 0
    );

    if (!filtered.length) {
      container.innerHTML = "<p>Aucune version archivée pour le moment.</p>";
      return;
    }

    container.innerHTML = filtered
      .map((release) => {
        const version = normalizeVersion(release.tag_name);
        const date = release.published_at
          ? new Date(release.published_at).toLocaleDateString("fr-FR")
          : "";
        const links = Object.entries(PLATFORM_ASSETS)
          .map(([key, cfg]) => {
            const url = downloadUrl(release, cfg.file);
            if (!url) return "";
            return `<a class="arch-link" href="${url}">${cfg.label}</a>`;
          })
          .filter(Boolean)
          .join("");

        return `
          <article class="arch-card">
            <div class="arch-head">
              <h2>Version ${version}</h2>
              <span class="arch-date">${date}</span>
            </div>
            <div class="arch-links">${links || "<span class=\"arch-muted\">Aucun fichier pour cette version.</span>"}</div>
          </article>
        `;
      })
      .join("");
  } catch {
    container.innerHTML = "<p>Impossible de charger les versions archivées.</p>";
  }
}

document.addEventListener("DOMContentLoaded", () => {
  loadLatestVersion();
  loadArchivedVersions("archived-versions");
});
