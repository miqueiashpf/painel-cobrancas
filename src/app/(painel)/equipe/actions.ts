"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { sessaoComPapel } from "@/lib/auth";
import { criarClienteSupabase } from "@/lib/supabase/server";
import { criarClienteAdmin } from "@/lib/supabase/admin";
import { env } from "@/lib/env";

export type Resultado = { ok: boolean; mensagem?: string };

const papel = z.enum(["admin", "equipe", "leitura"]);
const SEM_PERMISSAO: Resultado = { ok: false, mensagem: "Só administradores podem fazer isso." };

const schemaConvite = z.object({ email: z.email().max(254), papel });

export async function convidar(_: Resultado, formData: FormData): Promise<Resultado> {
  if (!(await sessaoComPapel("admin"))) return SEM_PERMISSAO;
  const parsed = schemaConvite.safeParse({
    email: String(formData.get("email") ?? "").trim().toLowerCase(),
    papel: formData.get("papel"),
  });
  if (!parsed.success) return { ok: false, mensagem: "Confira o e-mail e o perfil." };
  const { email } = parsed.data;

  // 1. O banco registra o convite (e confere de novo que quem pede é admin).
  const supabase = await criarClienteSupabase();
  const { data: conviteId, error } = await supabase.rpc("criar_convite", { p_email: email, p_papel: parsed.data.papel });
  if (error) {
    if (error.code === "23505") return { ok: false, mensagem: "Este e-mail já tem acesso ao painel." };
    if (error.code === "42501") return SEM_PERMISSAO;
    console.error("convite: erro no banco", error.code);
    return { ok: false, mensagem: "Não foi possível criar o convite. Tente de novo." };
  }

  // 2. O Supabase Auth envia o e-mail com o link (uso único, vai só para este e-mail).
  const admin = criarClienteAdmin();
  const redirectTo = `${env().SITE_URL}/auth/confirm`;
  const { error: erroEnvio } = await admin.auth.admin.inviteUserByEmail(email, { redirectTo });
  if (erroEnvio) {
    // Já existe no Auth (convite anterior não aceito): manda um link de acesso comum.
    const jaExiste = erroEnvio.code === "email_exists" || erroEnvio.status === 422;
    const { error: erroLink } = jaExiste
      ? await admin.auth.signInWithOtp({ email, options: { shouldCreateUser: false, emailRedirectTo: redirectTo } })
      : { error: erroEnvio };
    if (erroLink) {
      await supabase.rpc("cancelar_convite", { p_id: conviteId });
      console.error("convite: erro ao enviar e-mail", erroLink.code, erroLink.status);
      return { ok: false, mensagem: "O convite não pôde ser enviado por e-mail. Tente de novo em alguns minutos." };
    }
  }

  revalidatePath("/equipe");
  return { ok: true, mensagem: `Convite enviado para ${email}. O link vale por 48 horas.` };
}

const schemaId = z.uuid();

export async function cancelarConvite(formData: FormData) {
  if (!(await sessaoComPapel("admin"))) return;
  const id = schemaId.safeParse(formData.get("id"));
  if (!id.success) return;
  const supabase = await criarClienteSupabase();
  await supabase.rpc("cancelar_convite", { p_id: id.data });
  revalidatePath("/equipe");
}

const schemaUsuario = z.object({ id: z.uuid(), papel, ativo: z.enum(["sim", "nao"]) });

export async function alterarUsuario(_: Resultado, formData: FormData): Promise<Resultado> {
  const sessao = await sessaoComPapel("admin");
  if (!sessao) return SEM_PERMISSAO;
  const parsed = schemaUsuario.safeParse({ id: formData.get("id"), papel: formData.get("papel"), ativo: formData.get("ativo") });
  if (!parsed.success) return { ok: false, mensagem: "Dados inválidos." };
  if (parsed.data.id === sessao.id) return { ok: false, mensagem: "Você não pode alterar o próprio acesso." };
  const ativo = parsed.data.ativo === "sim";

  const supabase = await criarClienteSupabase();
  const { error } = await supabase.rpc("alterar_usuario", { p_id: parsed.data.id, p_papel: parsed.data.papel, p_ativo: ativo });
  if (error) return { ok: false, mensagem: error.code === "42501" ? "Ação não permitida." : "Não foi possível salvar." };

  // Desativado também perde o login no Auth: links e sessões param de funcionar.
  const { error: erroBan } = await criarClienteAdmin().auth.admin.updateUserById(parsed.data.id, {
    ban_duration: ativo ? "none" : "876000h",
  });
  if (erroBan) console.error("usuario: erro ao (des)bloquear login", erroBan.code);

  revalidatePath("/equipe");
  return { ok: true, mensagem: "Acesso atualizado." };
}
