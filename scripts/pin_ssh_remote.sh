#!/usr/bin/env bash
set -euo pipefail
cd "$HOME/projects/coinbase_pipeline"
git remote set-url origin git@github.com:andybahtwin-maker/coinbase_pipeline.git
git config --local url."git@github.com:".insteadOf https://github.com/
git remote -v
