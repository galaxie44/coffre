/** Coffre — autofill. Chrome PWM cannot be fully hidden from a page; we block the field until Coffre fills it. */

const FIELD = {
  EMAIL: "email",
  PASSWORD: "password",
  USERNAME: "username",
};

let panel = null;
let activeField = null;
let activeFieldKind = null;
let lastEntries = [];
let lastError = "";
let loadToken = 0;
let cachedAll = null;
let cacheAt = 0;
let lastCoffreFill = null;
let saveBar = null;
let saveOfferOpen = false;

function sendWithTimeout(msg, ms = 8000) {
  return Promise.race([
    chrome.runtime.sendMessage(msg),
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error("timeout")), ms)
    ),
  ]);
}

function pageDomain() {
  try {
    return location.hostname.replace(/^www\./, "").toLowerCase();
  } catch (_) {
    return "";
  }
}

function domainMatches(page, entry) {
  const p = String(page || "").toLowerCase().replace(/^www\./, "");
  const e = String(entry || "").toLowerCase().replace(/^www\./, "");
  if (!p || !e) return false;
  return p === e || p.endsWith("." + e);
}

function domainFromUrl(url) {
  try {
    return new URL(url).hostname.replace(/^www\./, "").toLowerCase();
  } catch (_) {
    return "";
  }
}

function fieldHint(el) {
  let labelled = "";
  const labelledBy = el.getAttribute("aria-labelledby") || "";
  if (labelledBy) {
    labelled = labelledBy
      .split(/\s+/)
      .map((id) => document.getElementById(id)?.textContent || "")
      .join(" ");
  }
  let labelText = "";
  if (el.id) {
    try {
      const lab = document.querySelector(`label[for="${CSS.escape(el.id)}"]`);
      if (lab) labelText = lab.textContent || "";
    } catch (_) {}
  }
  const wrap = el.closest("label");
  if (wrap) labelText += " " + (wrap.textContent || "");
  return `${el.name || ""} ${el.id || ""} ${el.placeholder || ""} ${el.className || ""} ${
    el.getAttribute("aria-label") || ""
  } ${labelled} ${labelText}`.toLowerCase();
}

function isInCodeInputGroup(el) {
  const parent = el.closest("form, fieldset, div, span") || el.parentElement;
  if (!parent) return false;
  const short = Array.from(parent.querySelectorAll("input")).filter((i) => {
    if (i.disabled || i.type === "hidden") return false;
    return i.maxLength === 1 || i.maxLength === 2;
  });
  return short.length >= 4;
}

function isVerificationPage() {
  try {
    const p = (location.pathname + location.search).toLowerCase();
    return p.includes("/login/device") || /\/challenge\/(totp|sms|iap)/.test(p);
  } catch (_) {
    return false;
  }
}

/** Codes 2FA / Authenticator / device login : jamais le menu Coffre. */
function isOneTimeCodeField(el) {
  if (!(el instanceof HTMLInputElement) && !(el instanceof HTMLTextAreaElement)) return false;
  if (el.dataset.coffre === "1") return false;
  if (isVerificationPage()) return true;

  const type = (el.type || "").toLowerCase();
  const ac = (el.getAttribute("autocomplete") || "").toLowerCase();
  const inputMode = (el.getAttribute("inputmode") || "").toLowerCase();
  const hint = fieldHint(el);
  const maxLength = el.maxLength;
  const pattern = el.getAttribute("pattern") || "";

  if (
    ac.includes("one-time-code") ||
    ac.includes("one_time_code") ||
    ac.includes("otp") ||
    ac.includes("totp")
  ) {
    return true;
  }
  if (
    /otp|totp|hotp|2fa|mfa|two.?factor|authenticator|verification.?code|verify.?code|sms.?code|email.?code|one.?time|user.?code|device.?code|auth.?code|security.?code|confirmation.?code|ga-?code|backup.?code/.test(
      hint
    )
  ) {
    return true;
  }
  if (maxLength === 1) return true;
  if (isInCodeInputGroup(el)) return true;
  if (pattern === "\\d" || pattern === "[0-9]" || pattern === "[0-9]{1}") return true;
  const numeric =
    inputMode === "numeric" || inputMode === "decimal" || type === "tel" || type === "number";
  if (numeric && maxLength >= 4 && maxLength <= 8) return true;
  return false;
}

