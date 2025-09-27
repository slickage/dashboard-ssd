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

  // Only set up toggle functionality if elements exist (settings page)
  const themeToggle = document.getElementById('theme-toggle');
  const themeLabel = document.getElementById('theme-label');

  if (themeToggle && themeLabel) {
    // Get current theme from the HTML attribute (set by inline script)
    const currentTheme = html.getAttribute('data-theme') || 'dark';
    updateToggleUI(currentTheme);

    // Toggle theme on button click
    themeToggle.addEventListener('click', () => {
      const currentTheme = html.getAttribute('data-theme');
      const newTheme = currentTheme === 'dark' ? 'light' : 'dark';

      html.setAttribute('data-theme', newTheme);
      localStorage.setItem('theme', newTheme);
      updateToggleUI(newTheme);
    });
  }

  function updateToggleUI(theme) {
    const toggle = themeToggle.querySelector('span:last-child');
    if (theme === 'light') {
      toggle.classList.remove('translate-x-1');
      toggle.classList.add('translate-x-6');
      themeLabel.textContent = 'Light';
    } else {
      toggle.classList.remove('translate-x-6');
      toggle.classList.add('translate-x-1');
      themeLabel.textContent = 'Dark';
    }
  }
}

// Initialize theme when DOM is ready
document.addEventListener('DOMContentLoaded', initTheme);

// Also initialize on LiveView navigation
document.addEventListener('phx:page-loading-stop', initTheme);

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

