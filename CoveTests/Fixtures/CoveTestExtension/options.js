// The options page reads the same storage as the popup.

browser.storage.local.get("visits").then(({ visits = 0 }) => {
  document.getElementById("visits").textContent = visits;
});
