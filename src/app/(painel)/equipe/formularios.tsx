"use client";

import { useActionState } from "react";
import { alterarUsuario, convidar, type Resultado } from "./actions";
import { Botao, Campo, Mensagem, classeEntrada } from "@/components/ui";

const inicial: Resultado = { ok: false };

export function FormularioConvite() {
  const [estado, acao, enviando] = useActionState(convidar, inicial);
  return (
    <form action={acao} className="grid gap-4">
      <div className="grid gap-4 sm:grid-cols-[1fr_180px_auto] sm:items-end">
        <Campo rotulo="E-mail" id="convite-email">
          <input id="convite-email" name="email" type="email" required maxLength={254} className={classeEntrada} placeholder="pessoa@exemplo.com" />
        </Campo>
        <Campo rotulo="Perfil" id="convite-papel">
          <select id="convite-papel" name="papel" defaultValue="equipe" className={classeEntrada}>
            <option value="equipe">Equipe</option>
            <option value="leitura">Somente leitura</option>
            <option value="admin">Administrador</option>
          </select>
        </Campo>
        <Botao variante="primario" type="submit" disabled={enviando}>{enviando ? "Enviando…" : "Enviar convite"}</Botao>
      </div>
      {estado.mensagem && <Mensagem tom={estado.ok ? "ok" : "perigo"}>{estado.mensagem}</Mensagem>}
    </form>
  );
}

export function FormularioUsuario({ id, nome, papel, ativo }: { id: string; nome: string; papel: string; ativo: boolean }) {
  const [estado, acao, salvando] = useActionState(alterarUsuario, inicial);
  return (
    <form action={acao} className="flex flex-wrap items-center gap-2">
      <input type="hidden" name="id" value={id} />
      <select name="papel" defaultValue={papel} aria-label={`Perfil de ${nome}`} className={`${classeEntrada} w-auto`}>
        <option value="admin">Administrador</option>
        <option value="equipe">Equipe</option>
        <option value="leitura">Somente leitura</option>
      </select>
      <select name="ativo" defaultValue={ativo ? "sim" : "nao"} aria-label={`Situação de ${nome}`} className={`${classeEntrada} w-auto`}>
        <option value="sim">Ativo</option>
        <option value="nao">Desativado</option>
      </select>
      <Botao type="submit" disabled={salvando}>{salvando ? "Salvando…" : "Salvar"}</Botao>
      {estado.mensagem && <span role="status" className={`text-xs ${estado.ok ? "text-ok" : "text-perigo"}`}>{estado.mensagem}</span>}
    </form>
  );
}
