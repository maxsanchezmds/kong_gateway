#!/usr/bin/env sh
set -eu

TEMPLATE_PATH="/opt/kong-gateway/kong.yml.template"
GENERATED_CONFIG="${KONG_DECLARATIVE_CONFIG:-/tmp/kong.generated.yml}"

log() {
  printf '%s\n' "[kong-gateway] $*"
}

resolve_environment_from_ecs_metadata() {
  if [ -z "${ECS_CONTAINER_METADATA_URI_V4:-}" ]; then
    return 0
  fi

  metadata=""
  if command -v curl >/dev/null 2>&1; then
    metadata="$(curl -fsS "${ECS_CONTAINER_METADATA_URI_V4}/task" 2>/dev/null || true)"
  elif command -v wget >/dev/null 2>&1; then
    metadata="$(wget -qO- "${ECS_CONTAINER_METADATA_URI_V4}/task" 2>/dev/null || true)"
  fi

  if [ -z "$metadata" ]; then
    return 0
  fi

  family="$(printf '%s' "$metadata" | sed -n 's/.*"Family"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
  case "$family" in
    kong-*)
      printf '%s' "${family#kong-}"
      ;;
  esac
}

resolve_namespace() {
  if [ -n "${KONG_SERVICE_DISCOVERY_NAMESPACE:-}" ]; then
    printf '%s' "$KONG_SERVICE_DISCOVERY_NAMESPACE"
    return 0
  fi

  environment="${KONG_ENVIRONMENT:-}"
  if [ -z "$environment" ]; then
    environment="$(resolve_environment_from_ecs_metadata)"
  fi

  case "$environment" in
    main)
      printf '%s' "smartlogix-main.local"
      ;;
    canary)
      printf '%s' "smartlogix-canary.local"
      ;;
    pr-*|ephemeral|"")
      printf '%s' "smartlogix.local"
      ;;
    *)
      printf '%s' "smartlogix.local"
      ;;
  esac
}

validate_namespace() {
  case "$1" in
    *[!a-zA-Z0-9.-]*|""|.*|*.)
      log "ERROR: namespace invalido '$1'"
      exit 1
      ;;
  esac
}

main() {
  if [ ! -f "$TEMPLATE_PATH" ]; then
    log "ERROR: no existe plantilla en $TEMPLATE_PATH"
    exit 1
  fi

  namespace="$(resolve_namespace)"
  validate_namespace "$namespace"

  sed "s|__SERVICE_DISCOVERY_NAMESPACE__|$namespace|g" "$TEMPLATE_PATH" > "$GENERATED_CONFIG"

  kong config parse "$GENERATED_CONFIG" >/dev/null

  log "configuracion renderizada en $GENERATED_CONFIG"
  log "namespace de service discovery: $namespace"

  exec /docker-entrypoint.sh "$@"
}

main "$@"