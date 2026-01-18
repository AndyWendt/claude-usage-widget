/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        sans: [
          "Söhne",
          "-apple-system",
          "BlinkMacSystemFont",
          "SF Pro Text",
          "system-ui",
          "sans-serif",
        ],
      },
      colors: {
        // Anthropic brand palette
        anthropic: {
          // Primary tan/beige
          tan: "#D4A574",
          "tan-light": "#E8D4BC",
          "tan-dark": "#B8956A",
          // Coral accent
          coral: "#E07A5F",
          "coral-light": "#F0A090",
          "coral-dark": "#C66A4F",
          // Background tones
          cream: "#FAF7F2",
          "cream-dark": "#F0EBE3",
          parchment: "#F5F0E8",
          // Dark mode backgrounds
          charcoal: "#2D2A26",
          "charcoal-light": "#3D3A36",
          "charcoal-dark": "#1D1A16",
          // Text colors
          "text-primary": "#1A1915",
          "text-secondary": "#6B6560",
          "text-muted": "#9B9590",
          // For dark mode text
          "text-light": "#FAF7F2",
          "text-light-secondary": "#D4CFC7",
        },
        widget: {
          bg: "rgba(45, 42, 38, 0.85)",
          border: "rgba(212, 165, 116, 0.2)",
          text: "#FAF7F2",
          muted: "rgba(250, 247, 242, 0.6)",
          accent: "#D4A574",
          warning: "#E07A5F",
          danger: "#C66A4F",
        },
      },
    },
  },
  plugins: [],
};
