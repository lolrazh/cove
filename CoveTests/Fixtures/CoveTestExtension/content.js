// Marks the page so a test can see the content script ran, and reports the
// visit to the background script.

document.documentElement.dataset.coveTestExtension = "marked";

const mark = document.createElement("div");
mark.id = "cove-test-extension-mark";
mark.textContent = "Cove Test Extension";
Object.assign(mark.style, {
  position: "fixed",
  right: "12px",
  bottom: "12px",
  zIndex: "2147483647",
  padding: "6px 10px",
  borderRadius: "999px",
  background: "#5b5bd6",
  color: "white",
  font: "600 12px -apple-system, system-ui, sans-serif",
  boxShadow: "0 2px 8px rgba(0, 0, 0, 0.2)",
});
document.body.append(mark);

browser.runtime.sendMessage({ type: "visited", url: location.href }).then(({ visits }) => {
  mark.textContent = `Cove Test Extension · visit ${visits}`;
});
