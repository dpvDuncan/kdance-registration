#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
readonly QUADLET_SOURCE="$SCRIPT_DIR/quadlet"
readonly UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/containers/systemd"
readonly IMAGE="localhost/kdance-backend:latest"
readonly OLD_UNIT_PREFIX='%h/GitHub/kdance-registration/kdance'

die() {
    printf 'Erreur: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "commande requise introuvable: $1"
}

env_value() {
    local file="$1" key="$2"
    awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$file"
}

escape_sed_replacement() {
    printf '%s' "$1" | sed 's/[\\&|]/\\&/g'
}

if (( EUID == 0 )); then
    die "lancez ce script comme utilisateur normal avec Podman rootless, pas avec sudo"
fi

for command in podman systemctl install sed awk; do
    require_command "$command"
done

systemctl --user show-environment >/dev/null 2>&1 \
    || die "systemd utilisateur indisponible; ouvrez une session systemd ou activez le lingering"

rootless="$(podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null)" \
    || die "impossible d'interroger Podman"
[[ "$rootless" == true ]] || die "Podman n'est pas configuré en mode rootless pour cet utilisateur"

if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
    cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
    chmod 600 "$SCRIPT_DIR/.env"
    die "j'ai créé kdance/.env; configurez-le puis relancez ce script"
fi

if [[ ! -f "$QUADLET_SOURCE/mysql.env" ]]; then
    cp "$QUADLET_SOURCE/mysql.env.example" "$QUADLET_SOURCE/mysql.env"
    chmod 600 "$QUADLET_SOURCE/mysql.env"
    die "j'ai créé kdance/quadlet/mysql.env; configurez-le puis relancez ce script"
fi

chmod 600 "$SCRIPT_DIR/.env" "$QUADLET_SOURCE/mysql.env"

for key in DB_NAME DB_USER DB_PASSWORD; do
    value="$(env_value "$SCRIPT_DIR/.env" "$key")"
    [[ -n "$value" && "$value" != replace-with-* ]] \
        || die "configurez $key dans kdance/.env avant le déploiement"
done

for key in MARIADB_DATABASE MARIADB_USER MARIADB_PASSWORD MARIADB_ROOT_PASSWORD; do
    value="$(env_value "$QUADLET_SOURCE/mysql.env" "$key")"
    [[ -n "$value" && "$value" != replace-with-* ]] \
        || die "configurez $key dans kdance/quadlet/mysql.env avant le déploiement"
done

[[ "$(env_value "$SCRIPT_DIR/.env" DB_NAME)" == "$(env_value "$QUADLET_SOURCE/mysql.env" MARIADB_DATABASE)" ]] \
    || die "DB_NAME et MARIADB_DATABASE doivent avoir la même valeur"
[[ "$(env_value "$SCRIPT_DIR/.env" DB_USER)" == "$(env_value "$QUADLET_SOURCE/mysql.env" MARIADB_USER)" ]] \
    || die "DB_USER et MARIADB_USER doivent avoir la même valeur"
[[ "$(env_value "$SCRIPT_DIR/.env" DB_PASSWORD)" == "$(env_value "$QUADLET_SOURCE/mysql.env" MARIADB_PASSWORD)" ]] \
    || die "DB_PASSWORD et MARIADB_PASSWORD doivent avoir la même valeur"

case "$REPO_DIR" in
    *[[:space:]]*) die "le chemin du dépôt ne doit pas contenir d'espaces: $REPO_DIR" ;;
esac

replacement="$(escape_sed_replacement "$REPO_DIR/kdance")"
mkdir -p "$UNIT_DIR"

# Stop prior units before replacing their Quadlet sources.
systemctl --user stop kdance-backend.service kdance-db.service kdance-pod.service \
    kdance-registration-pod.service >/dev/null 2>&1 || true

rm -f "$UNIT_DIR/kdance-db.network"
for unit in kdance-mariadb.volume kdance-registration.pod kdance-db.container kdance-backend.container; do
    source="$QUADLET_SOURCE/$unit"
    [[ -f "$source" ]] || die "fichier Quadlet manquant: $source"
    sed "s|$OLD_UNIT_PREFIX|$replacement|g" "$source" > "$UNIT_DIR/$unit"
    chmod 644 "$UNIT_DIR/$unit"
done

podman build -t "$IMAGE" -f "$SCRIPT_DIR/Dockerfile" "$SCRIPT_DIR"
systemctl --user daemon-reload
systemctl --user start kdance-registration-pod.service

echo "wait for containers start"
sleep 15

podman exec kdance_backend python /app/manage.py migrate --noinput

linger="$(loginctl show-user "$USER" --property=Linger --value 2>/dev/null || true)"
if [[ "$linger" != yes ]]; then
    printf 'Attention: pour démarrer le pod au boot sans session ouverte, exécutez: sudo loginctl enable-linger %s\n' "$USER" >&2
fi

printf 'Déploiement terminé. Application: http://localhost:8000\n'