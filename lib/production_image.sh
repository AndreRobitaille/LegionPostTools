# shellcheck shell=bash
# Source before any Docker operation in the image build/smoke tools.
require_isolated_image_runner() {
  [[ "${GITHUB_ACTIONS:-}" == true && "${RUNNER_ENVIRONMENT:-}" == github-hosted &&
     "${RUNNER_OS:-}" == Linux && "${RUNNER_ARCH:-}" == X64 ]] || {
    echo "Build images only on isolated GitHub-hosted Linux amd64 runners" >&2
    return 1
  }
  [[ -z "${DOCKER_HOST:-}" && -z "${DOCKER_CONTEXT:-}" &&
     -z "${DOCKER_TLS_VERIFY:-}" && -z "${DOCKER_CERT_PATH:-}" ]] || {
    echo "Docker host/context overrides are not allowed" >&2
    return 1
  }
}

# Never resolve a workstation's or runner's saved remote Docker context.
docker() {
  command docker --host unix:///var/run/docker.sock "$@"
}
