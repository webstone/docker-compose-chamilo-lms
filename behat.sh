#!/usr/bin/env bash
# Run the Chamilo Behat suite against the isolated test stack
# (docker compose --profile test up -d).
#
#   ./behat.sh snapshot            save the current test database + uploads
#   ./behat.sh reset               restore the last snapshot
#   ./behat.sh run <feature>...    reset, then run the given feature file(s)
#   ./behat.sh run-all             reset before each feature, run them all
#
# Feature paths are relative to tests/behat, e.g. features/toolDocument.feature
set -euo pipefail

cd "$(dirname "$0")"

DATA_PATH="${BEHAT_DATA_PATH:-./data/behat}"
DB_NAME="${BEHAT_DATABASE_NAME:-chamilo2_behat}"
SNAPSHOT_SQL="$DATA_PATH/snapshot.sql"
SNAPSHOT_UPLOAD="$DATA_PATH/snapshot-upload.tar"
RESULTS="$DATA_PATH/results"

compose() { docker compose --profile test "$@"; }
container() { compose ps -q "$1"; }

db() {
    # The root password stays inside the MariaDB container
    docker exec -i "$(container mariadb)" sh -c "mariadb -uroot -p\"\$MYSQL_ROOT_PASSWORD\" $*"
}

snapshot() {
    docker exec "$(container mariadb)" sh -c \
        "mariadb-dump -uroot -p\"\$MYSQL_ROOT_PASSWORD\" --single-transaction $DB_NAME" > "$SNAPSHOT_SQL"
    # Uploaded files belong to www-data, so archive them from inside the container
    docker exec "$(container chamilo-behat)" tar -C /var/www/chamilo/var -cf - upload > "$SNAPSHOT_UPLOAD"
    echo "Snapshot saved ($(du -h "$SNAPSHOT_SQL" | cut -f1) SQL)"
}

reset() {
    [ -f "$SNAPSHOT_SQL" ] || { echo "No snapshot yet, run: $0 snapshot" >&2; exit 1; }
    db -e "\"DROP DATABASE IF EXISTS $DB_NAME; CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;\""
    db "$DB_NAME" < "$SNAPSHOT_SQL"
    docker exec "$(container chamilo-behat)" sh -c \
        'rm -rf /var/www/chamilo/var/upload/* /var/www/chamilo/var/cache/*/pools/*'
    docker exec -i "$(container chamilo-behat)" sh -c \
        'tar -C /var/www/chamilo/var -xf - && chgrp -R www-data /var/www/chamilo/var/upload && chmod -R g+rwX /var/www/chamilo/var/upload' \
        < "$SNAPSHOT_UPLOAD"
}

run_feature() {
    local feature="$1" name
    name="$(basename "$feature" .feature)"
    mkdir -p "$RESULTS"
    if docker exec -w /var/www/chamilo/tests/behat "$(container chamilo-behat)" \
        php ../../vendor/bin/behat --no-colors "$feature" > "$RESULTS/$name.log" 2>&1; then
        echo "PASS  $name"
    else
        echo "FAIL  $name  (see $RESULTS/$name.log)"
        return 1
    fi
}

case "${1:-}" in
    snapshot) snapshot ;;
    reset) reset; echo "Reset to snapshot" ;;
    run)
        shift
        [ $# -gt 0 ] || { echo "Usage: $0 run <feature>..." >&2; exit 1; }
        status=0
        for f in "$@"; do reset; run_feature "$f" || status=1; done
        exit $status
        ;;
    run-all)
        status=0
        for f in $(docker exec -w /var/www/chamilo/tests/behat "$(container chamilo-behat)" \
            sh -c 'ls features/*.feature' | grep -v actionInstall); do
            reset; run_feature "$f" || status=1
        done
        exit $status
        ;;
    *) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
