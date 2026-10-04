import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  async redirects() {
    return [
      { source: "/mint", destination: "/", permanent: true },
      { source: "/mint/:path*", destination: "/", permanent: true },
      { source: "/arcade", destination: "/", permanent: true },
      { source: "/arcade/:path*", destination: "/", permanent: true },
      { source: "/eligible", destination: "/", permanent: true },
      { source: "/eligible/:path*", destination: "/", permanent: true },
      { source: "/app", destination: "/", permanent: true },
      { source: "/app/:path*", destination: "/", permanent: true },
      { source: "/dial", destination: "/how", permanent: true },
      { source: "/dial/:path*", destination: "/how", permanent: true },
      {
        source: "/art/test/:id.gif",
        destination: "/art/examples/awake/:id.gif",
        permanent: true,
      },
      {
        source: "/art/test-egg/:id.gif",
        destination: "/art/examples/egg/:id.gif",
        permanent: true,
      },
    ];
  },
  async headers() {
    return [
      {
        source: "/art/:path*",
        headers: [
          { key: "Access-Control-Allow-Origin", value: "*" },
          { key: "Cache-Control", value: "public, max-age=86400" },
        ],
      },
      {
        source: "/metadata/:path*",
        headers: [
          { key: "Access-Control-Allow-Origin", value: "*" },
          { key: "Cache-Control", value: "public, max-age=3600" },
        ],
      },
    ];
  },
};

export default nextConfig;
