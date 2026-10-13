// AICE2011 clipboard sync for noVNC.
//
// noVNC can carry clipboard text over the VNC connection in both directions,
// but it only moves it when you use its Clipboard panel by hand. Upstream has
// an open pull request for automatic syncing that has never been merged, so
// this does that job instead.
//
// What it does:
//
//   container -> browser   Anything copied inside the container (Ctrl+C in a
//                          terminal) is written straight to your browser's
//                          clipboard.
//
//   browser -> container   When you click back into the browser tab, your
//                          browser's clipboard is pushed into the container,
//                          so Ctrl+V pastes it there.
//
// Both directions need browser permission that only Chrome and Edge grant
// reliably, and the browser must consider the page focused. If either refuses,
// this stays silent and noVNC's own Clipboard panel (the clipboard icon in
// toolbar, top right) still works exactly as it always did.
//
// Loaded by vnc.html. Keep it defensive: it must never break the page.

(function () {
    "use strict";

    if (window.AICELAB_CLIPBOARD) { return; }
    window.AICELAB_CLIPBOARD = true;

    // Keep the last text we saw coming from the container, so that switching
    // to the browser does not push a stale value back the other way.
    var lastFromServer = null;
    var attachedTo = null;

    function log(message) {
        if (window.console && console.debug) {
            console.debug("[aice2011] " + message);
        }
    }

    function canRead() {
        return !!(navigator.clipboard && navigator.clipboard.readText);
    }

    function canWrite() {
        return !!(navigator.clipboard && navigator.clipboard.writeText);
    }

    function mirrorToPanel(text) {
        // Keep noVNC's own panel showing the same thing, so the manual route
        // and the automatic route never disagree.
        try {
            var box = document.getElementById("noVNC_clipboard_text");
            if (box && box.value !== text) { box.value = text; }
        } catch (e) { /* the panel is optional */ }
    }

    function onServerClipboard(event) {
        var text = event && event.detail ? event.detail.text : null;
        if (typeof text !== "string" || text === "") { return; }

        lastFromServer = text;
        mirrorToPanel(text);

        if (!canWrite()) { return; }
        navigator.clipboard.writeText(text).then(function () {
            log("copied from container to browser");
        }).catch(function () {
            // Permission denied, or the document is not focused. Expected
            // often enough that it is not worth surfacing to the student.
        });
    }

    function pushBrowserToContainer() {
        if (!canRead()) { return; }

        var ui = window.UI;
        if (!ui || !ui.rfb || !ui.rfb.clipboardPasteFrom) { return; }

        navigator.clipboard.readText().then(function (text) {
            if (typeof text !== "string" || text === "") { return; }
            // Don't bounce the container's own last copy straight back.
            if (text === lastFromServer) { return; }
            ui.rfb.clipboardPasteFrom(text);
            mirrorToPanel(text);
            log("pushed browser clipboard into container");
        }).catch(function () {
            // Needs permission, or the page is not focused.
        });
    }

    function attach() {
        var ui = window.UI;
        if (!ui || !ui.rfb) { return; }
        if (ui.rfb === attachedTo) { return; }

        ui.rfb.addEventListener("clipboard", onServerClipboard);
        attachedTo = ui.rfb;
        log("attached to the VNC session");
    }

    // noVNC replaces UI.rfb on every reconnect, so poll rather than hooking
    // once at load. The interval stops itself once a session is attached,
    // because reconnects raise the "clipboard" listener question again -- so
    // in practice it keeps running at a cheap rate.
    setInterval(attach, 1000);
    attach();

    // Clicking back into the browser tab is the moment the student almost
    // always wants their host clipboard available on the far side.
    window.addEventListener("focus", pushBrowserToContainer);
    document.addEventListener("visibilitychange", function () {
        if (!document.hidden) { pushBrowserToContainer(); }
    });

    log("clipboard sync loaded");
})();