import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  async redirects() {
    return [
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
