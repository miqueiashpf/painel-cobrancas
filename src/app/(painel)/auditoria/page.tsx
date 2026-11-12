import Link from "next/link";
import { exigirSessao } from "@/lib/auth";
import { criarClienteSupabase } from "@/lib/supabase/server";
import { quando } from "@/lib/formato";
import { Painel, Selo, TituloPagina, cx } from "@/components/ui";

const TABELAS: Record<string, string> = {
  mensalidades: "Mensalidades",
  jogadores: "Jogadores",
  sorteios: "Sorteios",
  jogos: "Jogos",
  lances: "Lances",
  usuarios: "Usuários",
  convites: "Convites",
  configuracoes: "Configurações",
};
const ACOES: Record<string, { rotulo: string; tom: "ok" | "alerta" | "perigo" }> = {
  INSERT: { rotulo: "Criou", tom: "ok" },
  UPDATE: { rotulo: "Alterou", tom: "alerta" },
  DELETE: { rotulo: "Apagou", tom: "perigo" },
};

export default async function AuditoriaPage({ searchParams }: PageProps<"/auditoria">) {
  await exigirSessao("admin");
  const { tabela } = await searchParams;
  const filtro = typeof tabela === "string" && tabela in TABELAS ? tabela : null;

  const supabase = await criarClienteSupabase();
  let consulta = supabase
    .from("auditoria")
    .select("id, usuario_id, tabela, acao, registro_id, criado_em")
    .order("criado_em", { ascending: false })
    .limit(100);
  if (filtro) consulta = consulta.eq("tabela", filtro);
  const [{ data: linhas }, { data: usuarios }] = await Promise.all([consulta, supabase.from("usuarios").select("id, nome")]);
  const nomes = new Map((usuarios ?? []).map((u) => [u.id, u.nome]));

  return (
    <>
      <TituloPagina titulo="Auditoria" descricao="Tudo o que foi criado, alterado ou apagado no painel, com quem fez e quando. Este registro não pode ser editado nem apagado." />
      <nav aria-label="Filtrar por área" className="flex flex-wrap gap-2">
        {[["", "Tudo"], ...Object.entries(TABELAS)].map(([chave, rotulo]) => {
          const ativo = (chave || null) === filtro;
          return (
            <Link
              key={chave || "tudo"}
              href={chave ? `/auditoria?tabela=${chave}` : "/auditoria"}
              aria-current={ativo ? "page" : undefined}
              className={cx("rounded-full border px-3 py-1 text-sm font-semibold", ativo ? "border-destaque bg-destaque text-sobre-destaque" : "border-borda bg-superficie text-suave hover:text-texto")}
            >
              {rotulo}
            </Link>
          );
        })}
      </nav>
      <Painel>
        {linhas?.length ? (
          <div className="-m-5 overflow-x-auto">
            <table className="w-full text-left text-sm tabular">
              <thead>
                <tr className="border-b border-borda text-xs uppercase tracking-wider text-suave">
                  <th className="px-5 py-3 font-semibold">Quando</th>
                  <th className="px-5 py-3 font-semibold">Quem</th>
                  <th className="px-5 py-3 font-semibold">O quê</th>
                  <th className="px-5 py-3 font-semibold">Área</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-borda">
                {linhas.map((l) => (
                  <tr key={l.id}>
                    <td className="whitespace-nowrap px-5 py-3 text-suave">{quando(l.criado_em)}</td>
                    <td className="px-5 py-3">{l.usuario_id ? nomes.get(l.usuario_id) ?? "Usuário removido" : "Sistema"}</td>
                    <td className="px-5 py-3"><Selo tom={ACOES[l.acao]?.tom ?? "alerta"}>{ACOES[l.acao]?.rotulo ?? l.acao}</Selo></td>
                    <td className="px-5 py-3">{TABELAS[l.tabela] ?? l.tabela}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p className="text-sm text-suave">Nenhum registro {filtro ? "nesta área" : "ainda"}.</p>
        )}
      </Painel>
    </>
  );
}
