# Content Blocking Implementation Plan

## Steps

### Step 1: Bundle the filter list
- Download `easylist_min_content_blocker.json` (~28k rules, pre-converted for WebKit)
- Add to `Vayu/Resources/`
- Sanity check: file exists in bundle at runtime

### Step 2: Create ContentBlockerManager
- Singleton, @MainActor
- `load()` — lookup cached compiled rules, compile from bundled JSON if cache miss
- Stores compiled `WKContentRuleList` in memory
- Sanity check: rules compile without error, log rule count

### Step 3: Wire into WKWebView
- WebViewModel.init calls `ContentBlockerManager.shared.attach(to: config.userContentController)`
- Rules applied before first page load
- Sanity check: visit ad-heavy site (e.g. cnn.com), compare with/without blocking

### Step 4: Toggle in NavigationBar
- Shield icon button next to downloads — toggles blocking on/off for current tab
- Visual state: filled = blocking on, outline = off
- Sanity check: toggle works, page reloads with/without rules

### Step 5: Commit, push, test end-to-end
- Final verification on multiple sites
- Clean up plan file
