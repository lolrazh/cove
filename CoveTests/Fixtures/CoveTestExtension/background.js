// Counts the pages the content script reports, keeps the count in storage,
// and shows it on the extension's button. Remembers the last tab selected,
// so tests can see tab events arrive.

async function showCount() {
  const { visits = 0 } = await browser.storage.local.get("visits");
  await browser.action.setBadgeText({ text: visits ? String(visits) : "" });
}

browser.runtime.onInstalled.addListener(showCount);
browser.runtime.onStartup.addListener(showCount);

browser.runtime.onMessage.addListener(async (message) => {
  if (message.type === "visited") {
    const { visits = 0 } = await browser.storage.local.get("visits");
    await browser.storage.local.set({ visits: visits + 1, lastVisited: message.url });
    await showCount();
    return { visits: visits + 1 };
  }
  if (message.type === "reset") {
    await browser.storage.local.set({ visits: 0 });
    await showCount();
    return { visits: 0 };
  }
});

browser.tabs.onActivated.addListener(async ({ tabId }) => {
  const tab = await browser.tabs.get(tabId);
  await browser.storage.local.set({ lastActivated: tab.title || tab.url || "" });
});
