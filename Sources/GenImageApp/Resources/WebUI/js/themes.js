export const themes = ["violet", "ocean", "forest", "sunset", "graphite", "rose"];

let currentTheme = localStorage.getItem("genimage.theme") || "violet";

export function getTheme() {
  return currentTheme;
}

export function setTheme(theme) {
  if (!themes.includes(theme)) return;
  currentTheme = theme;
  localStorage.setItem("genimage.theme", theme);
  document.documentElement.dataset.theme = theme;
}

document.documentElement.dataset.theme = currentTheme;