function fieldMeta(el) {
  if (!(el instanceof HTMLInputElement) && !(el instanceof HTMLTextAreaElement)) return null;
  if (isOneTimeCodeField(el)) return null;
  const type = (el.type || "").toLowerCase();
  const ac = (el.getAttribute("autocomplete") || "").toLowerCase();
  const hint = fieldHint(el);
  if (type === "password" || (ac.includes("password") && !ac.includes("one-time"))) {
    return FIELD.PASSWORD;
  }
  if (
    type === "email" ||
    ac.includes("email") ||
    ac.includes("username") ||
    /email|e-mail|mail|login|user|identifiant|username/.test(hint)
  ) {
    return FIELD.EMAIL;
  }
  if ((type === "text" || type === "tel" || type === "url" || !type) && looksLikeLoginField(el, hint)) {
    return FIELD.USERNAME;
  }
  return null;
}

function looksLikeLoginField(el, hint) {
  if (/email|user|login|identifiant|account|pseudo/.test(hint)) return true;
  const form = el.form || el.closest("form");
  if (form && form.querySelector('input[type="password"]')) return true;
  return false;
}

function isUsable(el) {
  if (!el || el.disabled) return false;
  if (el.type === "hidden" || el.type === "submit" || el.type === "button") return false;
  const rect = el.getBoundingClientRect();
  return rect.width > 8 && rect.height > 8;
}

function shieldField(field) {
  if (!field) return;
  const kind = fieldMeta(field);
  if (!kind) return;

  field.setAttribute("data-lpignore", "true");
  field.setAttribute("data-1p-ignore", "true");
  field.setAttribute("data-bwignore", "true");
  field.setAttribute("data-form-type", "other");
  field.setAttribute("data-coffre", "1");
  field.setAttribute("autocorrect", "off");
  field.setAttribute("autocapitalize", "off");
  field.setAttribute("spellcheck", "false");

  // Chrome ignore souvent "off". Une valeur inconnue réduit la saisie auto native.
  if (kind === FIELD.PASSWORD) {
    field.setAttribute("autocomplete", "new-password");
  } else {
    field.setAttribute("autocomplete", "one-time-code");
  }

  if (field.dataset.coffreShield === "1") return;
  field.dataset.coffreShield = "1";

  // Readonly au focus : Chrome n'ouvre pas son menu de mots de passe sur un champ en lecture seule.
  field.addEventListener(
    "focus",
    () => {
      field.setAttribute("readonly", "readonly");
      requestAnimationFrame(() => {
        field.setAttribute("readonly", "readonly");
      });
    },
    true
  );

  const unlock = () => field.removeAttribute("readonly");
  field.addEventListener("keydown", unlock, true);
  field.addEventListener("pointerdown", () => {
    field.setAttribute("readonly", "readonly");
    setTimeout(unlock, 350);
  }, true);
}

function findPasswordField() {
  return document.querySelector('input[type="password"]:not([disabled])');
}

function findUsernameField() {
  const inputs = Array.from(document.querySelectorAll("input"));
  const password = findPasswordField();
  if (password) {
    const before = inputs.filter(
      (i) =>
        i !== password &&
        isUsable(i) &&
        !isOneTimeCodeField(i) &&
        (i.type === "text" ||
          i.type === "email" ||
          i.type === "tel" ||
          !i.type ||
          (i.getAttribute("autocomplete") || "").includes("username") ||
          (i.getAttribute("autocomplete") || "").includes("email"))
    );
    return before.length ? before[before.length - 1] : null;
  }
  return inputs.find((i) => isUsable(i) && fieldMeta(i) === FIELD.EMAIL);
}

function setNativeValue(input, value) {
  if (!input) return;
  input.removeAttribute("readonly");
  input.focus();
  const proto = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value");
  if (input._valueTracker) input._valueTracker.setValue("");
  if (proto?.set) proto.set.call(input, value);
  else input.value = value;
  input.dispatchEvent(new InputEvent("input", { bubbles: true, cancelable: true, inputType: "insertText", data: value }));
  input.dispatchEvent(new Event("change", { bubbles: true }));
}

