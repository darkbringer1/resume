# Makefile for building LaTeX CVs with Docker (uses ./build.sh).
# Usage examples:
#   make build
#   make pdf NAME=Duygu-N-Polat-CV
#   make pdf FILE=Dogukaan-Kilicarslan-CV.tex
#   make pdf ARGS="Dogukaan-Kilicarslan-CV Duygu-N-Polat-CV"

# Shell to use for recipes.
SHELL := /bin/bash

# Repo root so the Makefile works from any working directory.
REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

# Script used to build PDFs (already handles docker + name resolution).
BUILD_SH := $(REPO_ROOT)/build.sh

# Docker image tag used by build.sh (override with LATEX_IMAGE=...).
LATEX_IMAGE ?= darkb/latex

.PHONY: help build pdf list clean

# Default target shows help.
help:
	@printf "Make targets:\n"
	@printf "  make build                     Build all *.tex in repo root\n"
	@printf "  make pdf NAME=<base>            Build <base>.tex (no extension)\n"
	@printf "  make pdf FILE=<file.tex>        Build exact .tex file\n"
	@printf "  make pdf ARGS=\"a b c\"           Build multiple files (args passed to build.sh)\n"
	@printf "  make list                      List available .tex files\n"
	@printf "  make clean                     Remove aux/log/out files\n"
	@printf "\nVariables:\n"
	@printf "  LATEX_IMAGE=<tag>               Docker image tag (default: darkb/latex)\n"

# Build all .tex files using build.sh (docker-based).
build:
	@LATEX_IMAGE="$(LATEX_IMAGE)" "$(BUILD_SH)"

# Build one or more .tex files (use NAME, FILE, or ARGS).
pdf:
	@if [ -z "$(strip $(FILE)$(NAME)$(ARGS))" ]; then \
		echo "Missing input. Use NAME=<base>, FILE=<file.tex>, or ARGS=\"a b\"."; \
		exit 1; \
	fi; \
	LATEX_IMAGE="$(LATEX_IMAGE)" "$(BUILD_SH)" $(FILE) $(NAME) $(ARGS)

# List .tex files in the repo root for quick discovery.
list:
	@printf "Available .tex files in %s:\n" "$(REPO_ROOT)"
	@ls -1 "$(REPO_ROOT)"/*.tex 2>/dev/null | sed 's|.*/||' || echo "  (none)"

# Clean common LaTeX build artifacts (keeps PDFs).
clean:
	@rm -f "$(REPO_ROOT)"/*.aux "$(REPO_ROOT)"/*.log "$(REPO_ROOT)"/*.out

