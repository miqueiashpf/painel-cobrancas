import "server-only";
import { cache } from "react";
import { redirect } from "next/navigation";
import { criarClienteSupabase } from "@/lib/supabase/server";

export type Papel = "admin" | "equipe" | "leitura";

export type Sessao = {
  id: string;
  email: string;
  nome: string;
  papel: Papel;
};

/**
 * Lê o usuário da requisição atual. Valida o token no servidor do Supabase
 * (getUser, nunca getSession) e confere no banco se ele continua ativo.
 */
export const lerSessao = cache(async (): Promise<Sessao | null> => {
  const supabase = await criarClienteSupabase();
  const { data, error } = await supabase.auth.getUser();
  if (error || !data.user) return null;

  const { data: usuario } = await supabase
    .from("usuarios")
    .select("id, email, nome, papel, ativo")
    .eq("id", data.user.id)
    .maybeSingle();
  if (!usuario || !usuario.ativo) return null;

  return { id: usuario.id, email: usuario.email, nome: usuario.nome, papel: usuario.papel as Papel };
});

/** Exige login (e, se informado, um dos perfis). Redireciona quando não cumpre. */
export async function exigirSessao(...permitidos: Papel[]): Promise<Sessao> {
  const sessao = await lerSessao();
  if (!sessao) redirect("/login");
  if (permitidos.length && !permitidos.includes(sessao.papel)) redirect("/?erro=sem-permissao");
  return sessao;
}

/** Versão para Server Actions: devolve null em vez de redirecionar. */
export async function sessaoComPapel(...permitidos: Papel[]): Promise<Sessao | null> {
  const sessao = await lerSessao();
  if (!sessao || (permitidos.length && !permitidos.includes(sessao.papel))) return null;
  return sessao;
}
