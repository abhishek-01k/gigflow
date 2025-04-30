import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "../styles/globals.css";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "TrustID - Self-Sovereign Identity & Reputation on Rootstock",
  description: "AI-driven identity management and reputation system built on Rootstock blockchain",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <header className="border-b">
          <div className="container flex h-16 items-center">
            <div className="font-bold text-xl">TrustID</div>
            <nav className="ml-auto flex gap-4">
              <a href="/" className="font-medium">Home</a>
              <a href="/identity" className="font-medium">My Identity</a>
              <a href="/credentials" className="font-medium">Credentials</a>
              <a href="/reputation" className="font-medium">Reputation</a>
            </nav>
          </div>
        </header>
        <main className="container py-6">
          {children}
        </main>
        <footer className="border-t py-6">
          <div className="container text-center text-sm">
            <p>© 2023 TrustID - Built on Rootstock</p>
          </div>
        </footer>
      </body>
    </html>
  );
}
