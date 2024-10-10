#!/bin/sh
export BACKEND_URL="https://$CODESPACE_NAME-3000.$GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN"
yarn --cwd /workspaces/vets-website watch --env api="$BACKEND_URL"
tail -f /dev/null
