# pa-project-prisma
N392-87 - PA2 | Projeto Prisma

Desenvolvimento<br>
03/03 a 12/03 - Sprint 01<br>
17/03 a 31/03 - Sprint 02<br>
07/04 a 16/04 - Sprint 03<br>
23/04 a 30/04 - Sprint 04<br>
05/05 a 14/05 - Sprint 05<br>
19/05 a 28/05 - Sprint 06<br>

---

## Requisitos

- [Docker](https://www.docker.com/) + [Docker Compose](https://docs.docker.com/compose/)

---

## Subindo o projeto

```bash
docker compose up --build
```

Acesse em: http://localhost:4000

---

## Parando o projeto

```bash
# Para os containers
docker compose down

# Para os containers e apaga os dados do banco
docker compose down -v
```

---

## Migrations

```bash
docker compose run --rm app mix ecto.migrate
```

---

## Testes

```bash
# Rodar todos os testes
docker compose run --rm -e MIX_ENV=test app mix test

# Rodar um arquivo específico
docker compose run --rm -e MIX_ENV=test app mix test test/caminho/do_test.exs

# Rodar somente os testes que falharam anteriormente
docker compose run --rm -e MIX_ENV=test app mix test --failed

# Modo watch (TDD) — re-executa ao salvar arquivos
docker compose run --rm -e MIX_ENV=test app mix test.watch
```

> `mix test.watch` requer a dep `mix_test_watch`. Para instalar, adicione `{:mix_test_watch, "~> 1.0", only: :dev, runtime: false}` no `mix.exs` e rode `docker compose run --rm app mix deps.get`.


