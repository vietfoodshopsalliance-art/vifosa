import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  async rewrites() {
    const backend = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:8080'
    return [
      {
        source: '/_api/:path*',
        destination: `${backend}/:path*`,
      },
    ]
  },
};

export default nextConfig;
