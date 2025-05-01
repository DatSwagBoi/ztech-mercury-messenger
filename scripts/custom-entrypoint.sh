#!/bin/bash
set -e

echo "Starting ZTech Mercury Messenger..."

# Run the original entrypoint from the base image
exec /usr/local/bin/docker-entrypoint.sh "$@"