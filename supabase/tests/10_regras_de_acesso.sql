-- Testes das regras de acesso e do sorteio. Rode com: supabase/tests/rodar.sh
\set ON_ERROR_STOP 1
\set QUIET 1
\set admin '00000000-0000-0000-0000-00000000000a'
\set equipe '00000000-0000-0000-0000-00000000000e'
\set leitura '00000000-0000-0000-0000-00000000000c'
\set estranho '00000000-0000-0000-0000-0000000000ff'
\set atrasado '00000000-0000-0000-0000-0000000000dd'

create function pg_temp.como(p_uid uuid, p_email text) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_uid, 'email', p_email)::text, false);
$$;
create function pg_temp.ok(cond boolean, msg text) returns void language plpgsql as $$
begin
  if cond is not true then raise exception 'FALHOU: %', msg; end if;
  raise notice 'ok - %', msg;
end $$;
-- Executa um SQL e exige que ele falhe.
create function pg_temp.deve_falhar(p_sql text, msg text) returns void language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    raise notice 'ok - % (%)', msg, sqlerrm;
    return;
  end;
  raise exception 'FALHOU: % (deveria ter dado erro)', msg;
end $$;
grant execute on all functions in schema pg_temp to anon, authenticated;

-- Preparação (como postgres): usuários do Auth e o primeiro admin.
insert into auth.users values
  (:'admin', 'admin@x.com'), (:'equipe', 'equipe@x.com'), (:'leitura', 'leitura@x.com'),
  (:'estranho', 'estranho@x.com'), (:'atrasado', 'atrasado@x.com');
insert into public.usuarios (id, email, nome, papel) values (:'admin', 'admin@x.com', 'Admin', 'admin');

-- 1. Convites
select pg_temp.como(:'admin', 'admin@x.com');
set role authenticated;
select public.criar_convite('Equipe@X.com', 'equipe');
select public.criar_convite('leitura@x.com', 'leitura');
select public.criar_convite('atrasado@x.com', 'equipe');
select pg_temp.deve_falhar($$select public.criar_convite('admin@x.com', 'leitura')$$, 'não convida quem já tem acesso');
reset role;
update public.convites set expira_em = now() - interval '1 minute' where email = 'atrasado@x.com';

select pg_temp.como(:'equipe', 'equipe@x.com'); set role authenticated;
select pg_temp.ok(public.aceitar_convite() = 'equipe', 'convite aceito com perfil equipe (e-mail sem diferenciar maiúsculas)');
select pg_temp.ok(public.aceitar_convite() = 'equipe', 'aceitar de novo devolve o mesmo perfil');
select pg_temp.deve_falhar($$select public.criar_convite('novo@x.com', 'admin')$$, 'equipe não cria convite');
reset role;

select pg_temp.como(:'leitura', 'leitura@x.com'); set role authenticated;
select pg_temp.ok(public.aceitar_convite() = 'leitura', 'convite aceito com perfil leitura');
reset role;

select pg_temp.como(:'atrasado', 'atrasado@x.com'); set role authenticated;
select pg_temp.ok(public.aceitar_convite() is null, 'convite vencido não dá acesso');
reset role;

select pg_temp.como(:'estranho', 'estranho@x.com'); set role authenticated;
select pg_temp.ok(public.aceitar_convite() is null, 'sem convite não dá acesso');
select pg_temp.ok((select count(*) from public.usuarios) = 0, 'sem acesso não enxerga usuários');
select pg_temp.deve_falhar($$insert into public.jogadores (nome) values ('Invasor')$$, 'sem acesso não cadastra jogador');
reset role;

-- 2. anon não acessa nada
set role anon;
select pg_temp.deve_falhar($$select * from public.jogadores$$, 'anon não lê jogadores');
select pg_temp.deve_falhar($$select public.aceitar_convite()$$, 'anon não executa funções');
reset role;

-- 3. Jogadores
select pg_temp.como(:'equipe', 'equipe@x.com'); set role authenticated;
insert into public.jogadores (nome, posicao, nivel, tipo) values
  ('Goleiro A', 'goleiro', 3, 'mensalista'), ('Goleiro B', 'goleiro', 5, 'mensalista'),
  ('Craque 1', 'linha', 5, 'mensalista'), ('Craque 2', 'linha', 5, 'mensalista'),
  ('J1', 'linha', 4, 'mensalista'), ('J2', 'linha', 4, 'mensalista'), ('J3', 'linha', 3, 'mensalista'),
  ('J4', 'linha', 3, 'avulso'), ('J5', 'linha', 2, 'mensalista'), ('J6', 'linha', 2, 'avulso'),
  ('J7', 'linha', 1, 'mensalista'), ('J8', 'linha', 1, 'mensalista');
