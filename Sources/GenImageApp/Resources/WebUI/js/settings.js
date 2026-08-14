import { escapeHTML } from "./format.js";
import { languages, t } from "./i18n.js";
import { themes } from "./themes.js";

export function renderSettings(state, ui) {
  const localModels = state.models.filter(({ descriptor }) => descriptor.localURL);
  return `
    <section class="page">
      <header class="page-header">
        <div class="page-header-copy">
          <h1>${t("settings.title")}</h1>
          <p>${t("settings.subtitle")}</p>
        </div>
      </header>
      <div class="page-scroll settings-page" data-scroll-id="settings">
        <section class="settings-card">
          <div>
            <h2>${t("settings.general")}</h2>
            <p>${t("settings.languageNote")}</p>
          </div>
          <label class="settings-control">
            <span>${t("settings.language")}</span>
            <select class="field" data-setting="language">
              ${languages.map((language) => `<option value="${language.id}" ${ui.language === language.id ? "selected" : ""}>${language.label}</option>`).join("")}
            </select>
          </label>
        </section>

        <section class="settings-card vertical">
          <div>
            <h2>${t("settings.appearance")}</h2>
            <p>${t("settings.appearanceNote")}</p>
          </div>
          <div class="theme-grid">
            ${themes.map((theme) => `
              <button class="theme-choice ${ui.theme === theme ? "active" : ""}" data-action="selectTheme" data-theme="${theme}">
                <span class="theme-swatch" data-swatch="${theme}"></span>
                <span>${t(`theme.${theme}`)}</span>
              </button>
            `).join("")}
          </div>
        </section>

        <section class="settings-card vertical">
          <div>
            <h2>${t("settings.models")}</h2>
            <p>${t("settings.detectedModels", { count: localModels.length })}</p>
          </div>
          <div class="settings-list">
            ${localModels.map(({ descriptor }) => `<div><strong>${escapeHTML(descriptor.displayName)}</strong><code>${escapeHTML(descriptor.localURL)}</code></div>`).join("")}
          </div>
        </section>

        <section class="settings-card vertical">
          <div>
            <h2>${t("settings.mcp")}</h2>
            <p>${t("settings.mcpNote")}</p>
          </div>
          <label>${t("settings.mcpCommand")}</label>
          <code class="command-box">swift run GenImageMCP</code>
          <p>${t("settings.mcpTools")}</p>
        </section>
      </div>
    </section>
  `;
}