function fillEntry(entry, kind, targetField) {
  const usernameField =
    kind === FIELD.EMAIL || kind === FIELD.USERNAME
      ? targetField || findUsernameField()
      : findUsernameField();
  const passwordField =
    kind === FIELD.PASSWORD ? targetField || findPasswordField() : findPasswordField();

  if (kind === FIELD.EMAIL || kind === FIELD.USERNAME) {
    if (usernameField && entry.username) setNativeValue(usernameField, entry.username);
    lastCoffreFill = {
      username: entry.username || "",
      password: (passwordField && passwordField.value) || entry.password || "",
    };
    return;
  }
  if (kind === FIELD.PASSWORD) {
    if (usernameField && entry.username && !usernameField.value) {
      setNativeValue(usernameField, entry.username);
    }
    if (passwordField && entry.password) setNativeValue(passwordField, entry.password);
    lastCoffreFill = {
      username: (usernameField && usernameField.value) || entry.username || "",
      password: entry.password || "",
    };
  }
}

function maskPassword(pwd) {
  if (!pwd) return "";
  return "•".repeat(Math.min(Math.max(pwd.length, 8), 16));
}

function escapeHtml(s) {
  return String(s)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function removePanel() {
  if (panel) {
    panel.remove();
    panel = null;
  }
  activeField = null;
  activeFieldKind = null;
}

function placePanel(anchor) {
  if (!panel || !anchor) return;
  const rect = anchor.getBoundingClientRect();
  const w = Math.max(rect.width, 340);
  panel.style.top = `${Math.min(rect.bottom + 8, window.innerHeight - 340)}px`;
  panel.style.left = `${Math.min(rect.left, window.innerWidth - w - 8)}px`;
  panel.style.width = `${w}px`;
}

function parseBridgeError(response) {
  if (!response) return "Extension Coffre inactive.";
  if (response.error) {
    const detail = response.message || response.error;
    if (String(detail).includes("not found") || response.error === "native_messaging") {
      return "Host Native Messaging introuvable.";
    }
    if (response.error === "bridge_missing") {
      return "Coffre fermé ou verrouillé — ouvrez l'app.";
    }
    return "Coffre non connecté : " + detail;
  }
  if (response.locked) return "Coffre verrouillé.";
  return "";
}

async function preloadCache() {
  try {
    const r = await sendWithTimeout({ type: "getAllEntries" });
    if (r && r.entries) {
      cachedAll = r.entries;
      cacheAt = Date.now();
    }
  } catch (_) {}
}

async function loadEntries(kind) {
  const token = ++loadToken;
  lastError = "";
  lastEntries = [];

  try {
    let response;
    if (kind === FIELD.EMAIL || kind === FIELD.USERNAME) {
      if (cachedAll && Date.now() - cacheAt < 45000) {
        response = { entries: cachedAll };
      } else {
        response = await sendWithTimeout({ type: "getAllEntries" });
        if (response?.entries) {
          cachedAll = response.entries;
          cacheAt = Date.now();
        }
      }
    } else {
      response = await sendWithTimeout({
        type: "getCredentials",
        domain: pageDomain(),
      });
    }
    if (token !== loadToken) return;

    lastError = parseBridgeError(response);
    if (lastError) return;

    const entries = response.entries || [];
    const domain = pageDomain();

    if (kind === FIELD.EMAIL || kind === FIELD.USERNAME) {
      const seen = new Set();
      const sorted = [...entries].sort((a, b) => {
        const am = domainMatches(domain, domainFromUrl(a.url) || a.domain) ? 0 : 1;
        const bm = domainMatches(domain, domainFromUrl(b.url) || b.domain) ? 0 : 1;
        return am - bm;
      });
      lastEntries = sorted.filter((e) => {
        const u = (e.username || "").trim();
        if (!u || seen.has(u.toLowerCase())) return false;
        seen.add(u.toLowerCase());
        return true;
      });
    } else {
      lastEntries = entries.filter((e) => e.password);
    }
  } catch (_) {
    lastError = "Impossible de contacter Coffre.";
  }
}

function panelBaseStyle() {
  return {
    position: "fixed",
    zIndex: "2147483647",
    background: "#fff",
    color: "#1a2426",
    border: "2px solid #0A6B6B",
    borderRadius: "12px",
    boxShadow: "0 16px 48px rgba(10,40,45,0.35)",
    fontFamily: "Segoe UI, system-ui, sans-serif",
    overflow: "hidden",
    maxHeight: "380px",
  };
}

function renderPanelLoading(anchor, kind) {
  if (panel) panel.remove();
  activeField = anchor;
  activeFieldKind = kind;
  panel = document.createElement("div");
  panel.id = "coffre-autofill-panel";
  Object.assign(panel.style, panelBaseStyle());
  panel.style.padding = "16px";
  panel.innerHTML = `<div style="font-weight:700;color:#0A6B6B;margin-bottom:8px">Coffre</div><div style="color:#5a6b70;font-size:13px">Chargement…</div>`;
  document.documentElement.appendChild(panel);
  placePanel(anchor);
}

function renderPanel(anchor, kind) {
  if (panel) panel.remove();
  activeField = anchor;
  activeFieldKind = kind;

  panel = document.createElement("div");
  panel.id = "coffre-autofill-panel";
  Object.assign(panel.style, panelBaseStyle());

  const header = document.createElement("div");
  Object.assign(header.style, {
    padding: "12px 14px",
    fontSize: "13px",
    fontWeight: "700",
    color: "#fff",
    background: "#0A6B6B",
    display: "flex",
    justifyContent: "space-between",
  });
  const label = kind === FIELD.PASSWORD ? "Mots de passe Coffre" : "Comptes Coffre";
  header.innerHTML = `<span>${label}</span><span style="opacity:0.85;font-weight:500">${escapeHtml(pageDomain() || "")}</span>`;
  panel.appendChild(header);

  const body = document.createElement("div");
  body.style.maxHeight = "300px";
  body.style.overflow = "auto";

  if (lastError) {
    const err = document.createElement("div");
    Object.assign(err.style, { padding: "14px", fontSize: "13px", color: "#8B1E1E" });
    err.textContent = lastError;
    body.appendChild(err);
  } else if (!lastEntries.length) {
    const empty = document.createElement("div");
    Object.assign(empty.style, { padding: "14px", fontSize: "13px", color: "#5a6b70" });
    empty.textContent =
      kind === FIELD.PASSWORD
        ? "Aucun mot de passe pour ce site dans Coffre."
        : "Aucun compte dans Coffre — importez depuis Chrome (Paramètres Coffre).";
    body.appendChild(empty);
  } else {
    for (const entry of lastEntries) {
      const entryDomain = domainFromUrl(entry.url || "") || entry.domain || "";
      const matchesSite = entryDomain && domainMatches(pageDomain(), entryDomain);
      const btn = document.createElement("button");
      btn.type = "button";
      Object.assign(btn.style, {
        display: "block",
        width: "100%",
        textAlign: "left",
        border: "0",
        borderBottom: "1px solid #eef3f5",
        background: matchesSite ? "#eef6f6" : "transparent",
        padding: "12px 14px",
        cursor: "pointer",
      });
      const sub =
        kind === FIELD.PASSWORD ? maskPassword(entry.password) : entry.title || entryDomain || "";
      btn.innerHTML = `<div style="font-size:14px;font-weight:600">${escapeHtml(
        entry.username || entry.title || "Sans titre"
      )}</div><div style="font-size:12px;color:#5a6b70;margin-top:2px">${escapeHtml(sub)}</div>`;
      btn.addEventListener("mousedown", (e) => {
        e.preventDefault();
        e.stopPropagation();
        fillEntry(entry, kind, anchor);
        removePanel();
      });
      body.appendChild(btn);
    }
  }

  panel.appendChild(body);
  document.documentElement.appendChild(panel);
  placePanel(anchor);
}

async function showForField(field, kind) {
  if (!field || !isUsable(field)) return;
  shieldField(field);
  field.setAttribute("readonly", "readonly");
  renderPanelLoading(field, kind);
  await loadEntries(kind);
  renderPanel(field, kind);
}

function onPointerDown(event) {
  const target = event.target;
  if (!(target instanceof HTMLInputElement)) return;
  if (isOneTimeCodeField(target)) {
    removePanel();
    return;
  }
  const kind = fieldMeta(target);
  if (!kind) return;
  shieldField(target);
  target.setAttribute("readonly", "readonly");
  event.stopPropagation();
  showForField(target, kind);
}

function scanFields() {
  document.querySelectorAll("input").forEach((el) => {
    if (fieldMeta(el)) shieldField(el);
  });
}

document.addEventListener("pointerdown", onPointerDown, true);
document.addEventListener(
  "focusin",
  (e) => {
    if (!(e.target instanceof HTMLInputElement)) return;
    if (isOneTimeCodeField(e.target)) {
      removePanel();
      return;
    }
    if (fieldMeta(e.target)) {
      shieldField(e.target);
      e.target.setAttribute("readonly", "readonly");
      const kind = fieldMeta(e.target);
      if (kind && e.target !== activeField) showForField(e.target, kind);
    }
  },
  true
);

document.addEventListener(
  "click",
  (e) => {
    if (panel && !panel.contains(e.target) && e.target !== activeField) removePanel();
  },
  true
);

window.addEventListener(
  "scroll",
  () => {
    if (panel && activeField) placePanel(activeField);
  },
  true
);
window.addEventListener("resize", () => {
  if (panel) removePanel();
});

const observer = new MutationObserver(() => scanFields());
observer.observe(document.documentElement, { childList: true, subtree: true });
scanFields();
setTimeout(preloadCache, 400);
setInterval(preloadCache, 20000);

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message?.type === "fillEntry") {
    const kind = findPasswordField() ? FIELD.PASSWORD : FIELD.EMAIL;
    fillEntry(message.entry || {}, kind, null);
    removePanel();
    sendResponse({ ok: true });
    return true;
  }
  if (message?.type === "pageDomain") {
    sendResponse({ domain: pageDomain() });
    return true;
  }
  return false;
});

