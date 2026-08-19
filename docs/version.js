/** Affiche la dernière version publiée sur GitHub Releases. */
const RELEASES_API = "https://api.github.com/repos/galaxie44/coffre/releases/latest";
const RELEASES_PAGE = "https://github.com/galaxie44/coffre/releases/latest";

function normalizeVersion(tag) {
  return String(tag || "").replace(/^v/i, "").trim();
}

async function loadLatestVersion() {
  const pills = document.querySelectorAll("[data-latest-version]");
  const badges = document.querySelectorAll("[data-version-badge]");
  const dates = document.querySelectorAll("[data-release-date]");

  try {
    const res = await fetch(RELEASES_API, {
      headers: { Accept: "application/vnd.github+json" },
    });
    if (!res.ok) throw new Error("HTTP " + res.status);
    const data = await res.json();
    const version = normalizeVersion(data.tag_name);
    const published = data.published_at
      ? new Date(data.published_at).toLocaleDateString("fr-FR", {
          day: "numeric",
          month: "long",
          year: "numeric",
        })
      : "";

    pills.forEach((el) => {
      el.textContent = version ? "Version " + version : "Dernière version";
      el.classList.add("loaded");
      if (el.tagName === "A") el.href = RELEASES_PAGE;
    });

    badges.forEach((el) => {
      el.textContent = version ? "Disponible — v" + version : "Disponible";
      el.classList.remove("soon");
      el.classList.add("ready");
    });

    dates.forEach((el) => {
      if (published) {
        el.textContent = "Publiée le " + published;
        el.hidden = false;
      }
    });
  } catch {
    pills.forEach((el) => {
      el.textContent = "Voir les releases";
      if (el.tagName === "A") el.href = RELEASES_PAGE;
    });
  }
}

document.addEventListener("DOMContentLoaded", loadLatestVersion);
