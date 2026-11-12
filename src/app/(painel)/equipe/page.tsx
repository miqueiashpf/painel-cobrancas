import { exigirSessao } from "@/lib/auth";
import { criarClienteSupabase } from "@/lib/supabase/server";
import { quando } from "@/lib/formato";
import { Botao, Painel, Selo, TituloPagina } from "@/components/ui";
import { FormularioConvite, FormularioUsuario } from "./formularios";
import { cancelarConvite } from "./actions";

const NOMES_PAPEL: Record<string, string> = { admin: "Administrador", equipe: "Equipe", leitura: "Somente leitura" };

export default async function EquipePage() {
  const sessao = await exigirSessao("admin");
  const supabase = await criarClienteSupabase();
  const [{ data: usuarios }, { data: convites }] = await Promise.all([
    supabase.from("usuarios").select("id, nome, email, papel, ativo, criado_em").order("nome"),
    supabase
      .from("convites")
      .select("id, email, papel, criado_em, expira_em")
      .is("usado_em", null)
      .is("cancelado_em", null)
      .gt("expira_em", new Date().toISOString())
      .order("criado_em", { ascending: false }),
  ]);

  return (
    <>
      <TituloPagina titulo="Equipe" descricao="Quem pode entrar no painel. O acesso é só por convite: a pessoa recebe um link no e-mail, válido por 48 horas e de uso único." />

      <Painel titulo="Convidar pessoa">
        <FormularioConvite />
        <p className="mt-4 text-xs text-suave">
          Administrador gerencia a equipe e as configurações. Equipe cadastra jogadores, sorteia e registra pagamentos. Somente leitura apenas consulta.
        </p>
      </Painel>

      <Painel titulo={`Convites pendentes (${convites?.length ?? 0})`}>
        {convites?.length ? (
          <ul className="divide-y divide-borda">
            {convites.map((c) => (
              <li key={c.id} className="flex flex-wrap items-center justify-between gap-3 py-3 first:pt-0 last:pb-0">
                <div className="min-w-0">
                  <p className="truncate text-sm font-semibold">{c.email}</p>
                  <p className="text-xs text-suave">{NOMES_PAPEL[c.papel]} · vence em {quando(c.expira_em)}</p>
                </div>
                <form action={cancelarConvite}>
                  <input type="hidden" name="id" value={c.id} />
                  <Botao variante="perigo" type="submit">Cancelar convite</Botao>
                </form>
              </li>
            ))}
          </ul>
        ) : (
          <p className="text-sm text-suave">Nenhum convite aguardando resposta.</p>
        )}
      </Painel>

      <Painel titulo={`Pessoas com acesso (${usuarios?.length ?? 0})`}>
        <ul className="divide-y divide-borda">
          {(usuarios ?? []).map((u) => (
            <li key={u.id} className="flex flex-wrap items-center justify-between gap-3 py-3 first:pt-0 last:pb-0">
              <div className="min-w-0">
                <p className="flex flex-wrap items-center gap-2 text-sm font-semibold">
                  <span className="truncate">{u.nome}</span>
                  {u.id === sessao.id && <Selo tom="neutro">Você</Selo>}
                  {!u.ativo && <Selo tom="perigo">Desativado</Selo>}
                </p>
                <p className="truncate text-xs text-suave">{u.email} · {NOMES_PAPEL[u.papel]}</p>
              </div>
              {u.id !== sessao.id && <FormularioUsuario id={u.id} nome={u.nome} papel={u.papel} ativo={u.ativo} />}
            </li>
          ))}
        </ul>
      </Painel>
    </>
  );
}
