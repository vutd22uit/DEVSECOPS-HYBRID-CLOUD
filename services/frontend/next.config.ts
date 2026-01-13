import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactStrictMode: true,
  output: 'standalone',
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'placehold.co',
      },
      {
        protocol: 'https',
        hostname: '**',
      },
    ],
  },

  async rewrites() {
    // [FIX] Sử dụng tên Service nội bộ K8s làm giá trị mặc định (Fallback)
    // Next.js Server Actions/SSR sẽ sử dụng các URL này để proxy request.

    // Nếu biến môi trường K8s được inject (Khuyến khích dùng trong Production)
    const PRODUCTS_SERVICE_URL = process.env.PRODUCTS_SERVICE_URL || "http://products-service:8083";
    const USERS_SERVICE_URL = process.env.USERS_SERVICE_URL || "http://users-service:8082";
    const ORDERS_SERVICE_URL = process.env.ORDERS_SERVICE_URL || "http://orders-service:8084";

    return [
      // --- USERS SERVICE ---
      {
        source: '/api/auth/:path*',
        destination: `${USERS_SERVICE_URL}/api/auth/:path*`,
      },
      {
        source: '/api/users/:path*',
        destination: `${USERS_SERVICE_URL}/api/users/:path*`,
      },

      // --- PRODUCTS SERVICE ---
      {
        source: '/api/products/:path*',
        destination: `${PRODUCTS_SERVICE_URL}/api/products/:path*`,
      },
      {
        source: '/api/categories/:path*',
        destination: `${PRODUCTS_SERVICE_URL}/api/categories/:path*`,
      },
      // [QUAN TRỌNG] Thêm đoạn này để map API Reviews sang Products Service
      {
        source: "/api/reviews/:path*",
        destination: `${PRODUCTS_SERVICE_URL}/api/reviews/:path*`,
      },

      // --- ORDERS SERVICE ---
      {
        source: '/api/orders/:path*',
        // Chú ý: Orders Service có thêm /api/v1
        destination: `${ORDERS_SERVICE_URL}/api/v1/orders/:path*`,
      },
    ];
  },
};

export default nextConfig;