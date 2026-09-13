#!/bin/sh
set -e

echo "=== [REPLICA] Waiting for primary PostgreSQL (postgres-primary:5432) to be ready ==="
until pg_isready -h postgres-primary -p 5432 -U postgres; do
  echo "Primary not ready yet. Retrying in 2 seconds..."
  sleep 2
done

echo "=== [REPLICA] Primary is ready! Checking data directory ==="

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  echo "=== [REPLICA] Data directory is empty. Running pg_basebackup from primary ==="
  rm -rf "$PGDATA"/*
  chown -R postgres:postgres "$PGDATA"
  chmod 700 "$PGDATA"

  export PGPASSWORD="ReplicaPassword2026!"
  gosu postgres pg_basebackup \
    -h postgres-primary \
    -p 5432 \
    -U replicator \
    -D "$PGDATA" \
    -Fp \
    -Xs \
    -P \
    -R \
    -S replica_1_slot
  unset PGPASSWORD

  echo "=== [REPLICA] pg_basebackup completed successfully ==="
  chown -R postgres:postgres "$PGDATA"
  chmod 700 "$PGDATA"
fi

echo "=== [REPLICA] Starting PostgreSQL Standby Replica ==="
if [ "$#" -eq 0 ]; then
  set -- postgres -c hot_standby=on -c max_connections=200 -c shared_buffers=128MB
fi
exec gosu postgres "$@"
