#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly MANIFEST="${PROJECT_DIR}/kubernetes-lab.yaml"
readonly PROFILE="${PROFILE:-asi-k8s}"
readonly NAMESPACE="${NAMESPACE:-tp-kubernetes}"
readonly DEPLOYMENT="${DEPLOYMENT:-portal}"
readonly SERVICE="${SERVICE:-portal}"
readonly LABEL_SELECTOR="app=portal"
readonly TIMEOUT="${TIMEOUT:-180s}"

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "falta el comando requerido: $1"
}

require_kubernetes_tools() {
  need kubectl
  need minikube
}

assert_lab_context() {
  local current_context
  current_context="$(kubectl config current-context 2>/dev/null || true)"
  [[ "${current_context}" == "${PROFILE}" ]] || die \
    "el contexto actual es '${current_context:-ninguno}'; seleccione '${PROFILE}'"
}

wait_for_portal() {
  kubectl -n "${NAMESPACE}" rollout status \
    "deployment/${DEPLOYMENT}" --timeout="${TIMEOUT}"
}

show_status() {
  kubectl -n "${NAMESPACE}" get deployments,pods,services -o wide
}

start_cluster() {
  need docker
  require_kubernetes_tools
  need curl

  docker info >/dev/null
  printf 'Docker Server: '
  docker info --format '{{.ServerVersion}}'
  minikube version
  kubectl version --client

  minikube start -p "${PROFILE}" --driver=docker --cpus=2 --memory=4096
  kubectl config use-context "${PROFILE}" >/dev/null
  kubectl wait --for=condition=Ready node --all --timeout="${TIMEOUT}"
  kubectl get nodes -o wide
}

validate_manifest() {
  need kubectl
  kubectl kustomize "${PROJECT_DIR}" >/dev/null
  printf 'YAML válido y renderizado correctamente: %s\n' "${MANIFEST}"
}

deploy_portal() {
  require_kubernetes_tools
  assert_lab_context
  kubectl apply -f "${MANIFEST}"
  wait_for_portal
  show_status
}

print_url() {
  require_kubernetes_tools
  assert_lab_context
  minikube -p "${PROFILE}" service "${SERVICE}" \
    -n "${NAMESPACE}" --url
}

request_portal() {
  need curl
  local portal_url="${1:-${TP_URL:-}}"
  [[ -n "${portal_url}" ]] || die \
    "indique la URL como argumento o mediante TP_URL"

  local attempt
  for attempt in {1..20}; do
    printf '%02d: ' "${attempt}"
    curl --fail --silent --show-error --max-time 3 \
      -H 'Connection: close' "${portal_url}"
  done
}

scale_portal() {
  require_kubernetes_tools
  assert_lab_context
  local replicas="${1:-}"
  [[ "${replicas}" =~ ^[1-9][0-9]*$ ]] || die \
    "la cantidad de réplicas debe ser un entero positivo"

  kubectl -n "${NAMESPACE}" scale \
    "deployment/${DEPLOYMENT}" --replicas="${replicas}"
  wait_for_portal
  kubectl -n "${NAMESPACE}" get deployment "${DEPLOYMENT}"
  kubectl -n "${NAMESPACE}" get pods -l "${LABEL_SELECTOR}" -o wide
}

