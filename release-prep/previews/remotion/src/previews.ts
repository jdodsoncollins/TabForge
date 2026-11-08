import { AppPreviewProps } from "./AppPreview";

// Times are seconds in each native Simulator recording (public/*-take.mp4).
// Each cut starts about half a second before the key's visible effect, so the
// preview opens on the action. Beats are seconds in the finished preview.
const phone = { width: 1206, height: 2622 };
const ipad = { width: 1668, height: 2420 };
const duo = { width: 1398, height: 2034 };

export type PreviewSpec = { id: string; width: number; height: number; props: AppPreviewProps };

export const previews: PreviewSpec[] = [
  {
    id: "iPhone-Editing", width: 886, height: 1920,
    props: {
      src: "phone-take.mp4", screen: phone, radius: 0.13, title: "Edit code without\nleaving the keys",
      clips: [{ from: 90.5, to: 93.8 }, { from: 94.7, to: 98.5 }, { from: 100.9, to: 103.9 }, { from: 104.9, to: 107.9 }, { from: 108.95, to: 112.5 }],
      beats: [{ at: 0.45, label: "Tab indents the line" }, { at: 3.6, label: "⌘ → jumps to the line end" }, { at: 7.6, label: "Return keeps the indent" }, { at: 10.6, label: "Outdent steps back" }, { at: 13.6, label: "Brackets close themselves" }],
    },
  },
  {
    id: "iPhone-Themes", width: 886, height: 1920,
    props: {
      src: "themes-phone-take.mp4", screen: phone, radius: 0.13, title: "Light, dark or\na code theme",
      clips: [{ from: 35.2, to: 38.7 }, { from: 41.3, to: 43.0 }, { from: 49.9, to: 51.4 }, { from: 56.4, to: 59.4 }, { from: 64.0, to: 65.4 }, { from: 67.7, to: 69.0 }, { from: 71.2, to: 75.0 }],
      beats: [{ at: 0, label: "Light glass, like the iOS keyboard" }, { at: 1.4, label: "Follows dark mode live" }, { at: 3.6, label: "Pick a theme from the gear" }, { at: 7.1, label: "Darcula" }, { at: 9.8, label: "Choose an input profile" }, { at: 12.75, label: "Terminal · ANSI" }],
    },
  },
  {
    id: "iPad-Editing", width: 1200, height: 1600,
    props: {
      src: "ipad-take.mp4", screen: ipad, radius: 0.025, title: "Edit code without\nleaving the keys",
      clips: [{ from: 100.25, to: 103.4 }, { from: 104.45, to: 107.6 }, { from: 108.45, to: 111.6 }, { from: 112.9, to: 116.6 }, { from: 119.05, to: 122.3 }],
      beats: [{ at: 0.5, label: "Outdent moves the line left" }, { at: 3.7, label: "Tab moves it back" }, { at: 6.8, label: "Delete line removes it" }, { at: 9.9, label: "⌘ → jumps to the line end" }, { at: 13.7, label: "Return keeps the indent" }],
    },
  },
  {
    id: "iPad-Themes", width: 1200, height: 1600,
    props: {
      src: "themes-ipad-take.mp4", screen: ipad, radius: 0.025, title: "Light, dark or\na code theme",
      clips: [{ from: 33.4, to: 36.9 }, { from: 39.6, to: 41.4 }, { from: 48.8, to: 52.8 }, { from: 57.2, to: 58.8 }, { from: 65.9, to: 67.9 }, { from: 72.1, to: 72.74, hold: 2.26, holdImage: "themes-ipad-hold.png" }],
      beats: [{ at: 0, label: "Light glass, like the iOS keyboard" }, { at: 1.3, label: "Follows dark mode live" }, { at: 3.6, label: "Pick a theme from the gear" }, { at: 6.55, label: "Darcula" }, { at: 9.4, label: "Choose an input profile" }, { at: 13.2, label: "Terminal · ANSI" }],
    },
  },
  {
    id: "Duo-Editing", width: 886, height: 1920,
    props: {
      src: "duo-take.mp4", screen: duo, radius: 0.04, title: "Edit code without\nleaving the keys",
      clips: [{ from: 53.3, to: 56.4 }, { from: 56.9, to: 59.6 }, { from: 60.35, to: 64.4 }, { from: 66.35, to: 72.0 }],
      beats: [{ at: 0.45, label: "[ adds the closing bracket" }, { at: 3.55, label: "] steps over it" }, { at: 6.25, label: "⌘ ← jumps to the line start" }, { at: 10.3, label: "⌘ → jumps to the line end" }],
    },
  },
  {
    id: "Duo-Themes", width: 886, height: 1920,
    props: {
      src: "themes-duo-take.mp4", screen: duo, radius: 0.04, title: "Light, dark or\na code theme",
      clips: [{ from: 46.6, to: 50.1 }, { from: 54.0, to: 55.6 }, { from: 60.1, to: 61.5 }, { from: 67.0, to: 70.0 }, { from: 75.8, to: 77.2 }, { from: 80.8, to: 82.2 }, { from: 86.9, to: 90.9 }],
      beats: [{ at: 0, label: "Light glass, like the iOS keyboard" }, { at: 1.35, label: "Follows dark mode live" }, { at: 3.6, label: "Pick a theme from the gear" }, { at: 6.9, label: "Darcula" }, { at: 9.6, label: "Choose an input profile" }, { at: 12.65, label: "Terminal · ANSI" }],
    },
  },
];
