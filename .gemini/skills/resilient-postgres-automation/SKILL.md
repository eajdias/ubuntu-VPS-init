---
name: resilient-postgres-automation
description: Procedures for resilient PostgreSQL setup in Docker automation, including password synchronization between config files and existing volumes, safe password encoding, and wait-for-ready loops. Use when automating Postgres deployment or fixing authentication/connectivity issues in Docker stacks.
---

# Resilient Postgres Automation

Automating PostgreSQL within Docker environments requires handling persistence edge cases and ensuring secure credential propagation across various connection methods (TCP, local socket, URI).

## Procedures

### 1. Synchronize Internal Password with Config
If a Postgres Docker volume already exists from a previous run, updating `POSTGRES_PASSWORD` in the `.env` file does **NOT** update the password inside the database. This leads to authentication failures for applications connecting via TCP.

Add this step after the container is running to force the internal password to match your configuration:

```bash
# Use dollar-quoting ($$) to safely handle special characters (like single quotes)
docker exec <container_name> psql -U "$PG_USER" -d postgres -c "ALTER USER \"$PG_USER\" WITH PASSWORD \$\$${PG_PASSWORD}\$\$;" > /dev/null
```

### 2. URL-Encode Passwords for Connection URIs
Passwords containing characters like `@`, `/`, `?`, or `:` will break connection URIs (e.g., `postgresql://user:pass@host:port/db`).

Use `jq` to safely URL-encode the password before constructing the URI:

```bash
PG_PASSWORD_ENCODED=$(jq -nr --arg v "$PG_PASSWORD" '$v|@uri')
DATABASE_URL="postgresql://${PG_USER}:${PG_PASSWORD_ENCODED}@${PG_HOST}:${PG_PORT}/${PG_DB}"
```

### 3. Reliable Wait-for-Ready Loop
Ensure the database is fully initialized and accepting connections before running migrations or starting dependent services.

```bash
echo "Waiting for postgres..."
until docker exec <container_name> pg_isready -U "$PG_USER" &>/dev/null; do
    printf '.'; sleep 2
done
echo "Postgres is ready."
```

## Verification
- Change the password in your `.env` file and re-run the automation. Verify that dependent apps can still connect.
- Use a password with special characters (e.g., `P@ss'word!`) and verify the URI and SQL sync still work.

## Pitfalls
- **Heredoc EOF**: Ensure `EOF` markers are not indented unless using `<<-`.
- **Local vs TCP**: Postgres often allows local connections (socket) without a password by default (`trust` method), but requires a password for TCP connections. Testing connection via `docker exec ... psql` may pass while application connection fails. Always test with a TCP-based client if possible.
