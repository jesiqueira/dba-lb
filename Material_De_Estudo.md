# Entendendo o Banco de Dados Postgres

## Comandos
```bash 
  SELECT version();
  # Este comando retorna a certidão de nascimento do servidor
  # o que faz: Consulta função interna do sistema que exibe a versão exata do motor de banco de dados. S.O onde está rodando e qual o compilador foi usado
  SHOW shared_buffers;
  # Este é um dos parâmentros mais importante de performance do Postres. O que faz: Mostra quanta memória RAM o PostgreSQL reserva para fazer cache de dados. Sempre que você lê uma tabela, o Postgre joga os dados aqui para que a próxima leitura seja instantânea (na memória) em vez do disco.
  SHOW work_mem;
  # O que faz: Define a quantidade de memória usada por cada operação interna de busca (como ordenações ORDER BY ou junções JOIN)
  # importante: Diferente de shared_buffers, esse valor não é global. Se 10 usuário rodarem uma consulta complexa ao mesmo tempo, o banco pode usar 10x esse valor
  # OBS.: valores default são baixo, exemplo: 4MB. Se tentar ordenar uma tabela gigante que não cabe nesse 4MB, o Postgres usará o disco rígido, o que deixará a consulta lenta
  SHOW max_connections;
  # O que faz: Define o número máximo de clientes (usuários, sistemas, instâncias de pgAdmin) que podem estar conectados ao mesmo tempo.
```

### MVCC (Multiversion Concurrency Control ou Controle de Concorrência de Multiplas Versões)
- é a tecnologia que permite que o PostgreSQL seja extremamente rápido e eficiente, permitindo que várias pessoas leiam e escrevam no banco ao mesmo tempo sem que uma trave a outra.
- No Postgres, o lema do MVCC é: Leitores não bloqueiam escritores, e escritores não bloqueiam leitores.
- Como isso funciona: Em banco de dados antigos, se estivesse lendo uma tabela, ninguém poderia alterá-la ate você terminar. No MVCC, o banco não sobrescreve os dados imediatamente. Em vez disso ele mantém versões diferentes da mesma linha.
- imagine que você tem uma linha em uma tabela.
  - 1 . INSERT: o Postgres cria a versão 1 daquela linha e marca quem a criou.
  - 2 . UPDATE: Em vez de apagar a versão 1 e escrever por cima. O postgres marca como expirada e cria a versão 2
  - 3 . SELECT: Se alguém pedir os dados enquanto o Update está acontecendo, o Postgres entrega a versão 1. (Que ainda é a ultima vesão confirmada.) 
- Obs.: Cada linha do banco tem compos que não vemos, mas o que o MVCC usa para organizar.
  - xmin: O ID da transação que criou aquela linha.
  - xmax: O ID da transação que deletou ou alterou aquela linha.
  - Se rodar o SELECT xmin, xmax, * FROM sua_tabela, poderá ver esses IDS.
  
# 🔒 Locks e 🧹 Autovacuum

## 🔒 LOCK (bloqueios) no PostgreSQL
- Quando o PostgreSQL executa operações, ele precisa garantir consistência e isolamento. Para isso, ele usa locks (bloqueios) em linhas, tabelas e transações.
-  ✅ Tipos de bloqueios mais comuns:
   1. Row-Level Locks (bloqueio de linha). Acontecem quando você faz:
       ```sql
      UPDATE tabela SET ... WHERE id = 1;
      ```
      Isso trava somente a linha, permitindo que outras transações leiam, mas impeçam outras transações de alterarem a mesma linha.
   2.  Table Locks (bloqueio de tabela). Gerados por operações como:
        ```sql
        ALTER TABLE ...
        DROP TABLE ...
        ```
- Esses bloqueios impedem que outros modifiquem ou usem a tabela enquanto a operação não termina.
### 🔎 Como ver bloqueios ativos:
```sql
  SELECT * FROM pg_locks;

  -- Ou um comando mais amigável:
  
  SELECT pid, locktype, relation::regclass AS tabela, mode, granted FROM pg_locks WHERE relation IS NOT NULL;

```
### 🚨 Problema comum: LOCKS presos
Acontece quando:
- a aplicação faz BEGIN mas não dá COMMIT
- transações longas
- operações pesadas (ex: VACUUM FULL, ALTER TABLE)

