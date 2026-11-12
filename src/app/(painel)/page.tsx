import { exigirSessao } from "@/lib/auth";
import { criarClienteSupabase } from "@/lib/supabase/server";
import { competenciaAtual, nomeDoMes, reais } from "@/lib/formato";
import { Mensagem, Painel, TituloPagina } from "@/components/ui";

export default async function InicioPage({ searchParams }: PageProps<"/">) {
  const sessao = await exigirSessao();
  const { erro } = await searchParams;
  const supabase = await criarClienteSupabase();
  const competencia = competenciaAtual();

  const [{ data: mensalidades }, { count: jogadoresAtivos }] = await Promise.all([
    supabase.from("mensalidades_painel").select("status, valor_centavos").eq("competencia", competencia),
    supabase.from("jogadores").select("id", { count: "exact", head: true }).eq("ativo", true),
  ]);

  const lista = mensalidades ?? [];
  const soma = (f: (s: string) => boolean) => lista.filter((m) => f(m.status)).reduce((t, m) => t + m.valor_centavos, 0);
  const resumo = [
    { rotulo: "Recebido", valor: reais(soma((s) => s === "paga")), detalhe: `${lista.filter((m) => m.status === "paga").length} pagas` },
    { rotulo: "A receber", valor: reais(soma((s) => s === "aberta")), detalhe: `${lista.filter((m) => m.status === "aberta").length} em aberto` },
    { rotulo: "Atrasado", valor: reais(soma((s) => s === "atrasada")), detalhe: `${lista.filter((m) => m.status === "atrasada").length} atrasadas`, alerta: true },
    { rotulo: "Jogadores ativos", valor: String(jogadoresAtivos ?? 0), detalhe: "cadastrados" },
  ];

  return (
    <>
      <TituloPagina titulo={`Olá, ${sessao.nome}`} descricao={`Resumo das mensalidades de ${nomeDoMes(competencia)}.`} />
      {erro === "sem-permissao" && <Mensagem tom="perigo">Seu perfil não tem permissão para abrir aquela página.</Mensagem>}
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {resumo.map((r) => (
          <div key={r.rotulo} className="rounded-xl border border-borda bg-superficie p-5">
            <p className="text-xs font-semibold uppercase tracking-wider text-suave">{r.rotulo}</p>
            <p className={`mt-2 font-display text-2xl font-bold tabular ${r.alerta && r.valor !== reais(0) ? "text-perigo" : ""}`}>{r.valor}</p>
            <p className="mt-1 text-sm text-suave">{r.detalhe}</p>
          </div>
        ))}
      </div>
      {lista.length === 0 && (
        <Painel>
          <p className="text-sm text-suave">
            As mensalidades de {nomeDoMes(competencia)} ainda não foram geradas. Elas são criadas automaticamente no dia 1 de cada mês para os jogadores mensalistas ativos.
          </p>
        </Painel>
      )}
    </>
  );
}
