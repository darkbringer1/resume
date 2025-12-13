#!/usr/bin/env bash

set -euo pipefail

# If the script is invoked as `sh build.sh` or `zsh build.sh`, the shebang is bypassed.
# Re-exec with bash so bash-specific features (arrays, [[ ]], shopt, etc.) work reliably.
if [[ -z "${BASH_VERSION:-}" ]]; then
  exec bash "$0" "$@"
fi

# Build PDFs using the local Dockerfile (so you don't need TeX installed locally).
#
# Usage:
#   ./build.sh                         # builds all *.tex in repo root
#   ./build.sh Dogukaan-Kilicarslan-CV  # finds Dogukaan-Kilicarslan-CV.tex in repo root and builds it
#   ./build.sh Dogukaan-Kilicarslan-CV.tex
#   ./build.sh Dogukaan-Kilicarslan-CV Dogukaan-Kilicarslan-CV-DE  # builds both (resolved independently)
#
# Override image tag:
#   LATEX_IMAGE=latex ./build.sh

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LATEX_IMAGE="${LATEX_IMAGE:-darkb/latex}"

cd "$REPO_ROOT"

docker build -t "$LATEX_IMAGE" "$REPO_ROOT"

print_usage() {
  cat <<'EOF'
Build PDFs using Docker + pdflatex.

Usage:
  ./build.sh                    Builds all *.tex in the repo root.
  ./build.sh <name>             Builds <name>.tex from the repo root (you can omit the .tex extension).
  ./build.sh <name> [<name>...] Builds multiple tex files (each name resolved independently).

Examples:
  ./build.sh Dogukaan-Kilicarslan-CV
  ./build.sh Dogukaan-Kilicarslan-CV-DE.tex

Env:
  LATEX_IMAGE=latex ./build.sh  Override the Docker image tag (default: darkb/latex)
EOF
}

list_root_tex_files() {
  shopt -s nullglob
  local files=( *.tex )
  shopt -u nullglob
  if [[ "${#files[@]}" -eq 0 ]]; then
    echo "(none)"
    return
  fi
  for f in "${files[@]}"; do
    echo "  - $f"
  done
}

resolve_tex_arg() {
  # Resolves a user-provided name to a concrete *.tex filename in the repo root.
  # Accepts:
  # - exact file: Foo.tex
  # - base name:  Foo   (resolves to Foo.tex)
  # - unique substring match: "Foo" matches "My-Foo-Resume.tex" if it's the only match
  local arg="$1"

  # Explicit help flags.
  if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
    print_usage
    exit 0
  fi

  # Exact file match in repo root.
  if [[ -f "$REPO_ROOT/$arg" && "$arg" == *.tex ]]; then
    echo "$arg"
    return 0
  fi

  # Base-name match in repo root.
  if [[ -f "$REPO_ROOT/$arg.tex" ]]; then
    echo "$arg.tex"
    return 0
  fi

  # Unique substring match among root *.tex files.
  shopt -s nullglob
  local matches=( *"$arg"*.tex )
  shopt -u nullglob
  if [[ "${#matches[@]}" -eq 1 ]]; then
    echo "${matches[0]}"
    return 0
  fi

  if [[ "${#matches[@]}" -gt 1 ]]; then
    echo "Ambiguous input '$arg' - multiple matches:" >&2
    for m in "${matches[@]}"; do
      echo "  - $m" >&2
    done
    return 2
  fi

  echo "Couldn't find a .tex file for input '$arg' in $REPO_ROOT" >&2
  echo "Available .tex files:" >&2
  list_root_tex_files >&2
  return 1
}

tex_files=()
if [[ "$#" -gt 0 ]]; then
  for arg in "$@"; do
    tex_files+=( "$(resolve_tex_arg "$arg")" )
  done
else
  # No args: build every *.tex in the repo root.
  shopt -s nullglob
  tex_files=( *.tex )
  shopt -u nullglob
  if [[ "${#tex_files[@]}" -eq 0 ]]; then
    echo "No .tex files found in $REPO_ROOT" >&2
    exit 1
  fi
fi

if [[ "${#tex_files[@]}" -eq 0 ]]; then
  echo "No .tex files found in $REPO_ROOT" >&2
  exit 1
fi

for tex in "${tex_files[@]}"; do
  if [[ ! -f "$REPO_ROOT/$tex" ]]; then
    echo "File not found: $tex" >&2
    exit 1
  fi

  # Two passes helps resolve references and improves stability for most resumes.
  docker run --rm \
    -v "$REPO_ROOT":/data \
    -w /data \
    "$LATEX_IMAGE" \
    pdflatex -interaction=nonstopmode -halt-on-error -file-line-error "$tex"

  docker run --rm \
    -v "$REPO_ROOT":/data \
    -w /data \
    "$LATEX_IMAGE" \
    pdflatex -interaction=nonstopmode -halt-on-error -file-line-error "$tex"
done