Esses locks podem travar o banco, causar lentidão e até impedir inserts/updates.

## 🧹 AUTOVACUUM

O autovacuum é um processo automático do PostgreSQL que mantém o banco saudável. Ele limpa fragmentos, organiza espaço e atualiza estatísticas, tudo em background.

Por que ele existe?
- PostgreSQL usa MVCC (controle de concorrência multiversão).
- Então quando uma linha é alterada, ele não sobrescreve — cria uma nova versão, e a antiga vira "lixo".
- Esse lixo precisa ser removido → vacuum
- E estatísticas precisam ser atualizadas → analyze

O que o AUTOVACUUM faz:

1. Remove tuplas mortas (dead tuples)
2. Garante que as tabelas não cresçam desnecessariamente.
3. Evita bloat (inchaço da tabela)
4. Atualiza estatísticas para o planner
5. Melhora performance nas queries.
6. Previne a temida “wraparound”  (que pode travar o banco inteiro!)

### Ver processos de autovacuum em execução:
```sql
  SELECT * FROM pg_stat_activity WHERE query LIKE '%autovacuum%';
```
Configurações importantes do autovacuum:
```sql
SHOW autovacuum;
SHOW autovacuum_naptime;
SHOW autovacuum_vacuum_threshold;
SHOW autovacuum_vacuum_scale_factor
```

Se autovacuum estiver desabilitado, o banco pode começar a:

- ficar lento
- consumir mais disco
- criar tabelas gigantes (bloat)
- sofrer risco de wraparound

### 🚀 Resumo rápido
| tema | Função | Impacto|
| -----| -------| -------|
| LOCK | Garante isolamento e consistência | Pode causar travamentos se mal gerenciado|
| AUTOVACUUM | Limpa lixo e atualiza estatísticas | Mantém o banco rápido e saudável |

# ✔️ Interpretação dos locks 

```sql
  SELECT pid, locktype, mode, granted FROM pg_locks;
```

 |pid |   locktype    |       mode       | granted|
 |----|---------------|------------------|--------|
 | 67 | relation      | AccessShareLock  | t |
 | 67 | virtualxid    | ExclusiveLock    | t |
 | 47 | relation      | RowExclusiveLock | t |
 | 47 | relation      | RowExclusiveLock | t |
 | 47 | virtualxid    | ExclusiveLock    | t |
 | 40 | relation      | RowExclusiveLock | t |
 | 40 | relation      | RowExclusiveLock | t |
 | 40 | virtualxid    | ExclusiveLock    | t |
 | 47 | transactionid | ShareLock        | f |
 | 40 | transactionid | ExclusiveLock    | t |
 | 47 | transactionid | ExclusiveLock    | t |
 | 47 | tuple         | ExclusiveLock    | t |

 ## 🧵 1. O que cada PID significa?
 - ### PID 40 e PID 47
   -  Estão fazendo operações de escrita (UPDATE/INSERT/DELETE), porque possuem RowExclusiveLock, ExclusiveLock e até tuple-level lock.
-  ### PID 67
   -  Está fazendo uma leitura (SELECT), pois possui AccessShareLock.

## 🔍 2. Explicando cada lock de forma simples

### 🔵 AccessShareLock (t)
```
  Quem: PID 67
  O que significa:
  Esse é o lock mais leve do PostgreSQL — ocorre quando você faz um SELECT.
  Ele não bloqueia escrita e é totalmente normal.
```

### 🟡 RowExclusiveLock (t)
```
Quem: PID 40 e 47
Causa:
  Criado por operações como:
  INSERT
  UPDATE
  DELETE
```
Esse lock impede outras transações de alterarem a mesma tabela, mas não impede SELECTs.

### 🔴 tuple | ExclusiveLock (t)
```
Quem: PID 47
Causa:
Esse é o lock por linha (row-level), gerado por:

UPDATE tabela WHERE id = ...
```
Ou seja, uma linha específica está travada por um UPDATE ativo.