function captureTypedCredentials() {
  const userField = findUsernameField();
  const username = (userField?.value || "").trim();
  const passwords = Array.from(document.querySelectorAll("input[type=password]")).filter(isUsable);
  let password = "";
  for (const field of passwords) {
    if (field.value) {
      password = field.value;
      break;
    }
  }
  return { username, password };
}

function wasFilledFromCoffre(username, password) {
  if (!lastCoffreFill) return false;
  return lastCoffreFill.username === username && lastCoffreFill.password === password;
}

function classifyLocal(username, password) {
  const domain = pageDomain();
  const entries = cachedAll || [];
  const matches = entries.filter((e) =>
    domainMatches(domain, domainFromUrl(e.url) || e.domain || "")
  );
  const sameUser = matches.find(
    (e) => (e.username || "").trim().toLowerCase() === username.toLowerCase()
  );
  if (sameUser && sameUser.password === password) return "unchanged";
  if (sameUser) return "update";
  return "create";
}

function dismissKey(username) {
  return `coffre-save:${pageDomain()}:${username.toLowerCase()}`;
}

function removeSaveBar() {
  if (saveBar) {
    saveBar.remove();
    saveBar = null;
  }
  saveOfferOpen = false;
}

function showSaveBar({ username, password, kind }) {
  if (saveOfferOpen) return;
  saveOfferOpen = true;
  removePanel();
  if (saveBar) saveBar.remove();

  saveBar = document.createElement("div");
  saveBar.id = "coffre-save-bar";
  Object.assign(saveBar.style, {
    position: "fixed",
    left: "12px",
    right: "12px",
    bottom: "12px",
    zIndex: "2147483647",
    background: "#fff",
    color: "#1a2426",
    border: "2px solid #0A6B6B",
    borderRadius: "14px",
    boxShadow: "0 16px 48px rgba(10,40,45,0.28)",
    fontFamily: "Segoe UI, system-ui, sans-serif",
    padding: "14px 16px",
    maxWidth: "520px",
    margin: "0 auto",
  });

  const title = kind === "update" ? "Mettre à jour dans Coffre ?" : "Enregistrer dans Coffre ?";
  const subtitle =
    kind === "update"
      ? "Le mot de passe de ce compte a changé."
      : "Nouvelle combinaison détectée pour ce site.";

  const head = document.createElement("div");
  head.innerHTML = `<div style="font-weight:700;color:#0A6B6B;margin-bottom:4px">${title}</div>
    <div style="font-size:13px;color:#5a6b70;margin-bottom:8px">${subtitle}</div>
    <div style="font-size:13px"><strong>${escapeHtml(username)}</strong> · ${escapeHtml(
    pageDomain() || "ce site"
  )}</div>`;
  saveBar.appendChild(head);

  const actions = document.createElement("div");
  Object.assign(actions.style, {
    display: "flex",
    justifyContent: "flex-end",
    gap: "8px",
    marginTop: "12px",
  });

  const later = document.createElement("button");
  later.type = "button";
  later.textContent = "Pas maintenant";
  Object.assign(later.style, {
    border: "0",
    background: "transparent",
    color: "#5a6b70",
    fontWeight: "600",
    cursor: "pointer",
    padding: "8px 10px",
  });
  later.addEventListener("click", async () => {
    try {
      sessionStorage.setItem(dismissKey(username), "1");
      await chrome.storage?.session?.remove("pendingSave");
    } catch (_) {}
    removeSaveBar();
  });

  const save = document.createElement("button");
  save.type = "button";
  save.textContent = kind === "update" ? "Mettre à jour" : "Enregistrer";
  Object.assign(save.style, {
    border: "0",
    background: "#0A6B6B",
    color: "#fff",
    fontWeight: "700",
    cursor: "pointer",
    padding: "8px 14px",
    borderRadius: "8px",
  });
  save.addEventListener("click", async () => {
    save.disabled = true;
    save.textContent = "…";
    try {
      const response = await sendWithTimeout({
        type: "saveCredential",
        username,
        password,
        url: location.href,
        domain: pageDomain(),
      });
      if (response?.locked || response?.error === "bridge_missing" || response?.error) {
        save.disabled = false;
        save.textContent = kind === "update" ? "Mettre à jour" : "Enregistrer";
        head.querySelector("div")?.insertAdjacentHTML?.(
          "afterend",
          `<div style="font-size:13px;color:#8B1E1E;margin:8px 0">Ouvrez et déverrouillez Coffre, puis réessayez.</div>`
        );
        return;
      }
      try {
        sessionStorage.setItem(dismissKey(username), "1");
        await chrome.storage?.session?.remove("pendingSave");
      } catch (_) {}
      lastCoffreFill = { username, password };
      removeSaveBar();
    } catch (_) {
      save.disabled = false;
      save.textContent = kind === "update" ? "Mettre à jour" : "Enregistrer";
    }
  });

  actions.appendChild(later);
  actions.appendChild(save);
  saveBar.appendChild(actions);
  document.documentElement.appendChild(saveBar);
}

