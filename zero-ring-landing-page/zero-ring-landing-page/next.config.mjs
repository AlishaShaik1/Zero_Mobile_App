/** @type {import('next').NextConfig} */
const nextConfig = {
  devIndicators: false,
  typescript: {
    ignoreBuildErrors: true,
  },
  images: {
    unoptimized: true,
  },
  turbopack: {
    root: process.cwd(),
  },
  webpack(config, { isServer }) {
    config.resolve.extensionAlias = {
      ...config.resolve.extensionAlias,
      '.js': ['.ts', '.tsx', '.js', '.jsx'],
    };
    if (!isServer) {
      config.resolve.alias = {
        ...config.resolve.alias,
        "sharp$": false,
        "onnxruntime-node$": false,
      }
      config.resolve.fallback = {
        ...config.resolve.fallback,
        fs: false,
        "node:fs": false,
        path: false,
        "node:path": false,
        stream: false,
        "node:stream": false,
        crypto: false,
        "node:crypto": false,
        os: false,
        "node:os": false,
      };
    }
    return config;
  },
}

export default nextConfig
