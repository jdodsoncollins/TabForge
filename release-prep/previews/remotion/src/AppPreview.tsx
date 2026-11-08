import React from "react";
import {
  AbsoluteFill,
  OffthreadVideo,
  Img,
  Series,
  interpolate,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";

export type Clip = { from: number; to: number; /** Seconds to hold a still of the clip's last frame (the app quit right after), from holdImage. */ hold?: number; holdImage?: string };
export type Beat = { at: number; label: string };
export type AppPreviewProps = {
  src: string;
  clips: Clip[];
  /** Native capture size in pixels, used to keep the screen's real proportions. */
  screen: { width: number; height: number };
  title: string;
  beats: Beat[];
  /** Corner radius of the screen as a fraction of its width. */
  radius: number;
};

const TEXT = "#1D1D1F";
const SECONDARY = "#6E6E73";
const BACKGROUND = "#F2F2F4";

// The genuine app screen from a native Simulator recording, at normal speed
// with straight cuts, as in the October previews. New for 1.1.1: the listing's
// plain background, a headline, and a caption naming the key being pressed.
export const AppPreview: React.FC<AppPreviewProps> = ({ src, clips, screen, title, beats, radius }) => {
  const frame = useCurrentFrame();
  const { fps, width, height } = useVideoConfig();
  const unit = Math.min(width, height) / 1000;
  // A squarer canvas (iPad, 3:4) gets a smaller header so the screen stays large.
  const square = width / height > 0.6;
  const top = (square ? 56 : 92) * unit;
  const titleSize = (square ? 58 : 74) * unit;
  const captionSize = (square ? 32 : 40) * unit;
  const headerHeight = top + titleSize * 1.08 * 2 + 30 * unit + captionSize * 1.4 + (square ? 36 : 56) * unit;
  const bottom = (square ? 44 : 60) * unit;
  const maxW = width - 2 * 60 * unit;
  const maxH = height - headerHeight - bottom;
  const scale = Math.min(maxW / screen.width, maxH / screen.height);
  const w = screen.width * scale;
  const h = screen.height * scale;
  const seconds = frame / fps;
  const active = [...beats].reverse().find((b) => seconds >= b.at);
  const next = beats.find((b) => b.at > seconds);
  const fadeIn = active ? interpolate(seconds - active.at, [0, 0.25], [0, 1], { extrapolateRight: "clamp" }) : 0;
  const fadeOut = next ? interpolate(next.at - seconds, [0, 0.2], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }) : 1;
  return (
    <AbsoluteFill style={{ backgroundColor: BACKGROUND, fontFamily: "-apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Helvetica Neue', sans-serif", WebkitFontSmoothing: "antialiased" }}>
      <div style={{ position: "absolute", top: top + (maxH - h) / 2, left: 50 * unit, right: 50 * unit, textAlign: "center" }}>
        <div style={{ fontSize: titleSize, fontWeight: 700, lineHeight: 1.08, letterSpacing: "-0.025em", color: TEXT, whiteSpace: "pre-line" }}>{title}</div>
        <div style={{ marginTop: 30 * unit, height: captionSize * 1.4, fontSize: captionSize, fontWeight: 600, lineHeight: 1.4, color: SECONDARY, opacity: fadeIn * fadeOut, transform: `translateY(${(1 - fadeIn) * 8 * unit}px)` }}>
          {active?.label ?? ""}
        </div>
      </div>
      <div
        style={{
          position: "absolute",
          left: (width - w) / 2,
          top: headerHeight + (maxH - h) / 2,
          width: w,
          height: h,
          borderRadius: radius * w,
          overflow: "hidden",
          backgroundColor: "black",
          boxShadow: `0 ${18 * unit}px ${44 * unit}px rgba(0,0,0,.16), 0 0 0 ${1.5 * unit}px rgba(0,0,0,.08)`,
        }}
      >
        <Series>
          {clips.flatMap((clip, index) => {
            const video = (
              <OffthreadVideo
                src={staticFile(src)}
                trimBefore={Math.round(clip.from * fps)}
                trimAfter={Math.round(clip.to * fps)}
                muted
                style={{ width: "100%", height: "100%", objectFit: "cover" }}
              />
            );
            const length = Math.round((clip.to - clip.from) * fps);
            const parts = [<Series.Sequence key={`${index}`} durationInFrames={length}>{video}</Series.Sequence>];
            if (clip.hold) {
              parts.push(
                <Series.Sequence key={`${index}-hold`} durationInFrames={Math.round(clip.hold * fps)}>
                  <Img src={staticFile(clip.holdImage ?? "")} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
                </Series.Sequence>,
              );
            }
            return parts;
          })}
        </Series>
      </div>
    </AbsoluteFill>
  );
};
