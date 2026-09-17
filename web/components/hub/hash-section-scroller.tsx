"use client";

import { useEffect } from "react";

/** Re-apply hash targets after paint — App Router can miss `/#eligible` on load. */
export function HashSectionScroller() {
  useEffect(() => {
    const id = window.location.hash.replace(/^#/, "");
    if (!id) return;

    const scroll = () => {
      document.getElementById(id)?.scrollIntoView({ block: "start" });
    };

    scroll();
    const frame = window.requestAnimationFrame(scroll);
    return () => window.cancelAnimationFrame(frame);
  }, []);

  return null;
}
