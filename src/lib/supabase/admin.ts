import "server-only";
import { createClient } from "@supabase/supabase-js";
import { env } from "@/lib/env";

/**
 * Cliente com a chave de serviço. Ignora as regras de acesso do banco,
 * por isso só é usado para o Auth (enviar convite, bloquear login),
 * sempre depois de conferir que quem pediu é admin.
 */
export function criarClienteAdmin() {
  const { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } = env();
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
