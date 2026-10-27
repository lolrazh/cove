// Shows what the extension stored and the active tab, from storage and the
// tabs API, with buttons that write to storage, open the options page and
// ask for an optional permission.

async function render() {
  const { visits = 0, lastActivated = "—" } = await browser.storage.local.get(["visits", "lastActivated"]);
  const [tab] = await browser.tabs.query({ active: true, currentWindow: true });
  document.getElementById("visits").textContent = visits;
  document.getElementById("tab").textContent = tab?.title || tab?.url || "—";
  document.getElementById("activated").textContent = lastActivated;
  const cookies = await browser.permissions.contains({ permissions: ["cookies"] });
  document.getElementById("cookies").textContent = cookies ? "allowed" : "not allowed";
}

document.getElementById("reset").addEventListener("click", async () => {
  await browser.runtime.sendMessage({ type: "reset" });
  await render();
});

document.getElementById("options").addEventListener("click", () => {
  browser.runtime.openOptionsPage();
});

// An optional permission, asked for while running.
document.getElementById("ask").addEventListener("click", async () => {
  await browser.permissions.request({ permissions: ["cookies"] });
  await render();
});

render();
