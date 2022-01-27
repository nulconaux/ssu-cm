# Makefile
SHELL := /bin/bash
version = $(shell git describe --tags | tr . _)
GIT_REF ?= $(shell echo "refs/heads/"`git rev-parse --abbrev-ref HEAD`)
GIT_SHA ?= $(shell echo `git rev-parse --verify HEAD^{commit}`)

.PHONY: install-dev
install-dev:
    python -m pip install -e ".[dev]" --no-cache-dir
    pre-commit install
    pre-commit autoupdate

# virtualenv allows isolation of python libraries
.PHONY: venv
venv: bin/python

.PHONY: bin/python
bin/python:
	pip -V || sudo easy_install pip
	# virtualenv allows isolation of python libraries
	virtualenv --version || sudo easy_install virtualenv
	# Now with those two we can isolate our test setup.
	virtualenv venv
	venv/bin/pip install -r requirements.txt
