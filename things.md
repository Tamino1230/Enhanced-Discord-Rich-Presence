
---

## Architecture Notes For Proper Multi-Browser Support

The current codebase is already split into two layers:

1. The extension layer detects tabs, pages, playback, and browsing state.
2. The native bridge layer owns the Discord IPC connection and sends Rich Presence updates.

That split is the correct place to solve both of the problems you described, but the lock must live in the native layer, not only in browser memory.

### 1) Make the first browser instance lock the service

Right now, the bridge stores selection in memory only. That works inside a single native process, but it does not coordinate Firefox and Chromium at the same time. If both browsers are open, each browser can spawn its own native host process, and each process can believe it owns the same service.

To make the first browser lock a service until it is closed or disabled, use a shared ownership record that all native host processes can see.

Recommended design:

1. Generate a stable browser instance ID in the extension and store it in extension storage.
2. Include that ID in every native message that claims or refreshes a service.
3. In the native app, keep a persistent lock table for each service, such as YouTube, YouTube Music, and Custom RPC.
4. Store each lock with these fields:
  - browser instance ID
  - tab ID
  - service name
  - timestamp of the last heartbeat
  - optional browser type and profile metadata for diagnostics
5. When a browser claims a service:
  - if no lock exists, grant it
  - if the lock exists for the same browser and tab, renew it
  - if the lock exists for a different browser, reject the claim unless the old lock is stale
6. Release the lock when:
  - the tab closes
  - the user disables that service in the popup
  - the browser tells the native app that the tab stopped playing or browsing
  - the extension unloads cleanly
7. Add a stale-lock timeout so a crashed browser does not hold the service forever.

The key point is that the lock needs to be shared across native host processes.
If the lock exists only inside memory in [App/bridge.py](App/bridge.py), Firefox and Chrome will still race each other.

For true Windows, Linux, and macOS support, the shared lock should live in a cross-platform location, for example:

- Windows: a lock file or mutex under the user profile or app data folder
- Linux: a lock file under XDG state or config directories
- macOS: a lock file under Application Support

A lock file is usually simpler to debug than a named mutex, especially if you want the same implementation pattern across all operating systems.

### 2) Make ownership browser-specific instead of tab-random

The browser side should decide which tab is allowed to represent a service inside that browser profile, but it should not decide the global winner across browsers.

That means you want two separate concepts:

1. Browser-local selection
2. Native global ownership

Browser-local selection is what you already see in the popup flow and the content scripts. Global ownership is the native lock.

Practical rule:

- The first eligible tab in a browser claims the browser-local selection.
- The native app grants ownership only if the service is not already owned by another browser instance.
- If the selected tab closes, the browser releases the lock and another browser can claim it again.

This avoids random flips when both browsers are active, while still allowing each browser to reclaim the service naturally when the previous owner disappears.

### 3) Show "streaming to Discord" only after real IPC success

The current broadcast popup is only a UI confirmation that the page sent data to the background script. It is not yet a proof that Discord accepted the activity.

If you want a notification that truly means "Discord took it", the confirmation needs to come from the native bridge after the IPC exchange succeeds.

The clean implementation is:

1. The extension sends a claim or update request to the native bridge.
2. The native bridge writes the Discord IPC frame.
3. The native bridge waits for a valid response from Discord or at least a confirmed non-error IPC reply.
4. Only after that confirmation does the native bridge emit a success message back to the extension.
5. The extension shows a non-blocking popup or toast such as "Streaming to Discord".

Important detail:

- Do not block the UI thread.
- Do not block the content script.
- Do not block the browser action popup.

The success check should run asynchronously in the native bridge, with a short timeout and a failure path.
If the IPC write fails, the pipe disconnects, or the response never arrives, show nothing or show a quieter failure state.

If you want the most accurate version of this feature, the native bridge should keep a reader loop on the Discord IPC pipe and correlate the response with the request it just sent.
If you do not want to maintain a response loop, the fallback is to treat "pipe connected + write succeeded" as a soft success, but that is weaker than a true confirmation.

### 4) Where this should be wired in the current codebase

The practical implementation points are already visible in the repository:

- [App/bridge.py](App/bridge.py) owns the selection map and the Discord IPC write path.
- [Extension/background.js](Extension/background.js) routes sync, select, and tab-close messages.
- [Extension/Activities/Youtube/handler.js](Extension/Activities/Youtube/handler.js) and [Extension/Activities/YoutubeMusic/handler.js](Extension/Activities/YoutubeMusic/handler.js) decide when a tab becomes active or should request sync.
- [Extension/content.js](Extension/content.js) already renders in-page toast and broadcast UI.

That means the best long-term shape is:

1. Keep page detection in the content scripts.
2. Keep routing and popup gating in the background script.
3. Add the lock and Discord confirmation in the native bridge.
4. Send one small success message back to the extension only after the bridge confirms the activity.

### 5) What to improve next beyond those two features

If you are aiming for a production-quality cross-platform extension, the next improvements worth doing are:

1. Add a diagnostics view that shows the current owner browser, selected tab, native bridge status, and last IPC confirmation.
2. Add stale-lock recovery so a crash or forced browser close does not leave a service stuck.
3. Add explicit service ownership status in the popup, so users can see whether YouTube, YouTube Music, or Custom RPC is currently claimed.
4. Add platform adapters for browser identity and lock storage so the same behavior works on Windows, Linux, and macOS.
5. Add a lightweight event log for connection failures, selection changes, and ownership handoffs.
6. Keep the success popup optional, because some users will want activity updates without extra UI noise.

### 6) Recommended portability plan

If you want this project to work well in Chromium-based browsers and Gecko-based browsers across Windows, Linux, and macOS, the safest path is:

1. Keep the browser extension logic browser-agnostic by using the standard WebExtension APIs.
2. Avoid any browser-specific assumptions in the popup or content scripts.
3. Put all cross-browser arbitration into the native app.
4. Store persistent lock data in a location that is shared across browser launches on the same machine.
5. Treat the browser extension as a client, not as the source of truth.
6. Use timeouts and heartbeats so stale owners automatically expire.
7. Design the native host so it can recover cleanly after browser crashes, OS sleep, or Discord restarts.

If you follow that shape, Chrome, Firefox, and future Chromium or Gecko browsers can all participate without the selection becoming random.