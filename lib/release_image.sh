# shellcheck shell=bash
# Shared by bin/release and its owned session; sourcing opens no connection.
require_image_digest() {
  [[ "${RELEASE_IMAGE_DIGEST:-}" =~ ^sha256:[a-f0-9]{64}$ ]] || {
    echo 'release: RELEASE_IMAGE_DIGEST must be the verified sha256 digest of an off-server image' >&2
    return 1
  }
}

verify_prebuilt_image() {
  require_image_digest || return
  local head="$1"
  [[ "$head" =~ ^[a-f0-9]{40}$ ]] || return 1
  release_ssh "docker image inspect --format '{{json .}}' '$PROD_IMAGE:$head'" |
    ruby script/verify_production_image.rb local "$head" "$RELEASE_IMAGE_DIGEST"
}

release_run() (
  set -Eeuo pipefail
  cd "$APP_ROOT"
  require_image_digest || exit 1
  [[ "${RELEASE_PREFLIGHT_OK:-}" == 1 ]] || { fail 'run release_preflight successfully in this session first'; exit 1; }
  assert_clean_worktree || exit 1
  assert_remote_matches_head || exit 1
  local head
  head="$(git rev-parse HEAD)"
  release_ssh true </dev/null || exit 1
  release_kamal build pull --version "$head" || exit 1
  verify_prebuilt_image "$head" || exit 1
  # Kamal pulls again; pre-deploy validates that final image before replacement.
  release_kamal deploy --skip-push --version "$head" || exit 1
  if [[ -n "${release_activation_email:-}" ]]; then
    release_kamal app exec --reuse "bin/rails 'buddy_checks:activate[$release_activation_email]'" || exit 1
    probe_mobile_readiness true || exit 1
  fi
  release_verify
)
