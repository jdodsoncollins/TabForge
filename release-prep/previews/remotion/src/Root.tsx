import React from "react";
import { Composition } from "remotion";
import { AppPreview, AppPreviewProps } from "./AppPreview";
import { previews } from "./previews";

const FPS = 30;
const seconds = (p: AppPreviewProps) => p.clips.reduce((sum, c) => sum + Math.round((c.to - c.from) * FPS) + Math.round((c.hold ?? 0) * FPS), 0);

export const RemotionRoot: React.FC = () => (
  <>
    {previews.map((p) => (
      <Composition
        key={p.id}
        id={p.id}
        component={AppPreview}
        width={p.width}
        height={p.height}
        fps={FPS}
        durationInFrames={seconds(p.props)}
        defaultProps={p.props}
      />
    ))}
  </>
);
