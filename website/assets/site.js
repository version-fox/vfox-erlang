/*
 * Copyright 2026 vfox-erlang contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

"use strict";

const labels = JSON.parse(document.body.dataset.copy);
const tabs = [...document.querySelectorAll("[data-tab]")];
const panels = [...document.querySelectorAll("[data-panel]")];
document.body.classList.add("enhanced");
document.querySelector(".manager-tabs").setAttribute("role", "tablist");

function selectManager(tab) {
  for (const item of tabs) {
    const selected = item === tab;
    item.setAttribute("role", "tab");
    item.setAttribute("aria-selected", String(selected));
    item.tabIndex = selected ? 0 : -1;
  }
  for (const panel of panels) {
    panel.setAttribute("role", "tabpanel");
    panel.hidden = panel.dataset.panel !== tab.dataset.tab;
    panel.tabIndex = 0;
  }
}

for (const tab of tabs) {
  tab.addEventListener("click", () => selectManager(tab));
  tab.addEventListener("keydown", (event) => {
    let target;
    if (event.key === "ArrowRight") target = tabs[(tabs.indexOf(tab) + 1) % tabs.length];
    if (event.key === "ArrowLeft") target = tabs[(tabs.indexOf(tab) + tabs.length - 1) % tabs.length];
    if (event.key === "Home") target = tabs[0];
    if (event.key === "End") target = tabs[tabs.length - 1];
    if (target) {
      event.preventDefault();
      selectManager(target);
      target.focus();
    }
  });
}
selectManager(tabs[0]);

for (const button of document.querySelectorAll(".copy-button")) {
  button.addEventListener("click", async () => {
    const code = button.closest(".command-block").querySelector("code").textContent;
    const status = document.getElementById("copy-status");
    try {
      await navigator.clipboard.writeText(code);
      button.textContent = labels.copied;
      status.textContent = labels.copied;
      setTimeout(() => { button.textContent = labels.copy; }, 1800);
    } catch {
      status.textContent = labels.copy_error;
    }
  });
}

// Preserve the section when switching between the fully rendered locale routes.
for (const link of document.querySelectorAll("[data-language]")) {
  link.addEventListener("click", () => {
    const target = new URL(link.getAttribute("href"), location.href);
    target.hash = location.hash;
    link.href = target.href;
  });
}
