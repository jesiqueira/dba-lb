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
  - Se rodar o SELECT xmin, xmax, * FROM sua_tabela, podemorá ver esses IDS.
  
### 🔒 Locks e 🧹 Autovacuum
