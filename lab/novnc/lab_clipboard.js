// AICE2011 clipboard glue for noVNC.
//
// The supported way to move text between the lab and your computer is noVNC's
// own Clipboard panel -- the clipboard icon in the toolbar at the top right.
// That works in every browser because it is just a textarea: pasting into a
// text field needs no permission at all. This file does not replace it. It
// does three small things around it:
//
//   1. Points people at it. Every attempt at automatic clipboard syncing for
//      a noVNC page has failed, and it fails silently, which is worse than
//      not offering it. A badge in the corner names the panel so nobody has
//      to find it by accident.
//
//   2. Makes one direction free. Pressing Ctrl+V over the desktop also sends
//      what you pasted to the container's clipboard, so a later Ctrl+V in
//      another window works. A paste event needs no permission in any browser.
//
//   3. Reports honestly. window.aiceLabClipboard says whether the page is a
//      secure context and whether the Clipboard API is even available, which
//      is the thing that silently breaks automatic syncing.
//
// Why automatic syncing is not offered:
//
//   Reading the clipboard needs permission, which Firefox and Safari do not
//   implement at all. Writing needs *transient user activation* -- a real
//   click or key press -- so a clipboard event arriving over VNC can never
//   write to the browser clipboard on its own; writeText() throws
//   NotAllowedError every time. There is no way around this from a page.
//   Guacamole and KasmVNC hit the identical wall, which is why the panel is
//   the documented path rather than a fallback.
//
// IMPORTANT -- why this file is a module, and why it must stay one:
//
// noVNC 1.7.0's app/ui.js ends with "export default UI", and vnc.html pulls it
// in with an inline <script type="module">import UI from "./app/ui.js"</script>.
// UI is therefore a module-scoped binding. It is never assigned to window.UI --
// that name appears nowhere in noVNC 1.7.0. A plain script reading window.UI
// gets undefined, every guard in it silently bails out, and the result looks
// exactly like a clipboard that does not work. Importing UI is the only way in.
//
// Keep this defensive: it must never break the page.

import UI from "./app/ui.js";

const status = {
    attached: false,
    secureContext: window.isSecureContext,
    clipboardApi: !!(navigator.clipboard && navigator.clipboard.writeText),
    pastesSent: 0,
    lastSent: null,
};
window.aiceLabClipboard = status;

let attachedTo = null;
let badge = null;

function log(message) {
    if (window.console && console.debug) {
        console.debug("[aice2011] " + message);
    }
}

// The badge. Its job is to make the panel discoverable rather than something
// people have to go looking for, and to stop clipboard problems being silent.
function ensureBadge() {
    if (badge && badge.isConnected) { return badge; }

    badge = document.createElement("div");
    badge.id = "aice-clipboard-badge";
    const style = document.createElement("style");
    style.textContent =
        "#aice-clipboard-badge{" +
        "position:fixed;left:8px;bottom:8px;z-index:99999;" +
        "font:12px/1.4 sans-serif;color:#dfe6e9;background:rgba(44,62,80,.92);" +
        "border:1px solid #5d6d7e;border-radius:4px;padding:4px 8px;" +
        "cursor:pointer;user-select:none;}" +
        "#aice-clipboard-badge.hot{border-color:#f39c12;color:#f8c471;}";
    document.head.appendChild(style);
    document.body.appendChild(badge);

    badge.addEventListener("click", function () {
        openPanel();
    });
    return badge;
}

// Reuse noVNC's own panel rather than inventing another one.
function openPanel() {
    const button = document.getElementById("noVNC_clipboard_button");
    if (button) {
        button.click();
        const box = document.getElementById("noVNC_clipboard_text");
        if (box) { box.focus(); }
    }
}

function describe() {
    if (!status.clipboardApi) {
        return ["clipboard: use the clipboard icon in the toolbar", ""];
    }
    return ["clipboard: use the clipboard icon in the toolbar", ""];
}

function refreshBadge() {
    const [text, cls] = describe();
    const el = ensureBadge();
    el.textContent = text;
    el.className = cls;
}

// Copying inside the lab fills noVNC's panel on its own. Flash the badge so
// people notice there is something to copy out.
function noteContainerCopy() {
    const el = ensureBadge();
    el.textContent = "clipboard: text ready - click to open the panel";
    el.className = "hot";
    setTimeout(refreshBadge, 4000);
}

// ---------------------------------------------------------------------------
// browser -> container
// ---------------------------------------------------------------------------

function toContainer(text) {
    const rfb = UI.rfb;
    if (!rfb || !rfb.clipboardPasteFrom) { return false; }
    rfb.clipboardPasteFrom(text);
    status.pastesSent += 1;
    status.lastSent = text;
    return true;
}

// Capture phase so nothing downstream can swallow it. Deliberately no
// preventDefault: Ctrl+V over the desktop must still reach the application
// that has focus inside the lab.
document.addEventListener("paste", function (event) {
    const data = event.clipboardData;
    if (!data) { return; }
    const text = data.getData("text/plain");
    if (typeof text !== "string" || text === "") { return; }

    if (toContainer(text)) {
        log("pasted text on to the container clipboard");
    }
}, true);

// ---------------------------------------------------------------------------
// Session wiring
// ---------------------------------------------------------------------------

function attach() {
    if (!UI.rfb || UI.rfb === attachedTo) { return; }

    // Fires whenever anything in the lab is copied, which is our cue to tell
    // the student there is something waiting.
    UI.rfb.addEventListener("clipboard", noteContainerCopy);
    attachedTo = UI.rfb;

    if (!status.attached) {
        status.attached = true;
        document.title = (document.title || "noVNC") + " - clipboard ready";
        log("clipboard glue attached to the VNC session");
    }
    refreshBadge();
}

setInterval(attach, 1000);
attach();
refreshBadge();
log("clipboard glue loaded; secure context=" + status.secureContext);