import type { Metadata } from "next";
import { headers } from "next/headers";
import { Inter, Space_Grotesk } from "next/font/google";
import "./globals.css";

const texto = Inter({ variable: "--fonte-texto", subsets: ["latin"] });
const titulo = Space_Grotesk({ variable: "--fonte-titulo", subsets: ["latin"], weight: ["500", "600", "700"] });

export const metadata: Metadata = {
  title: "Painel da Pelada",
  description: "Mensalidades, jogadores e sorteio da pelada de segunda.",
  robots: { index: false, follow: false },
};

export default async function RootLayout({ children }: LayoutProps<"/">) {
  // Ler os cabeçalhos torna toda página dinâmica, o que permite aplicar o nonce da CSP.
  await headers();
  return (
    <html lang="pt-BR" className={`${texto.variable} ${titulo.variable} h-full antialiased`}>
      <body className="min-h-full font-sans">{children}</body>
    </html>
  );
}
