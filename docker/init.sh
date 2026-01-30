#!/usr/bin/env bash
set -euo pipefail

BENCH_DIR="/home/frappe/frappe-bench"

# helper: start bench if it is valid
start_bench_if_ready() {
  if [ -f "${BENCH_DIR}/Procfile" ]; then
    echo "bench exists, starting"
    cd "${BENCH_DIR}"
    exec bench start
  fi
}

# if bench is valid, just start
start_bench_if_ready

# bench dir exists but is not a valid bench (common with empty named volume)
if [ -d "${BENCH_DIR}" ] && [ ! -f "${BENCH_DIR}/Procfile" ]; then
  echo "bench directory exists but is incomplete, rebuilding it"
  rm -rf "${BENCH_DIR}"
fi

export PATH="${NVM_DIR}/versions/node/v${NODE_VERSION_DEVELOP}/bin/:${PATH}"

# create bench
bench init --skip-redis-config-generation "${BENCH_DIR}"
cd "${BENCH_DIR}"

# configure hosts (now that sites/ exists)
bench set-mariadb-host mariadb
bench set-redis-cache-host redis://redis:6379
bench set-redis-queue-host redis://redis:6379
bench set-redis-socketio-host redis://redis:6379

# remove redis, watch from Procfile
sed -i '/redis/d' ./Procfile || true
sed -i '/watch/d' ./Procfile || true

# get only hrms
bench get-app hrms

SITE_NAME="${SITE_NAME:-hrms.localhost}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-123}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"

bench new-site "${SITE_NAME}" \
  --force \
  --mariadb-root-password "${MYSQL_ROOT_PASSWORD}" \
  --admin-password "${ADMIN_PASSWORD}" \
  --no-mariadb-socket

bench --site "${SITE_NAME}" install-app hrms
bench --site "${SITE_NAME}" set-config developer_mode 1
bench --site "${SITE_NAME}" enable-scheduler
bench --site "${SITE_NAME}" clear-cache
bench use "${SITE_NAME}"

exec bench start
