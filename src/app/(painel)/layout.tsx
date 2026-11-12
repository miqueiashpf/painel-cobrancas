import { exigirSessao } from "@/lib/auth";
import { Navegacao } from "./navegacao";
import { sair } from "@/app/actions";

const NOMES_PAPEL = { admin: "Administrador", equipe: "Equipe", leitura: "Somente leitura" } as const;

export default async function PainelLayout({ children }: LayoutProps<"/">) {
  const sessao = await exigirSessao();
  const itens = [
    { href: "/", rotulo: "Início" },
    ...(sessao.papel === "admin"
      ? [{ href: "/equipe", rotulo: "Equipe" }, { href: "/auditoria", rotulo: "Auditoria" }]
      : []),
  ];

  return (
    <div className="min-h-dvh md:grid md:grid-cols-[232px_1fr]">
      <aside className="border-b border-borda bg-superficie md:sticky md:top-0 md:h-dvh md:border-b-0 md:border-r">
        <div className="flex h-full flex-col gap-4 px-4 py-4 md:py-6">
          <div className="flex items-center justify-between gap-3 md:block">
            <p className="font-display text-lg font-bold">Painel da Pelada</p>
            <p className="hidden text-xs text-suave md:block">Segundas, 23h</p>
          </div>
          <Navegacao itens={itens} />
          <div className="mt-auto hidden border-t border-borda pt-4 md:block">
            <p className="truncate text-sm font-semibold" title={sessao.email}>{sessao.nome}</p>
            <p className="text-xs text-suave">{NOMES_PAPEL[sessao.papel]}</p>
            <form action={sair} className="mt-3">
              <button type="submit" className="text-sm font-semibold text-suave hover:text-texto">Sair</button>
            </form>
          </div>
        </div>
      </aside>
      <main className="min-w-0 px-4 py-6 md:px-8 md:py-8">
        <div className="mx-auto grid max-w-6xl gap-6">{children}</div>
        <form action={sair} className="mt-10 md:hidden">
          <p className="text-xs text-suave">{sessao.nome} · {NOMES_PAPEL[sessao.papel]}</p>
          <button type="submit" className="mt-1 text-sm font-semibold text-suave">Sair</button>
        </form>
      </main>
    </div>
  );
}
