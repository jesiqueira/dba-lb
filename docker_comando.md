## 1 . Conectar de dentro do container

- Use quando você já tem um container PostgreSQL rodando.

```sql
--  Descobrir o nome/ID do container
  docker ps
```

```sql
  docker composer up -d
```

## Executar psql via docker

```sql
  docker exec -it container_name psql -U POSTGRES_USER -d POSTGRES_DB
```

## 1️⃣ Entrar no container do Postgres (shell)
Primeiro, descubra o container:
```sql
docker ps
```
Depois entre nele:
```sql
docker exec -it <nome_ou_id_do_container> bash
```

## 2️⃣ Onde ficam os arquivos de configuração do Postgres no Docker
Na imagem oficial do Postgres, os arquivos costumam ficar em:
```
/var/lib/postgresql/data/
```
Arquivos principais:
```

postgresql.conf
pg_hba.conf
pg_ident.conf

```

## 3️⃣ Visualizar os arquivos de configuração
Ver o conteúdo:
```

cat postgresql.conf
cat pg_hba.conf
cat pg_ident.conf

```

Ou usando um pager:
```
less postgresql.conf
```

## 4️⃣ Descobrir exatamente onde o Postgres está usando os arquivos
Às vezes o caminho muda (volume customizado, imagem diferente, etc).
A forma mais segura é perguntar ao próprio Postgres 👇

### Pelo psql (dentro do container):
````sql
docker exec -it meu-postgres psql -U postgres
````
Dentro do psql:
```sql

SHOW config_file;
SHOW hba_file;
SHOW data_directory;

```
Isso vai retornar algo como:
```

/var/lib/postgresql/data/postgresql.conf
/var/lib/postgresql/data/pg_hba.conf

```
✅ Essa é a forma mais confiável.


## 5️⃣ Acessar usando Docker Compose
Se você usa docker compose e seu serviço se chama db:
```sql
docker compose exec db bash
```
Depois:
```sql

cd /var/lib/postgresql/data
ls

```
Ou direto:
```sql
docker compose exec db cat /var/lib/postgresql/data/postgresql.conf
```

## 6️⃣ Editar arquivos de configuração (com cuidado)
### Editar dentro do container:
```sql

vi postgresql.conf
# ou
nano postgresql.conf

```
Depois reinicie o container para aplicar:
```sql
docker restart meu-postgres
```