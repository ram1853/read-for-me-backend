#!/bin/bash
set -e

docker run --rm \
  -v "$(pwd):/workspace" \
  -w /workspace/infra \
  -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
  -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
  hashicorp/terraform:latest $@