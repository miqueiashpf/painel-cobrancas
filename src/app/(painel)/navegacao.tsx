"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cx } from "@/components/ui";

export function Navegacao({ itens }: { itens: { href: string; rotulo: string }[] }) {
  const atual = usePathname();
  return (
    <nav aria-label="Seções" className="-mx-1 flex gap-1 overflow-x-auto md:flex-col md:overflow-visible">
      {itens.map((item) => {
        const ativo = item.href === "/" ? atual === "/" : atual.startsWith(item.href);
        return (
          <Link
            key={item.href}
            href={item.href}
            aria-current={ativo ? "page" : undefined}
            className={cx(
              "shrink-0 rounded-lg px-3 py-2 text-sm font-semibold transition-colors",
              ativo ? "bg-superficie-2 text-texto" : "text-suave hover:bg-superficie-2 hover:text-texto",
            )}
          >
            {item.rotulo}
          </Link>
        );
      })}
    </nav>
  );
}
