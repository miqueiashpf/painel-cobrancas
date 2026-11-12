"use client";

import { useActionState } from "react";
import { enviarLinkDeAcesso, type EstadoLogin } from "./actions";
import { Botao, Campo, Mensagem, classeEntrada } from "@/components/ui";

const inicial: EstadoLogin = { enviado: false };

export function FormularioLogin() {
  const [estado, acao, enviando] = useActionState(enviarLinkDeAcesso, inicial);

  if (estado.enviado) {
    return (
      <Mensagem tom="ok">
        Se este e-mail tiver acesso, você vai receber um link para entrar. Ele vale por 10 minutos e funciona uma vez só.
      </Mensagem>
    );
  }

  return (
    <form action={acao} className="grid gap-4">
      <Campo rotulo="E-mail" id="email">
        <input id="email" name="email" type="email" autoComplete="email" required maxLength={254} className={classeEntrada} placeholder="voce@exemplo.com" />
      </Campo>
      {estado.erro && <Mensagem tom="perigo">{estado.erro}</Mensagem>}
      <Botao variante="primario" type="submit" disabled={enviando}>
        {enviando ? "Enviando…" : "Receber link de acesso"}
      </Botao>
    </form>
  );
}
