# Painel da Pelada

Painel interno para as mensalidades, os jogadores e o sorteio da pelada de segunda (23h).

**Stack:** Next.js 16 (App Router) · Supabase (Postgres + Auth) · Vercel · Tailwind CSS 4 · Zod.

## Como a segurança funciona

| Camada | O que faz |
|---|---|
| Navegador | Só mostra telas. Nunca fala com o banco e não tem nenhuma chave. O token de sessão fica em cookie `HttpOnly`, que o JavaScript da página não lê. |
| Servidor (Next.js) | Toda leitura e escrita passa por Server Components e Server Actions. Cada ação confere o login e o perfil de novo e valida a entrada com Zod. |
| Banco (Postgres) | Row Level Security em todas as tabelas. `anon` não acessa nada. As escritas sensíveis (pagamento, sorteio, convites, usuários) só acontecem por funções que conferem o perfil. |
| Auditoria | Um gatilho registra toda criação, alteração e exclusão, com autor e valores antes e depois. Ninguém altera nem apaga esse registro, nem o admin. |
| Cabeçalhos | CSP com nonce por requisição, HSTS, `X-Frame-Options: DENY`, `nosniff`, `Referrer-Policy` e `Permissions-Policy`. |

**Perfis:**

- **Administrador:** gerencia a equipe, os convites, a auditoria e as configurações.
- **Equipe:** cadastra jogadores, sorteia os times e registra pagamentos.
- **Somente leitura:** apenas consulta.

**Login:** só por convite. O admin convida um e-mail, e a pessoa recebe um link de uso único, válido por 48 horas. Nas próximas vezes ela pede um link de acesso, válido por 10 minutos. Não existe senha. A sessão expira depois de 8 horas sem uso. Quando um usuário é desativado, o login dele é bloqueado no Auth na hora.

**Sorteio:** roda dentro do banco, na função `sortear_times`, e não no navegador. As regras são:

1. os goleiros ficam em times diferentes;
2. nunca há dois nível 5 no mesmo time (o sistema avisa quando vêm mais nível 5 do que times);
3. todos os times têm o mesmo número de jogadores;
4. a força dos times, que é a soma dos níveis, fica equilibrada.

Cada sorteio fica guardado com o autor. Sortear de novo mantém o anterior no histórico.

## Instalação

### 1. Supabase

1. Crie um projeto em https://supabase.com na região **South America (São Paulo)**.
2. Rode as migrations da pasta `supabase/migrations`, em ordem. Há dois jeitos:
   - pela Supabase CLI: `supabase link` e depois `supabase db push`;
   - ou colando cada arquivo no **SQL Editor**.
3. Ative a extensão **pg_cron** (Database > Extensions) **antes** da migration `..._agendamento.sql`. Ela gera as mensalidades no dia 1 de cada mês, às 8h de Brasília.
4. Em **Authentication > Sign In / Providers**:
   - desligue **Allow new users to sign up**. Só entra quem for convidado;
   - em Email, deixe **Email OTP Expiration** em `600` segundos (10 minutos).
5. Em **Authentication > URL Configuration**:
   - **Site URL**: o endereço do site, por exemplo `https://painel.seudominio.com.br`;
   - **Redirect URLs**: `https://painel.seudominio.com.br/auth/confirm`.
6. Em **Authentication > Emails**, troque o link destes dois modelos. Isso é obrigatório, porque o login é validado no servidor:
   - **Invite user**:
     ```html
     <h2>Você foi convidado para o Painel da Pelada</h2>
     <p><a href="{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=invite">Aceitar convite</a></p>
     <p>O link vale uma vez só. Se você não esperava este convite, ignore este e-mail.</p>
     ```
   - **Magic link**:
     ```html
     <h2>Seu link de acesso</h2>
     <p><a href="{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=email">Entrar no painel</a></p>
     <p>Vale por 10 minutos e funciona uma vez só. Se não foi você, ignore este e-mail.</p>
     ```
7. **Configure um SMTP próprio** em Authentication > Emails > SMTP Settings. Resend, Brevo ou Amazon SES servem. O envio padrão do Supabase manda pouquíssimos e-mails por hora e não serve para uso real.

### 2. Primeiro administrador

O primeiro admin não tem quem o convide, então ele é criado à mão:

1. Em **Authentication > Users > Invite user**, convide o seu e-mail.
2. No **SQL Editor**, rode o comando abaixo trocando o e-mail e o nome:
   ```sql
   insert into public.usuarios (id, email, nome, papel)
   select id, lower(email), 'Seu nome', 'admin' from auth.users where email = 'seu@email.com';
   ```
3. Abra o link do e-mail. A partir daí, os outros convites saem pela tela **Equipe**.

### 3. Vercel

1. Importe o repositório na Vercel.
2. Em **Settings > Environment Variables**, cadastre as variáveis do arquivo `.env.example`:
   - `SUPABASE_URL` e `SUPABASE_ANON_KEY`;
   - `SUPABASE_SERVICE_ROLE_KEY`, que é **secreta**;
   - `SITE_URL`.

   Nenhuma delas usa o prefixo `NEXT_PUBLIC_`, de propósito.
3. Configure o domínio. O HSTS exige HTTPS, e a Vercel já cuida disso.

## Desenvolvimento

```bash
cp .env.example .env.local   # preencha com os dados do projeto Supabase
npm install
npm run dev
```

Verificações antes de cada entrega:

```bash
npm run typecheck   # tipos
npm run lint        # padrões de código
npm run test:db     # regras de acesso e sorteio num Postgres local
npm run build       # compilação de produção
```

O `test:db` cria um banco descartável, aplica as migrations e roda 44 testes. Os testes conferem, entre outras coisas:

- que a equipe não apaga jogadores nem vê a auditoria;
- que o perfil de leitura não altera nada;
- que ninguém grava um sorteio ou um pagamento direto na tabela;
- que convites vencidos não dão acesso;
- 200 sorteios seguidos sem nenhum time com dois nível 5.

Para rodar, é preciso ter `psql` e um Postgres local. Por exemplo, com o Postgres do sistema:

```bash
sudo -u postgres npm run test:db
```

## LGPD

- O painel guarda só o necessário: nome, telefone opcional e mensalidades.
- O acesso é registrado na auditoria, e o banco fica no Brasil (região São Paulo).
- Se houver vazamento, a minuta da ANPD prevê avisar a autoridade em até 3 dias úteis. Os logs da auditoria e do Supabase ajudam a descobrir o que foi afetado.
- Mensagens de cobrança não podem expor nem constranger o devedor (art. 42 do Código de Defesa do Consumidor).
