#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: build-and-push-images.sh [-r AWS_REGION] [-t IMAGE_TAG] [-m MODULE_PATH]

Builds and pushes the four ECR images expected by infra/aws-docker:
  <tag>-authserver
  <tag>-worldserver
  <tag>-db-import
  <tag>-client-data

Run from anywhere after `terraform apply` has created the ECR repository.

Environment overrides:
  AWS_PROFILE    Optional AWS profile used by aws/terraform.
  REPO_ROOT      AzerothCore checkout root. Defaults to this script's repo.
  TF_DIR         Terraform module dir. Defaults to infra/aws-docker.
EOF
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${TF_DIR:-$(cd -- "$SCRIPT_DIR/.." && pwd)}"
REPO_ROOT="${REPO_ROOT:-$(cd -- "$TF_DIR/../.." && pwd)}"
AWS_REGION="${AWS_REGION:-us-east-1}"
IMAGE_TAG="${IMAGE_TAG:-master}"
MODULE_PATH="${MODULE_PATH:-$REPO_ROOT/modules/mod-individual-progression}"

while getopts ":r:t:m:h" opt; do
  case "$opt" in
    r) AWS_REGION="$OPTARG" ;;
    t) IMAGE_TAG="$OPTARG" ;;
    m) MODULE_PATH="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

command -v aws >/dev/null || { echo "aws CLI is required" >&2; exit 1; }
command -v docker >/dev/null || { echo "docker is required" >&2; exit 1; }
command -v terraform >/dev/null || { echo "terraform is required" >&2; exit 1; }

if [ ! -d "$MODULE_PATH" ]; then
  echo "Required module is missing: $MODULE_PATH" >&2
  echo "Clone mod-individual-progression into modules/ before building images." >&2
  exit 1
fi

if [ ! -d "$REPO_ROOT/.git" ]; then
  echo "REPO_ROOT must point at the AzerothCore Git checkout: $REPO_ROOT" >&2
  exit 1
fi

cd "$REPO_ROOT"

repo_uri="$(terraform -chdir="$TF_DIR" output -raw ecr_repository_url)"
registry="${repo_uri%%/*}"

aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$registry"

build_and_push() {
  local target="$1"
  local tag="$2"

  docker build -f apps/docker/Dockerfile --target "$target" -t "$repo_uri:$tag" .
  docker push "$repo_uri:$tag"
}

build_and_push authserver  "$IMAGE_TAG-authserver"
build_and_push worldserver "$IMAGE_TAG-worldserver"
build_and_push db-import   "$IMAGE_TAG-db-import"
build_and_push client-data "$IMAGE_TAG-client-data"

cat <<EOF
Pushed AzerothCore images to $repo_uri:
  $IMAGE_TAG-authserver
  $IMAGE_TAG-worldserver
  $IMAGE_TAG-db-import
  $IMAGE_TAG-client-data
EOF
