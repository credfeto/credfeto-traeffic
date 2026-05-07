#!/bin/sh
set -e

die() {
    printf '\n\033[31m✗\033[0m %s\n' "$*" >&2
    exit 1
}

success() {
    printf '\n\033[32m✓\033[0m %s\n' "$*"
}

info() {
    printf '\n\033[32m→\033[0m %s\n' "$*"
}

TEMPLATE=/templates/dynamic_conf.yml.template
OUTPUT=/config/dynamic_conf.yml

[ -f "${TEMPLATE}" ] || die "Template not found: ${TEMPLATE}"
[ -n "${PHOTOS_LOCAL_SECRET}" ] || die "PHOTOS_LOCAL_SECRET is not set"

info "Generating Traefik dynamic config from template..."

awk -v secret="${PHOTOS_LOCAL_SECRET}" \
    '{gsub(/\$\{PHOTOS_LOCAL_SECRET\}/, secret)}1' \
    "${TEMPLATE}" > "${OUTPUT}"

success "Config written to ${OUTPUT}"