select pg_temp.deve_falhar($$insert into public.jogadores (nome, nivel) values ('Nivel 6', 6)$$, 'nível fora de 1 a 5 é recusado');
select pg_temp.deve_falhar($$insert into public.jogadores (nome) values ('j1')$$, 'nome repetido é recusado');
delete from public.jogadores where nome = 'J8';
select pg_temp.ok((select count(*) from public.jogadores) = 12, 'equipe não apaga jogador');
reset role;

select pg_temp.como(:'leitura', 'leitura@x.com'); set role authenticated;
select pg_temp.ok((select count(*) from public.jogadores) = 12, 'leitura enxerga jogadores');
select pg_temp.deve_falhar($$insert into public.jogadores (nome) values ('X')$$, 'leitura não cadastra jogador');
update public.jogadores set nivel = 5 where nome = 'J7';
select pg_temp.ok((select nivel from public.jogadores where nome = 'J7') = 1, 'leitura não altera nível');
reset role;

-- 4. Sorteio
select pg_temp.como(:'equipe', 'equipe@x.com'); set role authenticated;
insert into public.jogos (data, criado_por) values ('2026-11-16', :'equipe');
select pg_temp.deve_falhar(
  format($$insert into public.sorteios (jogo_id, times, criado_por) values ('%s', '[]', '%s')$$,
         (select id from public.jogos limit 1), :'equipe'),
  'ninguém grava sorteio direto, só pela função');
select pg_temp.deve_falhar(
  format($$select public.sortear_times('%s', array(select id from public.jogadores), 7)$$, (select id from public.jogos limit 1)),
  'máximo de 6 times');
select pg_temp.deve_falhar(
  format($$select public.sortear_times('%s', array['%s'::uuid], 2)$$, (select id from public.jogos limit 1), gen_random_uuid()),
  'jogador inexistente é recusado');

do $$
declare
  v_jogo uuid := (select id from public.jogos limit 1);
  v_todos uuid[] := array(select id from public.jogadores);
  v_s jsonb; t jsonb; i int; v_cinco int; v_gk int; v_tam int[];
begin
  for i in 1..200 loop
    perform public.sortear_times(v_jogo, v_todos, 3);
    select times into v_s from public.sorteios where jogo_id = v_jogo and ativo;
    v_tam := '{}';
    for t in select * from jsonb_array_elements(v_s) loop
      select count(*) filter (where j.nivel = 5 and j.posicao = 'linha'),
             count(*) filter (where j.posicao = 'goleiro')
        into v_cinco, v_gk
        from public.jogadores j where j.id::text in (select jsonb_array_elements_text(t -> 'jogadores'));
      if v_gk > 1 then raise exception 'FALHOU: dois goleiros no mesmo time'; end if;
      select count(*) into v_cinco from public.jogadores j
       where j.nivel = 5 and j.id::text in (select jsonb_array_elements_text(t -> 'jogadores'));
      if v_cinco > 1 then raise exception 'FALHOU: dois nível 5 no mesmo time: %', t; end if;
      v_tam := v_tam || jsonb_array_length(t -> 'jogadores');
    end loop;
    if (select max(x) - min(x) from unnest(v_tam) x) > 0 then raise exception 'FALHOU: times de tamanhos diferentes %', v_tam; end if;
  end loop;
  raise notice 'ok - 200 sorteios: nunca dois nível 5 juntos, goleiros separados, times do mesmo tamanho';
end $$;
select pg_temp.ok((select count(*) from public.sorteios where ativo) = 1, 'só um sorteio ativo por jogo');
select pg_temp.ok((select count(*) from public.sorteios) = 200, 'sorteios anteriores ficam no histórico');

-- 3 nível 5 para 2 times: avisa, e no máximo 2 por time
select public.sortear_times((select id from public.jogos limit 1), array(select id from public.jogadores), 2);
select pg_temp.ok((select aviso is not null from public.sorteios where ativo), 'avisa quando há mais nível 5 do que times');
reset role;

select pg_temp.como(:'leitura', 'leitura@x.com'); set role authenticated;
select pg_temp.deve_falhar(
  format($$select public.sortear_times('%s', array(select id from public.jogadores), 2)$$, (select id from public.jogos limit 1)),
  'leitura não sorteia');