self_heal() {
  require_kubernetes_tools
  assert_lab_context

  local desired victim before_names deadline ready current_names pod_count
  local replacement pod
  desired="$(kubectl -n "${NAMESPACE}" get deployment "${DEPLOYMENT}" \
    -o jsonpath='{.spec.replicas}')"
  before_names="$(kubectl -n "${NAMESPACE}" get pods -l "${LABEL_SELECTOR}" \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')"
  victim="$(kubectl -n "${NAMESPACE}" get pods -l "${LABEL_SELECTOR}" \
    -o jsonpath='{.items[0].metadata.name}')"
  [[ -n "${victim}" ]] || die "no se encontró ningún Pod del portal"

  printf 'Pod seleccionado para eliminar: %s\n' "${victim}"
  kubectl -n "${NAMESPACE}" delete pod "${victim}" --wait=true

  deadline=$((SECONDS + 180))
  while ((SECONDS < deadline)); do
    ready="$(kubectl -n "${NAMESPACE}" get deployment "${DEPLOYMENT}" \
      -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
    current_names="$(kubectl -n "${NAMESPACE}" get pods -l "${LABEL_SELECTOR}" \
      -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')"
    pod_count="$(grep -c . <<<"${current_names}" || true)"
    replacement=""
    while IFS= read -r pod; do
      if [[ -n "${pod}" ]] && ! grep -Fxq "${pod}" <<<"${before_names}"; then
        replacement="${pod}"
        break
      fi
    done <<<"${current_names}"

    if [[ "${ready:-0}" == "${desired}" ]] && \
      [[ "${pod_count}" == "${desired}" ]] && \
      [[ -n "${replacement}" ]]; then
      printf 'El Deployment recuperó %s réplicas listas.\n' "${desired}"
      printf 'Pod de reemplazo observado: %s\n' "${replacement}"
      kubectl -n "${NAMESPACE}" get pods -l "${LABEL_SELECTOR}" -o wide
      return 0
    fi
    sleep 2
  done

  die "el Deployment no recuperó ${desired} réplicas dentro de 180 segundos"
}

collect_evidence() {
  need docker
  require_kubernetes_tools
  assert_lab_context

  local stamp evidence_dir pod
  stamp="$(date +%Y%m%d-%H%M%S)"
  evidence_dir="${PROJECT_DIR}/evidencias/${stamp}"
  mkdir -p "${evidence_dir}"

  {
    docker info --format 'Docker Server: {{.ServerVersion}}'
    minikube version
    kubectl version --client
    kubectl get nodes -o wide
  } >"${evidence_dir}/01-entorno.txt"

  kubectl -n "${NAMESPACE}" get deployments,pods,services -o wide \
    >"${evidence_dir}/02-recursos.txt"

  pod="$(kubectl -n "${NAMESPACE}" get pods -l "${LABEL_SELECTOR}" \
    -o jsonpath='{.items[0].metadata.name}')"
  kubectl -n "${NAMESPACE}" get pod "${pod}" \
    -o jsonpath='Pod: {.metadata.name}{"\nImagen: "}{.spec.containers[0].image}{"\nImage ID: "}{.status.containerStatuses[0].imageID}{"\n"}' \
    >"${evidence_dir}/03-imagen.txt"

  printf 'Evidencia textual guardada en %s\n' "${evidence_dir}"
  printf 'Las cinco capturas requeridas por la consigna deben tomarse durante cada etapa.\n'
}

reset_portal() {
  scale_portal 2
}

stop_cluster() {
  require_kubernetes_tools
  minikube stop -p "${PROFILE}"
}

usage() {
  cat <<'EOF'
Uso: scripts/lab.sh COMANDO [ARGUMENTOS]

Comandos:
  start              comprueba requisitos e inicia el perfil asi-k8s
  validate           analiza y renderiza el manifiesto localmente
  deploy             aplica el manifiesto y espera las dos réplicas
  status             muestra Deployment, Pods y Service
  url                expone el Service y muestra su URL
  request [URL]      realiza 20 solicitudes (también acepta TP_URL)
  scale REPlicas     cambia la cantidad de réplicas y espera el rollout
  self-heal          elimina un Pod y espera su reemplazo
  evidence           guarda versiones, estado e Image ID en evidencias/
  reset              vuelve el Deployment a dos réplicas
  stop               detiene el perfil de Minikube
EOF
}

main() {
  local command="${1:-help}"
  shift || true

  case "${command}" in
    start) start_cluster "$@" ;;
    validate) validate_manifest "$@" ;;
    deploy) deploy_portal "$@" ;;
    status)
      require_kubernetes_tools
      assert_lab_context
      show_status
      ;;
    url) print_url "$@" ;;
    request) request_portal "$@" ;;
    scale) scale_portal "$@" ;;
    self-heal) self_heal "$@" ;;
    evidence) collect_evidence "$@" ;;
    reset) reset_portal "$@" ;;
    stop) stop_cluster "$@" ;;
    help|-h|--help) usage ;;
    *)
      usage >&2
      die "comando desconocido: ${command}"
      ;;
  esac
}

main "$@"
