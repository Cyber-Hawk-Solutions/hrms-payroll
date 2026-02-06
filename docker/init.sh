#!/usr/bin/env bash
set -euo pipefail

VOLUME_DIR="/home/frappe/frappe-bench"
BENCH_DIR="${VOLUME_DIR}/bench"

echo "init starting. bench_dir=${BENCH_DIR}"
pwd

# phase 1: if we're root, fix permissions then re-run as frappe
if [ "$(id -u)" -eq 0 ]; then
  echo "running as root, fixing volume ownership..."
  mkdir -p "${VOLUME_DIR}"
  chown -R frappe:frappe "${VOLUME_DIR}" || true

  echo "switching to frappe user..."
  exec su -s /bin/bash frappe -c "SITE_NAME='${SITE_NAME:-}' MYSQL_ROOT_PASSWORD='${MYSQL_ROOT_PASSWORD:-}' ADMIN_PASSWORD='${ADMIN_PASSWORD:-}' bash /workspace/init.sh"
fi

# phase 2: now we're the frappe user, bench imports work
if [ -f "${BENCH_DIR}/Procfile" ] && [ -d "${BENCH_DIR}/sites" ]; then
  echo "bench already exists, starting"
  cd "${BENCH_DIR}"
  exec bench start
fi

echo "creating new bench..."

mkdir -p "${BENCH_DIR}"
find "${BENCH_DIR}" -mindepth 1 -maxdepth 1 -exec rm -rf {} + || true

# don't assume NODE_VERSION_DEVELOP exists
if [ -n "${NVM_DIR:-}" ] && [ -n "${NODE_VERSION_DEVELOP:-}" ]; then
  export PATH="${NVM_DIR}/versions/node/v${NODE_VERSION_DEVELOP}/bin/:${PATH}"
fi

bench init --skip-redis-config-generation "${BENCH_DIR}"
cd "${BENCH_DIR}"

bench set-mariadb-host mariadb
bench set-redis-cache-host redis://redis:6379
bench set-redis-queue-host redis://redis:6379
bench set-redis-socketio-host redis://redis:6379

sed -i '/redis/d' ./Procfile || true
sed -i '/watch/d' ./Procfile || true

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
