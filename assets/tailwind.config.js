// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require("tailwindcss/plugin")
const fs = require("fs")
const path = require("path")

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/dashboard_ssd_web.ex",
    "../lib/dashboard_ssd_web/**/*.ex",
    "../lib/dashboard_ssd_web/**/*.heex"
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        brand: "#FD4F00",
        theme: {
          background: "var(--theme-background)",
          surface: "var(--theme-surface)",
          surfaceMuted: "var(--theme-surface-muted)",
          surfaceRaised: "var(--theme-surface-raised)",
          border: "var(--theme-border)",
          primary: "var(--theme-primary)",
          primarySoft: "var(--theme-primary-soft)",
          accent: "var(--theme-accent)",
          text: "var(--theme-text)",
          muted: "var(--theme-text-muted)",
          textActive: "var(--theme-text-active)"
        }
      },
      fontFamily: {
        theme: ["system-ui", "-apple-system", "BlinkMacSystemFont", "'Segoe UI'", "'Oxygen'", "'Ubuntu'", "'Cantarell'", "'Fira Sans'", "'Droid Sans'", "'Helvetica Neue'", "Arial", "sans-serif"],
        sans: ["system-ui", "-apple-system", "BlinkMacSystemFont", "'Segoe UI'", "'Oxygen'", "'Ubuntu'", "'Cantarell'", "'Fira Sans'", "'Droid Sans'", "'Helvetica Neue'", "Arial", "sans-serif"]
      },
      boxShadow: {
        "theme-card": "var(--theme-shadow-card)",
        "theme-soft": "var(--theme-shadow-soft)"
      },
      borderRadius: {
        theme: "24px"
      },
      fontFamily: {
        theme: "var(--theme-font-family)"
      }
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    // Allows prefixing tailwind classes with LiveView classes to add rules
    // only when LiveView classes are applied, for example:
    //
    //     <div class="phx-click-loading:animate-ping">
    //
    plugin(({addVariant}) => addVariant("phx-click-loading", [".phx-click-loading&", ".phx-click-loading &"])),
    plugin(({addVariant}) => addVariant("phx-submit-loading", [".phx-submit-loading&", ".phx-submit-loading &"])),
    plugin(({addVariant}) => addVariant("phx-change-loading", [".phx-change-loading&", ".phx-change-loading &"])),

    // Custom theme utilities
    plugin(function({ addUtilities }) {
      addUtilities({
        '.theme-card': {
          background: 'var(--theme-surface)',
          'border-radius': '24px',
          border: '1px solid var(--theme-border)',
          'box-shadow': 'var(--theme-shadow-card)',
        },
        '.theme-pill': {
          'border-radius': '9999px',
          background: 'rgba(255, 255, 255, 0.04)',
          border: '1px solid rgba(255, 255, 255, 0.12)',
          padding: '0.125rem 0.75rem',
          'font-size': '0.75rem',
          'font-weight': '500',
          color: 'rgba(255, 255, 255, 0.82)',
        },
        '.theme-outline': {
          'border-color': 'var(--theme-border)',
        },
        '.theme-divider': {
          height: '1px',
          width: '100%',
          background: 'linear-gradient(to right, transparent, rgba(255, 255, 255, 0.08), transparent)',
        },
      })
    }),

    // Embeds Heroicons (https://heroicons.com) into your app.css bundle
    // See your `CoreComponents.icon/1` for more information.
    //
    plugin(function({matchComponents, theme}) {
      let iconsDir = path.join(__dirname, "../deps/heroicons/optimized")
      let values = {}
      let icons = [
        ["", "/24/outline"],
        ["-solid", "/24/solid"],
        ["-mini", "/20/solid"],
        ["-micro", "/16/solid"]
      ]
      icons.forEach(([suffix, dir]) => {
        fs.readdirSync(path.join(iconsDir, dir)).forEach(file => {
          let name = path.basename(file, ".svg") + suffix
          values[name] = {name, fullPath: path.join(iconsDir, dir, file)}
        })
      })
      matchComponents({
        "hero": ({name, fullPath}) => {
          let content = fs.readFileSync(fullPath).toString().replace(/\r?\n|\r/g, "")
          let size = theme("spacing.6")
          if (name.endsWith("-mini")) {
            size = theme("spacing.5")
          } else if (name.endsWith("-micro")) {
            size = theme("spacing.4")
          }
          return {
            [`--hero-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
            "-webkit-mask": `var(--hero-${name})`,
            "mask": `var(--hero-${name})`,
            "mask-repeat": "no-repeat",
            "background-color": "currentColor",
            "vertical-align": "middle",
            "display": "inline-block",
            "width": size,
            "height": size
          }
        }
      }, {values})
    })
  ]
}
