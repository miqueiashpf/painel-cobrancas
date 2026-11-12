-- =====================================================================
-- Painel de Cobranças da Pelada — esquema inicial
--
-- Princípios:
--  * O navegador nunca fala com o banco. O servidor Next.js usa a sessão
--    do usuário, e o banco aplica Row Level Security (RLS) em toda tabela.
--  * anon não tem acesso a nada. authenticated só lê; escritas sensíveis
--    passam por funções SECURITY DEFINER que conferem o perfil.
--  * Tudo que muda fica na tabela de auditoria, que ninguém altera.
-- =====================================================================

-- ---------- Tipos ----------
create type public.papel as enum ('admin', 'equipe', 'leitura');
create type public.tipo_jogador as enum ('mensalista', 'avulso');
create type public.posicao as enum ('linha', 'goleiro');
create type public.status_mensalidade as enum ('aberta', 'paga', 'isenta');
create type public.forma_pagamento as enum ('pix', 'dinheiro', 'outro');

-- ---------- Tabelas ----------
create table public.usuarios (
  id          uuid primary key references auth.users (id) on delete cascade,
  email       text not null unique check (email = lower(email) and length(email) <= 254),
  nome        text not null check (length(btrim(nome)) between 1 and 80),
  papel       public.papel not null default 'leitura',
  ativo       boolean not null default true,
  criado_em   timestamptz not null default now()
);

