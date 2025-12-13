#!/usr/bin/env bash

set -euo pipefail

# Build PDFs using the local Dockerfile (so you don't need TeX installed locally).
#
# Usage:
#   ./build.sh                         # builds all *.tex in repo root
#   ./build.sh Dogukaan-Kilicarslan-CV.tex
#   ./build.sh Dogukaan-Kilicarslan-CV.tex Dogukaan-Kilicarslan-CV-DE.tex
#
# Override image tag:
#   LATEX_IMAGE=latex ./build.sh

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LATEX_IMAGE="${LATEX_IMAGE:-darkb/latex}"

cd "$REPO_ROOT"

docker build -t "$LATEX_IMAGE" "$REPO_ROOT"

# If no args are provided, build every *.tex in the repo root.
# Note: use a bash glob (portable across macOS/Linux); avoid GNU-only flags like `sort -z`.
tex_files=()
if [[ "$#" -gt 0 ]]; then
  tex_files=("$@")
else
  shopt -s nullglob
  tex_files=( *.tex )
  shopt -u nullglob
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
