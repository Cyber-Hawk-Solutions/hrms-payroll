#!/usr/bin/env bash
set -euo pipefail

BENCH_DIR="/home/frappe/frappe-bench"

# if a real bench already exists, start it
if [ -f "${BENCH_DIR}/Procfile" ]; then
  echo "bench already exists, starting"
  cd "${BENCH_DIR}"
  exec bench start
fi

# if the directory exists but is empty/broken, clear its CONTENTS (not the mount)
# this avoids "device or resource busy"
if [ -d "${BENCH_DIR}" ]; then
  echo "bench dir present but not initialized, clearing contents"
  rm -rf "${BENCH_DIR:?}/"* "${BENCH_DIR}"/.[!.]* "${BENCH_DIR}"/..?* 2>/dev/null || true
fi

export PATH="${NVM_DIR}/versions/node/v${NODE_VERSION_DEVELOP}/bin/:${PATH}"

# init bench into the fixed mount path
bench init --skip-redis-config-generation "${BENCH_DIR}"

cd "${BENCH_DIR}"

# configure hosts
bench set-mariadb-host mariadb
bench set-redis-cache-host redis://redis:6379
bench set-redis-queue-host redis://redis:6379
bench set-redis-socketio-host redis://redis:6379

# remove redis, watch from Procfile (ok if not present)
sed -i '/redis/d' ./Procfile || true
sed -i '/watch/d' ./Procfile || true

# apps
bench get-app hrms

SITE_NAME="${SITE_NAME:-hrms.localhost}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-123}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"

bench new-site "$SITE_NAME" \
  --force \
  --mariadb-root-password "$MYSQL_ROOT_PASSWORD" \
  --admin-password "$ADMIN_PASSWORD" \
  --no-mariadb-socket

bench --site "$SITE_NAME" install-app hrms
bench --site "$SITE_NAME" set-config developer_mode 1
bench --site "$SITE_NAME" enable-scheduler
bench --site "$SITE_NAME" clear-cache
bench use "$SITE_NAME"

exec bench start