create table public.convites (
  id            uuid primary key default gen_random_uuid(),
  email         text not null check (email = lower(email) and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' and length(email) <= 254),
  papel         public.papel not null,
  criado_por    uuid not null references public.usuarios (id),
  criado_em     timestamptz not null default now(),
  expira_em     timestamptz not null default now() + interval '48 hours',
  usado_em      timestamptz,
  usado_por     uuid references public.usuarios (id),
  cancelado_em  timestamptz
);
create index convites_email_idx on public.convites (email);

create table public.configuracoes (
  id                          smallint primary key default 1 check (id = 1),
  valor_mensalidade_centavos  integer not null default 10000 check (valor_mensalidade_centavos between 0 and 10000000),
  dia_vencimento              smallint not null default 10 check (dia_vencimento between 1 and 28),
  pontos_gol                  smallint not null default 5 check (pontos_gol between -20 and 50),
  pontos_assistencia          smallint not null default 3 check (pontos_assistencia between -20 and 50),
  pontos_defesa               smallint not null default 1 check (pontos_defesa between -20 and 50),
  pontos_presenca             smallint not null default 1 check (pontos_presenca between -20 and 50),
  atualizado_em               timestamptz not null default now()
);
insert into public.configuracoes (id) values (1);

create table public.jogadores (
  id          uuid primary key default gen_random_uuid(),
  nome        text not null check (length(btrim(nome)) between 1 and 60),
  telefone    text check (telefone is null or telefone ~ '^[0-9+() -]{8,20}$'),
  tipo        public.tipo_jogador not null default 'mensalista',
  posicao     public.posicao not null default 'linha',
  nivel       smallint not null default 3 check (nivel between 1 and 5),
  ativo       boolean not null default true,
  criado_em   timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create unique index jogadores_nome_unico on public.jogadores (lower(btrim(nome)));

create table public.mensalidades (
  id              uuid primary key default gen_random_uuid(),
  jogador_id      uuid not null references public.jogadores (id) on delete restrict,
  competencia     date not null check (extract(day from competencia) = 1),
  valor_centavos  integer not null check (valor_centavos between 0 and 10000000),
  vencimento      date not null,
  status          public.status_mensalidade not null default 'aberta',
  pago_em         timestamptz,
  forma_pagamento public.forma_pagamento,
  observacao      text check (observacao is null or length(observacao) <= 500),
  registrado_por  uuid references public.usuarios (id),
  criado_em       timestamptz not null default now(),
  atualizado_em   timestamptz not null default now(),
  unique (jogador_id, competencia),
  check ((status = 'paga') = (pago_em is not null and forma_pagamento is not null))
);
create index mensalidades_competencia_idx on public.mensalidades (competencia, status);

create table public.jogos (
  id          uuid primary key default gen_random_uuid(),
  data        date not null unique,
  horario     time not null default '23:00',
  criado_por  uuid not null references public.usuarios (id),
  criado_em   timestamptz not null default now()
);

create table public.sorteios (
  id          uuid primary key default gen_random_uuid(),
  jogo_id     uuid not null references public.jogos (id) on delete cascade,
  times       jsonb not null,
  aviso       text,
  ativo       boolean not null default true,
  criado_por  uuid not null references public.usuarios (id),
  criado_em   timestamptz not null default now()
);
create unique index sorteios_um_ativo_por_jogo on public.sorteios (jogo_id) where ativo;

create table public.lances (
  id            uuid primary key default gen_random_uuid(),
  jogo_id       uuid not null references public.jogos (id) on delete cascade,
  jogador_id    uuid not null references public.jogadores (id) on delete restrict,
  gols          smallint not null default 0 check (gols between 0 and 50),
  assistencias  smallint not null default 0 check (assistencias between 0 and 50),
  defesas       smallint not null default 0 check (defesas between 0 and 200),
  atualizado_em timestamptz not null default now(),
  unique (jogo_id, jogador_id)
);

create table public.auditoria (
  id           bigint generated always as identity primary key,
  usuario_id   uuid,
  tabela       text not null,
  acao         text not null,
  registro_id  text,
  antes        jsonb,
  depois       jsonb,
  criado_em    timestamptz not null default now()
);
create index auditoria_criado_em_idx on public.auditoria (criado_em desc);

-- ---------- Perfil do usuário atual ----------
create or replace function public.papel_atual()
returns public.papel
language sql stable security definer set search_path = ''
as $$
  select u.papel from public.usuarios u
  where u.id = (select auth.uid()) and u.ativo
$$;

create or replace function public.exigir_papel(variadic permitidos public.papel[])
returns uuid
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_papel public.papel := public.papel_atual();
begin
  if v_papel is null or not (v_papel = any (permitidos)) then
    raise exception 'acesso negado' using errcode = '42501';
  end if;
  return auth.uid();
end
$$;

-- ---------- Auditoria ----------
create or replace function public.registrar_auditoria()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  v_antes  jsonb := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end;
  v_depois jsonb := case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end;
begin
  if tg_op = 'UPDATE' and v_antes = v_depois then
    return null;
  end if;
  insert into public.auditoria (usuario_id, tabela, acao, registro_id, antes, depois)
  values (auth.uid(), tg_table_name, tg_op,
          coalesce(v_depois ->> 'id', v_antes ->> 'id'), v_antes, v_depois);
  return null;
end
$$;

create or replace function public.tocar_atualizado_em()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  new.atualizado_em := now();
  return new;
end
$$;

do $$
declare t text;
begin
  foreach t in array array['usuarios','convites','configuracoes','jogadores','mensalidades','jogos','sorteios','lances']
  loop
    execute format('create trigger %I after insert or update or delete on public.%I
                    for each row execute function public.registrar_auditoria()', t || '_auditoria', t);
  end loop;
  foreach t in array array['configuracoes','jogadores','mensalidades','lances']
  loop
    execute format('create trigger %I before update on public.%I
                    for each row execute function public.tocar_atualizado_em()', t || '_atualizado_em', t);
  end loop;
end
$$;

-- ---------- Convites e usuários ----------
-- O admin registra o convite; o servidor envia o e-mail pelo Supabase Auth.
create or replace function public.criar_convite(p_email text, p_papel public.papel)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_admin uuid := public.exigir_papel('admin');
  v_email text := lower(btrim(p_email));
  v_id uuid;
begin
  if exists (select 1 from public.usuarios where email = v_email) then
    raise exception 'este e-mail já tem acesso' using errcode = '23505';
  end if;
  -- Um convite novo cancela os pendentes do mesmo e-mail.
  update public.convites set cancelado_em = now()
   where email = v_email and usado_em is null and cancelado_em is null;
  insert into public.convites (email, papel, criado_por)
  values (v_email, p_papel, v_admin)
  returning id into v_id;
  return v_id;
end
$$;

create or replace function public.cancelar_convite(p_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  perform public.exigir_papel('admin');
  update public.convites set cancelado_em = now()
   where id = p_id and usado_em is null and cancelado_em is null;
end
$$;

-- Chamado logo depois do login. Devolve o perfil, ou null se a pessoa
-- não tem acesso (sem convite válido, ou desativada).
create or replace function public.aceitar_convite()
returns public.papel
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid   uuid := auth.uid();
  v_email text := lower(auth.jwt() ->> 'email');
  v_user  public.usuarios%rowtype;
  v_conv  public.convites%rowtype;
begin
  if v_uid is null or v_email is null then
    return null;
  end if;
  select * into v_user from public.usuarios where id = v_uid;
  if found then
    return case when v_user.ativo then v_user.papel end;
  end if;
  select * into v_conv from public.convites
   where email = v_email and usado_em is null and cancelado_em is null and expira_em > now()
   order by criado_em desc limit 1
   for update;
  if not found then
    return null;
  end if;
  insert into public.usuarios (id, email, nome, papel)
  values (v_uid, v_email, split_part(v_email, '@', 1), v_conv.papel);
  update public.convites set usado_em = now(), usado_por = v_uid where id = v_conv.id;
  return v_conv.papel;
end
$$;

create or replace function public.alterar_usuario(p_id uuid, p_papel public.papel, p_ativo boolean)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_admin uuid := public.exigir_papel('admin');
begin
  if p_id = v_admin then
    raise exception 'você não pode alterar o próprio acesso' using errcode = '42501';
  end if;
  update public.usuarios set papel = p_papel, ativo = p_ativo where id = p_id;
  if not found then
    raise exception 'usuário não encontrado' using errcode = 'P0002';
  end if;
end
$$;

create or replace function public.alterar_meu_nome(p_nome text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := public.exigir_papel('admin', 'equipe', 'leitura');
begin
  update public.usuarios set nome = btrim(p_nome) where id = v_uid;
end
$$;

-- ---------- Mensalidades ----------
create or replace function public.gerar_mensalidades(p_competencia date)
returns integer
language plpgsql security definer set search_path = ''
as $$
declare
  v_comp date := date_trunc('month', p_competencia)::date;
  v_cfg  public.configuracoes%rowtype;
  v_qtd  integer;
begin
  -- Pode ser chamado pela equipe ou pelo agendador do banco (sem usuário).
  -- session_user (e não current_user, que aqui é o dono da função).
  if auth.uid() is not null then
    perform public.exigir_papel('admin', 'equipe');
  elsif session_user not in ('postgres', 'supabase_admin') then
    raise exception 'acesso negado' using errcode = '42501';
  end if;
  select * into v_cfg from public.configuracoes where id = 1;
  insert into public.mensalidades (jogador_id, competencia, valor_centavos, vencimento)
  select j.id, v_comp, v_cfg.valor_mensalidade_centavos, v_comp + (v_cfg.dia_vencimento - 1)
    from public.jogadores j
   where j.ativo and j.tipo = 'mensalista'
  on conflict (jogador_id, competencia) do nothing;
  get diagnostics v_qtd = row_count;
  return v_qtd;
end
$$;

create or replace function public.atualizar_mensalidade(
  p_id uuid,
  p_status public.status_mensalidade,
  p_forma public.forma_pagamento default null,
  p_observacao text default null
)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := public.exigir_papel('admin', 'equipe');
begin
  if p_status = 'paga' and p_forma is null then
    raise exception 'informe a forma de pagamento' using errcode = '22023';
  end if;
  update public.mensalidades
     set status          = p_status,
         pago_em         = case when p_status = 'paga' then coalesce(pago_em, now()) end,
         forma_pagamento = case when p_status = 'paga' then p_forma end,
         observacao      = nullif(btrim(coalesce(p_observacao, '')), ''),
         registrado_por  = v_uid
   where id = p_id;
  if not found then
    raise exception 'mensalidade não encontrada' using errcode = 'P0002';
  end if;
end
$$;

-- Status "atrasada" é calculado, nunca gravado: aberta + vencida.
create view public.mensalidades_painel
with (security_invoker = true)
as
select m.id, m.jogador_id, j.nome as jogador_nome, j.telefone as jogador_telefone,
       m.competencia, m.valor_centavos, m.vencimento,
       case when m.status = 'aberta' and m.vencimento < (now() at time zone 'America/Sao_Paulo')::date
            then 'atrasada' else m.status::text end as status,
       m.pago_em, m.forma_pagamento, m.observacao, m.registrado_por, m.atualizado_em
  from public.mensalidades m
  join public.jogadores j on j.id = m.jogador_id;

-- ---------- Sorteio (roda no banco, nunca no navegador) ----------
-- Regras, em ordem de prioridade:
--  1. goleiros espalhados (um por time enquanto houver);
--  2. nunca dois nível 5 no mesmo time, enquanto houver times sem nível 5;
--  3. times com o mesmo número de jogadores;
--  4. menor soma de níveis recebe o próximo; empates são sorteados.
create or replace function public.sortear_times(p_jogo uuid, p_presentes uuid[], p_n_times integer)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid    uuid := public.exigir_papel('admin', 'equipe');
  v_nomes  text[] := array['Laranja', 'Azul', 'Verde', 'Amarelo', 'Vermelho', 'Branco'];
  v_gk     integer[] := array_fill(0, array[p_n_times]);
  v_cinco  integer[] := array_fill(0, array[p_n_times]);
  v_qtd    integer[] := array_fill(0, array[p_n_times]);
  v_soma   integer[] := array_fill(0, array[p_n_times]);
  v_ids    uuid[] := '{}';
  v_time   integer[] := '{}';
  v_total  integer;
  v_n5     integer;
  v_best   integer;
  v_aviso  text;
  v_times  jsonb;
  v_id     uuid;
  r        record;
begin
  if p_n_times is null or p_n_times not between 2 and 6 then
    raise exception 'o número de times deve ser entre 2 e 6' using errcode = '22023';
  end if;
  if not exists (select 1 from public.jogos where id = p_jogo) then
    raise exception 'jogo não encontrado' using errcode = 'P0002';
  end if;

  select count(*), count(*) filter (where nivel = 5) into v_total, v_n5
    from public.jogadores
   where id = any (p_presentes) and ativo;

  if v_total <> coalesce(cardinality(array(select distinct unnest(p_presentes))), 0) then
    raise exception 'há jogadores inválidos ou inativos na lista' using errcode = '22023';
  end if;
  if v_total < p_n_times * 2 then
    raise exception 'são necessários pelo menos % jogadores para % times', p_n_times * 2, p_n_times
      using errcode = '22023';
  end if;
  if v_n5 > p_n_times then
    v_aviso := format('Vieram %s jogadores nível 5 para %s times: alguns times ficaram com mais de um.', v_n5, p_n_times);
  end if;

  for r in
    select j.id, j.nivel, (j.posicao = 'goleiro') as gk
      from public.jogadores j
     where j.id = any (p_presentes) and j.ativo
     order by (j.posicao = 'goleiro') desc, j.nivel desc, random()
  loop
    select i into v_best
      from generate_series(1, p_n_times) as i
     order by case when r.gk then v_gk[i] else 0 end,
              case when r.nivel = 5 then v_cinco[i] else 0 end,
              v_qtd[i],
              v_soma[i],
              random()
     limit 1;
    v_ids  := v_ids || r.id;
    v_time := v_time || v_best;
    v_qtd[v_best]  := v_qtd[v_best] + 1;
    v_soma[v_best] := v_soma[v_best] + r.nivel;
    if r.gk then v_gk[v_best] := v_gk[v_best] + 1; end if;
    if r.nivel = 5 then v_cinco[v_best] := v_cinco[v_best] + 1; end if;
  end loop;

  select jsonb_agg(jsonb_build_object(
           'nome', v_nomes[t],
           'forca', v_soma[t],
           'jogadores', (select coalesce(jsonb_agg(v_ids[k] order by k), '[]'::jsonb)
                           from generate_subscripts(v_ids, 1) as k where v_time[k] = t))
         order by t)
    into v_times
    from generate_series(1, p_n_times) as t;

  update public.sorteios set ativo = false where jogo_id = p_jogo and ativo;
  insert into public.sorteios (jogo_id, times, aviso, criado_por)
  values (p_jogo, v_times, v_aviso, v_uid)
  returning id into v_id;
  return v_id;
end
$$;

-- ---------- Permissões ----------
-- Fecha tudo e abre só o necessário.
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;
alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;

grant usage on schema public to authenticated;

grant select on public.usuarios, public.convites, public.configuracoes, public.jogadores,
                public.mensalidades, public.mensalidades_painel, public.jogos, public.sorteios,
                public.lances, public.auditoria
  to authenticated;
grant insert, update on public.jogadores to authenticated;
grant delete on public.jogadores to authenticated;
grant update (valor_mensalidade_centavos, dia_vencimento, pontos_gol, pontos_assistencia,
              pontos_defesa, pontos_presenca)
  on public.configuracoes to authenticated;
grant insert, delete on public.jogos to authenticated;
grant insert, update (gols, assistencias, defesas) on public.lances to authenticated;
grant delete on public.mensalidades to authenticated;

grant execute on function
  public.papel_atual(),
  public.aceitar_convite(),
  public.criar_convite(text, public.papel),
  public.cancelar_convite(uuid),
  public.alterar_usuario(uuid, public.papel, boolean),
  public.alterar_meu_nome(text),
  public.gerar_mensalidades(date),
  public.atualizar_mensalidade(uuid, public.status_mensalidade, public.forma_pagamento, text),
  public.sortear_times(uuid, uuid[], integer)
  to authenticated;

-- ---------- Row Level Security ----------
alter table public.usuarios      enable row level security;
alter table public.convites      enable row level security;
alter table public.configuracoes enable row level security;
alter table public.jogadores     enable row level security;
alter table public.mensalidades  enable row level security;
alter table public.jogos         enable row level security;
alter table public.sorteios      enable row level security;
alter table public.lances        enable row level security;
alter table public.auditoria     enable row level security;

-- Leitura: qualquer usuário ativo (o admin vê convites e auditoria).
create policy usuarios_ler on public.usuarios for select to authenticated
  using ((select public.papel_atual()) is not null);
create policy convites_ler on public.convites for select to authenticated
  using ((select public.papel_atual()) = 'admin');
create policy configuracoes_ler on public.configuracoes for select to authenticated
  using ((select public.papel_atual()) is not null);
create policy jogadores_ler on public.jogadores for select to authenticated
  using ((select public.papel_atual()) is not null);
create policy mensalidades_ler on public.mensalidades for select to authenticated
  using ((select public.papel_atual()) is not null);
create policy jogos_ler on public.jogos for select to authenticated
  using ((select public.papel_atual()) is not null);
create policy sorteios_ler on public.sorteios for select to authenticated
  using ((select public.papel_atual()) is not null);
create policy lances_ler on public.lances for select to authenticated
  using ((select public.papel_atual()) is not null);
create policy auditoria_ler on public.auditoria for select to authenticated
  using ((select public.papel_atual()) = 'admin');

-- Escrita direta: só o que não precisa de regra extra.
create policy jogadores_criar on public.jogadores for insert to authenticated
  with check ((select public.papel_atual()) in ('admin', 'equipe'));
create policy jogadores_editar on public.jogadores for update to authenticated
  using ((select public.papel_atual()) in ('admin', 'equipe'))
  with check ((select public.papel_atual()) in ('admin', 'equipe'));
create policy jogadores_apagar on public.jogadores for delete to authenticated
  using ((select public.papel_atual()) = 'admin');

create policy configuracoes_editar on public.configuracoes for update to authenticated
  using ((select public.papel_atual()) = 'admin')
  with check ((select public.papel_atual()) = 'admin');

create policy jogos_criar on public.jogos for insert to authenticated
  with check ((select public.papel_atual()) in ('admin', 'equipe') and criado_por = (select auth.uid()));
create policy jogos_apagar on public.jogos for delete to authenticated
  using ((select public.papel_atual()) = 'admin');

create policy lances_criar on public.lances for insert to authenticated
  with check ((select public.papel_atual()) in ('admin', 'equipe'));
create policy lances_editar on public.lances for update to authenticated
  using ((select public.papel_atual()) in ('admin', 'equipe'))
  with check ((select public.papel_atual()) in ('admin', 'equipe'));

create policy mensalidades_apagar on public.mensalidades for delete to authenticated
  using ((select public.papel_atual()) = 'admin');