### 🟣 transactionid | ShareLock (f)
```
Quem: PID 47
O que significa:
Esse lock não foi concedido (granted = f).
Isso é um indício de que PID 47 está ESPERANDO outro processo liberar um lock.
```
Ou seja, existe espera de lock (lock contention).


## 🔥 Qual é o provável cenário?
### 📌 PID 40 e PID 47 estão fazendo escritas em tabelas possivelmente iguais.
### 📌 PID 47 está preso esperando um lock que ainda não foi liberado por outro processo.

### Isso costuma acontecer quando:
 - Uma transação começou (BEGIN) mas ainda não deu COMMIT
 - Um UPDATE está preso aguardando outra transação terminar
 - A aplicação deixou uma transação aberta sem querer

# 🧭 Como investigar melhor
## Ver quem são esses PIDs e suas queries:
```sql
SELECT pid, state, query 
FROM pg_stat_activity 
WHERE pid IN (40, 47, 67);

```
## Ver qual tabela o lock está atingindo:
```sql

SELECT 
    pid, 
    relation::regclass AS tabela, 
    mode,
    granted
FROM pg_locks
WHERE pid IN (40, 47, 67)
AND relation IS NOT NULL;


```
## Ver quem está BLOQUEANDO quem:
```sql

SELECT
  blocked.pid  AS pid_bloqueado,
  blocked.state AS estado_bloqueado,
  blocked.query AS query_bloqueada,
  blocker.pid  AS pid_bloqueador,
  blocker.state AS estado_bloqueador,
  blocker.query AS query_bloqueadora
FROM pg_stat_activity AS blocked
JOIN pg_stat_activity AS blocker
  ON blocker.pid = ANY (pg_blocking_pids(blocked.pid))
ORDER BY blocked.pid;

```
## Esse comando é ouro — mostra claramente:

- quem está travando
- quem está sendo travado
- e qual é a query que causou o bloqueio

# 🚑 Se quiser matar o processo que está travando tudo
```sql
  SELECT pg_terminate_backend( PID );
```
### ⚠️ Cuidado: isso cancela a transação e desfaz o que ela estava fazendo.

# 🧪 Deadlock

## 🔥 O QUE É UM DEADLOCK?

Um deadlock ocorre quando duas (ou mais) transações ficam esperando uma à outra, formando um ciclo de dependências impossível de resolver.
### ➡️ Cada transação segura um lock que a outra precisa.
### ➡️ E nenhuma consegue continuar.


<h4>Como consequência:</h4>

- Nenhuma transação consegue prosseguir
- O PostgreSQL detecta automaticamente o deadlock
- Ele mata uma transação com erro:

## 🎯 EXEMPLO PRÁTICO (O MAIS CLÁSSICO EM POSTGRES)
Imagine duas linhas em uma tabela de usuários:

- Transação A atualiza linha 1, depois tenta atualizar linha 2
- Transação B atualiza linha 2, depois tenta atualizar linha 1

### Sessão A
```sql

BEGIN;

UPDATE usuarios SET nome = 'A1' WHERE id = 1;
-- trava linha 1

UPDATE usuarios SET nome = 'A2' WHERE id = 2;
-- fica esperando linha 2, porque a sessão B já a travou

```

### Sessão B
```sql

BEGIN;

UPDATE usuarios SET nome = 'B1' WHERE id = 2;
-- trava linha 2

UPDATE usuarios SET nome = 'B2' WHERE id = 1;
-- fica esperando linha 1, porque a sessão A já a travou

```
Formou o ciclo:
 - A espera B
 - B espera A

###  ➡️ Isso é um deadlock.

### 🧠 QUAL A DIFERENÇA ENTRE LOCK E DEADLOCK?

| Situação | O que Acontece |
| ---------| ---------------|
| 🔒 Lock normal | Uma transação espera a outra terminar. Natural. |
| 🔥 Deadlock | Nenhuma pode continuar. Estão esperando recursos uma da outra. Nunca vai destravar sozinho.| 
---

### 🧠 COMO O POSTGRES DETECTA DEADLOCK?
O PostgreSQL tem um deadlock detector que roda periodicamente.
Quando ele percebe que existe um ciclo de espera, ele:
- 1️⃣ Identifica as transações envolvidas
- 2️⃣ Escolhe uma para cancelar
- 3️⃣ Libera os locks
- 4️⃣ Permite que a outra continue
  