async function maybeOfferSave() {
  const { username, password } = captureTypedCredentials();
  if (!username || !password || password.length < 4) return;
  if (wasFilledFromCoffre(username, password)) return;
  try {
    if (sessionStorage.getItem(dismissKey(username))) return;
  } catch (_) {}

  if (!cachedAll) await preloadCache();
  const kind = classifyLocal(username, password);
  if (kind === "unchanged") return;

  const payload = {
    username,
    password,
    domain: pageDomain(),
    url: location.href,
    kind,
    at: Date.now(),
  };
  try {
    await chrome.storage?.session?.set({ pendingSave: payload });
  } catch (_) {}
  showSaveBar(payload);
}

function isSubmitControl(el) {
  if (!(el instanceof Element)) return false;
  if (el.closest("#coffre-save-bar, #coffre-autofill-panel")) return false;
  if (el.matches("input[type=submit], button[type=submit]")) return true;
  if (el.matches("button") && el.closest("form") && (!el.getAttribute("type") || el.type === "submit")) {
    return true;
  }
  const label = `${el.innerText || ""} ${el.value || ""}`.toLowerCase();
  if (!findPasswordField()) return false;
  return /inscri|sign.?up|register|cr[ée]er un compte|create account|continuer|continue|next|suivant|log ?in|connexion|sign in|s.identifier/.test(
    label
  );
}

document.addEventListener(
  "submit",
  () => {
    setTimeout(maybeOfferSave, 80);
  },
  true
);

document.addEventListener(
  "click",
  (event) => {
    const target = event.target instanceof Element ? event.target.closest("button, input, [role=button]") : null;
    if (!target || !isSubmitControl(target)) return;
    setTimeout(maybeOfferSave, 80);
  },
  true
);

async function restorePendingSave() {
  try {
    const stored = await chrome.storage?.session?.get("pendingSave");
    const pending = stored?.pendingSave;
    if (!pending || pending.domain !== pageDomain()) return;
    if (Date.now() - (pending.at || 0) > 120000) {
      await chrome.storage.session.remove("pendingSave");
      return;
    }
    if (sessionStorage.getItem(dismissKey(pending.username))) return;
    showSaveBar(pending);
  } catch (_) {}
}

setTimeout(restorePendingSave, 600);