reset role;

-- 5. Mensalidades
select pg_temp.como(:'equipe', 'equipe@x.com'); set role authenticated;
select pg_temp.ok(public.gerar_mensalidades('2026-11-20') = 10, 'gera 1 mensalidade por mensalista ativo');
select pg_temp.ok(public.gerar_mensalidades('2026-11-01') = 0, 'gerar de novo não duplica');
select pg_temp.deve_falhar(
  $$update public.mensalidades set status = 'paga', pago_em = now(), forma_pagamento = 'pix'$$,
  'ninguém marca pagamento direto na tabela');
select pg_temp.deve_falhar(
  format($$select public.atualizar_mensalidade('%s', 'paga')$$, (select id from public.mensalidades limit 1)),
  'pagamento exige forma de pagamento');
select public.atualizar_mensalidade((select m.id from public.mensalidades m join public.jogadores j on j.id = m.jogador_id where j.nome = 'J1'), 'paga', 'pix', 'pagou no Pix');
select pg_temp.ok(
  (select registrado_por = :'equipe' and pago_em is not null from public.mensalidades m join public.jogadores j on j.id = m.jogador_id where j.nome = 'J1'),
  'pagamento registra quem marcou e quando');
reset role;
update public.mensalidades set vencimento = '2026-01-10' where jogador_id = (select id from public.jogadores where nome = 'J3');

select pg_temp.como(:'leitura', 'leitura@x.com'); set role authenticated;
select pg_temp.ok((select status from public.mensalidades_painel where jogador_nome = 'J3') = 'atrasada', 'aberta e vencida aparece como atrasada');
select pg_temp.ok((select status from public.mensalidades_painel where jogador_nome = 'J1') = 'paga', 'paga aparece como paga');
select pg_temp.deve_falhar(
  format($$select public.atualizar_mensalidade('%s', 'isenta')$$, (select id from public.mensalidades limit 1)),
  'leitura não altera mensalidade');
reset role;

-- 6. Configurações
select pg_temp.como(:'equipe', 'equipe@x.com'); set role authenticated;
update public.configuracoes set valor_mensalidade_centavos = 1;
select pg_temp.ok((select valor_mensalidade_centavos from public.configuracoes) = 10000, 'equipe não muda o valor da mensalidade');
reset role;
select pg_temp.como(:'admin', 'admin@x.com'); set role authenticated;
update public.configuracoes set valor_mensalidade_centavos = 12000;
select pg_temp.ok((select valor_mensalidade_centavos from public.configuracoes) = 12000, 'admin muda o valor da mensalidade');
reset role;

-- 7. Auditoria
select pg_temp.como(:'equipe', 'equipe@x.com'); set role authenticated;
select pg_temp.ok((select count(*) from public.auditoria) = 0, 'equipe não vê a auditoria');
reset role;
select pg_temp.como(:'admin', 'admin@x.com'); set role authenticated;
select pg_temp.ok((select count(*) from public.auditoria where tabela = 'mensalidades' and acao = 'UPDATE' and usuario_id = :'equipe') >= 1,
  'auditoria registra o pagamento com o autor');
select pg_temp.deve_falhar($$delete from public.auditoria$$, 'nem o admin apaga a auditoria');
select pg_temp.deve_falhar($$update public.auditoria set acao = 'x'$$, 'nem o admin altera a auditoria');

-- 8. Gestão de usuários
select pg_temp.deve_falhar(format($$select public.alterar_usuario('%s', 'leitura', true)$$, :'admin'), 'admin não rebaixa a si mesmo');
select public.alterar_usuario(:'leitura', 'leitura', false);
reset role;
select pg_temp.como(:'leitura', 'leitura@x.com'); set role authenticated;
select pg_temp.ok(public.papel_atual() is null, 'usuário desativado perde o acesso');
select pg_temp.ok((select count(*) from public.jogadores) = 0, 'usuário desativado não vê dados');
select pg_temp.ok(public.aceitar_convite() is null, 'usuário desativado não volta por convite antigo');
reset role;
select pg_temp.como(:'equipe', 'equipe@x.com'); set role authenticated;
select pg_temp.deve_falhar(format($$select public.alterar_usuario('%s', 'admin', true)$$, :'equipe'), 'equipe não se promove a admin');
reset role;

\echo 'TODOS OS TESTES PASSARAM'
