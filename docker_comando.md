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