A transação cancelada recebe:
### Log de Erro
> **ERROR:** deadlock detected  
> **DETAIL:** Process 385 waits for ShareLock on transaction 745; blocked by process 61.  
> Process 61 waits for ShareLock on transaction 746; blocked by process 385.  
> **CONTEXT:** while updating tuple (934,64) in relation "usuarios"

---

## 🛠️ O que aconteceu? (Cenário de Exemplo)

O banco de dados interrompeu o **Processo 385** para permitir que o **Processo 61** continuasse, evitando um travamento infinito. O fluxo lógico que gerou o erro foi:

| Passo | Transação A (Processo 385) | Transação B (Processo 61) |
| :--- | :--- | :--- |
| 1 | Inicia e bloqueia o **Usuário ID: 1** | Inicia e bloqueia o **Usuário ID: 2** |
| 2 | Tenta bloquear o **Usuário ID: 2** | Tenta bloquear o **Usuário ID: 1** |
| 3 | **AGUARDANDO...** (esperando Proc 61) | **AGUARDANDO...** (esperando Proc 385) |
| 4 | **CANCELADO PELO BANCO** | **EXECUÇÃO CONTINUA** |


---

## 🔍 Causas Comuns
1. **Ordem Inconsistente:** Processos que atualizam os mesmos registros em ordens diferentes (ex: A->B e B->A).
2. **Transações Longas:** Muitas operações entre o início e o fim da transação, segurando travas por muito tempo.
3. **Falta de Índices:** Pode forçar o banco a travar mais linhas do que o necessário (Sequential Scan) para encontrar o registro.

---

## ✅ Como Prevenir

1. **Padronização de Ordem:** Garantir que todos os processos atualizem registros seguindo sempre a mesma lógica (ex: sempre ordenar os IDs em ordem crescente antes de fazer o UPDATE).
2. **Atomicidade:** Realizar apenas as operações necessárias dentro de `BEGIN` e `COMMIT`.
3. **Retry Logic:** Implementar na camada da aplicação um mecanismo de tentativa (retry) caso o erro de deadlock ocorra.
4. **Select For Update:** Usar o `SELECT ... FOR UPDATE` com cautela e, se possível, com a cláusula `SKIP LOCKED` ou `NOWAIT` para evitar filas de espera.

---

## 🔧 COMO INVESTIGAR DEADLOCKS DE VERDADE

PostgreSQL registra no log.

Para ver detalhes no psql:

### Mostrar quem está esperando por quem:
```sql

SELECT
  blocked.pid AS pid_bloqueado,
  blocked.query AS query_bloqueada,
  blocker.pid AS pid_bloqueador,
  blocker.query AS query_bloqueadora
FROM pg_stat_activity blocked
JOIN LATERAL unnest(pg_blocking_pids(blocked.pid)) AS p(blocking_pid) ON TRUE
JOIN pg_stat_activity blocker ON blocker.pid = p.blocking_pid;

-- Esse comando já usamos e funciona para deadlock antes do cancelamento.

```

## 📝 Comandos Úteis para Investigação
Para monitorar travas em tempo real:
```sql
SELECT * FROM pg_locks l 
JOIN pg_stat_activity a ON l.pid = a.pid 
WHERE NOT l.granted;
```
## 🛡️ COMO EVITAR DEADLOCKS (DICAS DE OURO)

### ✔ 1. Atualize linhas SEMPRE NA MESMA ORDEM
Deadlocks quase sempre vêm disso.

Exemplo:
```sql
UPDATE tabela SET ... WHERE id IN (1, 2) ORDER BY id;
```

### ✔ 2. Mantenha transações curtas
- Evita “guardar” locks por tempo demais.

### ✔ 3. Evite SELECT ... FOR UPDATE desnecessário
- Isso cria locks que podem causar ciclo.

### ✔ 4. Use índices eficientes
- Quanto mais rápido localizar a linha, menos tempo segurando locks.

### ✔ 5. Evite “idle in transaction”
- Esse é o maior causador de bloqueios, e você viu isso AO VIVO no seu teste anterior.

