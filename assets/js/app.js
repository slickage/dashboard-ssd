// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken}
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Handle CSV download events
window.addEventListener("phx:download", (event) => {
  const { data, filename } = event.detail;
  const blob = new Blob([data], { type: "text/csv" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
});

// Theme switching functionality
function initTheme() {
  const html = document.documentElement;

  // Ensure theme is set correctly on initialization
  ensureThemeConsistency();

  // Only set up toggle functionality if elements exist (settings page)
  const themeToggle = document.getElementById('theme-toggle');
  const themeLabel = document.getElementById('theme-label');

  if (themeToggle && themeLabel) {
    // Remove existing event listener to prevent duplicates
    themeToggle.removeEventListener('click', handleThemeToggle);

    // Get current theme and update UI
    const currentTheme = html.classList.contains('dark') ? 'dark' : 'light';
    updateToggleUI(currentTheme);

    // Add theme toggle event listener
    themeToggle.addEventListener('click', handleThemeToggle);
  }
}

function handleThemeToggle() {
  const html = document.documentElement;
  const currentTheme = html.classList.contains('dark') ? 'dark' : 'light';
  const newTheme = currentTheme === 'dark' ? 'light' : 'dark';

  setTheme(newTheme);
  updateToggleUI(newTheme);
}

function ensureThemeConsistency() {
  const html = document.documentElement;
  const savedTheme = localStorage.getItem('theme') || 'dark';
  const currentTheme = html.classList.contains('dark') ? 'dark' : 'light';

  // If theme doesn't match saved preference, update it
  if (currentTheme !== savedTheme) {
    setTheme(savedTheme);
  }
}

function setTheme(theme) {
  const html = document.documentElement;

  if (theme === 'dark') {
    html.classList.add('dark');
  } else {
    html.classList.remove('dark');
  }

  localStorage.setItem('theme', theme);

  // Force a style recalculation to ensure theme applies immediately
  html.style.display = 'none';
  html.offsetHeight; // Trigger reflow
  html.style.display = '';
}

function updateToggleUI(theme) {
  const themeToggle = document.getElementById('theme-toggle');
  const themeLabel = document.getElementById('theme-label');

  if (!themeToggle || !themeLabel) return;

  const toggle = themeToggle.querySelector('span:last-child');
  const track = themeToggle;

  if (theme === 'light') {
    toggle.classList.remove('translate-x-1');
    toggle.classList.add('translate-x-6');
    track.classList.remove('bg-gray-200');
    track.classList.add('bg-theme-surface-muted');
    themeLabel.textContent = 'Light';
  } else {
    toggle.classList.remove('translate-x-6');
    toggle.classList.add('translate-x-1');
    track.classList.remove('bg-theme-surface-muted');
    track.classList.add('bg-gray-200');
    themeLabel.textContent = 'Dark';
  }
}

// Initialize theme when DOM is ready
document.addEventListener('DOMContentLoaded', initTheme);

// Also initialize on LiveView navigation and updates
document.addEventListener('phx:page-loading-stop', initTheme);

// Re-initialize on LiveView updates (when DOM changes)
document.addEventListener('phx:update', initTheme);

// Sticky header behavior
  function initStickyHeader() {
    const header = document.getElementById('sticky-header');
    if (!header) return;

    let lastScrollY = window.scrollY;
    let isScrollingDown = false;

    function updateHeader() {
      const currentScrollY = window.scrollY;
      const scrollingDown = currentScrollY > lastScrollY;

      const isKbPage = document.querySelector('[phx-click-away="close_search_dropdown"]') !== null;
      let searchResultsVisible = false;
      if (isKbPage) {
        searchResultsVisible = document.querySelector('[phx-click-away="close_search_dropdown"] .absolute') !== null;
        if (searchResultsVisible) {
          header.classList.add('no-sticky');
        } else {
          header.classList.remove('no-sticky');
        }
      }

      // Update scroll direction
      if (scrollingDown !== isScrollingDown) {
        isScrollingDown = scrollingDown;

        if (scrollingDown && (!isKbPage || (isKbPage && !searchResultsVisible))) {
          // Scrolling down: let header scroll out of view naturally
          header.classList.add('scrolling');
        } else if (!scrollingDown && (!isKbPage || (isKbPage && !searchResultsVisible))) {
          // Scrolling up: make header sticky again
          header.classList.remove('scrolling');
        }
      }

      lastScrollY = currentScrollY;
    }

    // Set initial state
    updateHeader();

    // Throttle scroll events for better performance
    let ticking = false;
    window.addEventListener('scroll', () => {
      if (!ticking) {
        requestAnimationFrame(() => {
          updateHeader();
          ticking = false;
        });
        ticking = true;
      }
    });
  }

// Initialize sticky header when DOM is ready
document.addEventListener('DOMContentLoaded', initStickyHeader);

// Also initialize on LiveView navigation and updates
document.addEventListener('phx:page-loading-stop', initStickyHeader);
document.addEventListener('phx:update', initStickyHeader);

// OAuth popup handling
window.addEventListener("phx:open_oauth_popup", (event) => {
  const { url } = event.detail;

  // Calculate center position for popup relative to current window
  const popupWidth = 500;
  const popupHeight = 600;

  // Get current window position (cross-browser compatible)
  const screenX = window.screenX || window.screenLeft || 0;
  const screenY = window.screenY || window.screenTop || 0;

  // Get available screen space for current monitor
  const availWidth = window.screen.availWidth || window.screen.width;
  const availHeight = window.screen.availHeight || window.screen.height;

  // Center popup relative to current window position
  const left = screenX + (availWidth - popupWidth) / 2;
  const top = screenY + (availHeight - popupHeight) / 2;

  const popup = window.open(
    url,
    "oauth-popup",
    `width=${popupWidth},height=${popupHeight},left=${left},top=${top},scrollbars=yes,resizable=yes`
  );

  if (popup) {
    // Check if popup is closed every 500ms
    const checkClosed = setInterval(() => {
      if (popup.closed) {
        clearInterval(checkClosed);
        // Reload the page to check if authentication succeeded
        window.location.reload();
      }
    }, 500);
  } else {
    // Fallback if popup was blocked
    window.location.href = url;
  }
});

// Copy to clipboard functionality
window.addEventListener("phx:copy-to-clipboard", (event) => {
  const { text } = event.detail;
  navigator.clipboard.writeText(text).catch(err => {
    console.error('Failed to copy text: ', err);
  });
});

// Flash auto-dismiss hook
let Hooks = {}
Hooks.AutoDismiss = {
  mounted() {
    this.startTimer()
  },
  updated() {
    this.resetTimer()
  },
  destroyed() {
    this.clearTimer()
  },
  startTimer() {
    const delay = parseInt(this.el.dataset.delay) || 5000
    this.timer = setTimeout(() => {
      const connected = this.liveSocket?.isConnected?.() && this.el?.isConnected
      if (connected) {
        this.pushEvent("lv:clear-flash", {key: this.el.dataset.kind})
      }
    }, delay)
  },
  resetTimer() {
    this.clearTimer()
    this.startTimer()
  },
  clearTimer() {
    if (this.timer) {
      clearTimeout(this.timer)
      this.timer = null
    }
  }
}

// connect if there are any LiveViews on the page
liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken}
})
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
