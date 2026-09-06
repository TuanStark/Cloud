#!/usr/bin/env bash
# Wrapper script tiện lợi để chạy Checkov qua Docker
exec docker run --rm -t -v "$PWD":/tf -w /tf bridgecrew/checkov "$@"
