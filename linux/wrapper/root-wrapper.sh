#!/usr/bin/env bash
scriptDir=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
exec "$scriptDir/share/dev.j7126.combat_tracker/combat_tracker" "$@"