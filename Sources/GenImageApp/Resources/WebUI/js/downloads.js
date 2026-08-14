import { renderModelCard } from "./models.js";
import { t } from "./i18n.js";

const activePhases = new Set(["queued", "downloading", "paused", "verifying", "failed"]);

export function renderDownloads(state) {
  const active = sortModels(
    state.models.filter(({ installation }) => activePhases.has(installation.phase)),
  );
  const completed = sortModels(
    state.models.filter(({ installation }) => installation.phase === "installed"),
  );

  return `
    <section class="page download-center-page">
      <header class="page-header">
        <div class="page-header-copy">
          <h1>${t("download.title")}</h1>
          <p>${t("download.subtitle")}</p>
        </div>
      </header>
      <div class="page-scroll download-center-scroll" data-scroll-id="downloads">
        ${downloadSection("active", t("download.active"), active, t("download.activeEmpty"))}
        ${downloadSection("completed", t("download.completed"), completed, t("download.completedEmpty"))}
      </div>
    </section>
  `;
}

function downloadSection(kind, title, models, emptyMessage) {
  return `
    <section class="download-section download-section-${kind}">
      <header class="download-section-header">
        <h2>${title}</h2>
        <span class="badge">${t("download.count", { count: models.length })}</span>
      </header>
      <div class="download-section-body">
        ${
          models.length
            ? `<div class="card-grid">${models.map(renderModelCard).join("")}</div>`
            : `<div class="download-empty">${emptyMessage}</div>`
        }
      </div>
    </section>
  `;
}

function sortModels(models) {
  return [...models].sort((left, right) =>
    left.descriptor.displayName.localeCompare(right.descriptor.displayName),
  );
}
