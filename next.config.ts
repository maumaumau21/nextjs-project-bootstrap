import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'images.pexels.com',
        pathname: '/photos/**',
      },
      {
        protocol: 'https',
        hostname: 'sviemtckfodbhphwbsmb.supabase.co',
        pathname: '/storage/v1/object/public/**',
      },
    ],
  },
  typescript: {
    ignoreBuildErrors: true,
  },
  experimental: {
    serverActions: {
      allowedOrigins: ['*.csb.app'],
      bodySizeLimit: '2mb',
    },
  },
}

export default nextConfig
