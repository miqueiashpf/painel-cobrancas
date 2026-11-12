"use server";

import { z } from "zod";
import { criarClienteSupabase } from "@/lib/supabase/server";
import { env } from "@/lib/env";

export type EstadoLogin = { enviado: boolean; erro?: string };

const schema = z.object({ email: z.email().max(254) });

/**
 * Envia o link de acesso. A resposta é sempre a mesma, exista ou não o e-mail,
 * para ninguém descobrir quem tem acesso ao sistema.
 */
export async function enviarLinkDeAcesso(_: EstadoLogin, formData: FormData): Promise<EstadoLogin> {
  const parsed = schema.safeParse({ email: String(formData.get("email") ?? "").trim().toLowerCase() });
  if (!parsed.success) return { enviado: false, erro: "Digite um e-mail válido." };

  const supabase = await criarClienteSupabase();
  const { error } = await supabase.auth.signInWithOtp({
    email: parsed.data.email,
    options: { shouldCreateUser: false, emailRedirectTo: `${env().SITE_URL}/auth/confirm` },
  });
  if (error?.status === 429) {
    return { enviado: false, erro: "Muitos pedidos seguidos. Espere um minuto e tente de novo." };
  }
  // E-mail sem cadastro também cai aqui (o Supabase recusa): a resposta continua igual.
  if (error && (error.status ?? 500) >= 500) {
    console.error("login: falha ao enviar link", error.code, error.status);
  }
  return { enviado: true };
}
