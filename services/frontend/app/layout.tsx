import type { Metadata } from "next";
import { Be_Vietnam_Pro } from "next/font/google";
import "./globals.css";
// Sử dụng đường dẫn tương đối để đảm bảo tìm thấy file trong cấu trúc dự án của bạn
import { ThemeProvider } from "../components/theme-provider";
import { AuthProvider } from "../context/AuthContext";
import { CartProvider } from "../context/CartContext";
import { Toaster } from "../components/ui/sonner";
import { AutoScroll } from "../components/utils/AutoScoll";
import { HybridStatus } from "../components/HybridStatus";

const beVietnamPro = Be_Vietnam_Pro({
  variable: "--font-be-vietnam-pro",
  subsets: ["latin", "vietnamese"],
  weight: ["300", "400", "500", "600", "700", "800"],
  display: "swap",
});

export const metadata: Metadata = {
  title: "FoodHub - Đặt món ăn",
  description: "Dự án DevSecOps Microservice - Hệ thống đặt món trực tuyến",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="vi" suppressHydrationWarning className="scroll-smooth">
      <body
        className={`${beVietnamPro.className} antialiased min-h-screen bg-background font-sans relative`}
      >
        <ThemeProvider
          attribute="class"
          defaultTheme="system"
          enableSystem
          disableTransitionOnChange
        >
          {/* Global Background Pattern */}
          <div className="fixed inset-0 -z-10 h-full w-full bg-[linear-gradient(to_right,#8080800a_1px,transparent_1px),linear-gradient(to_bottom,#8080800a_1px,transparent_1px)] bg-[size:24px_24px]">
            <div className="absolute left-0 right-0 top-0 -z-10 m-auto h-[310px] w-[310px] rounded-full bg-orange-400 opacity-20 blur-[100px]"></div>
          </div>

          <AuthProvider>
            <CartProvider>
              {/* AutoScroll sẽ tự động cuộn xuống danh sách món khi chuyển trang */}
              <AutoScroll />
              <HybridStatus />
              {children}
            </CartProvider>
          </AuthProvider>

          <Toaster richColors position="bottom-right" closeButton />

        </ThemeProvider>
      </body>
    </html>
  );
}