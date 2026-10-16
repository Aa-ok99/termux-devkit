# lib/core.sh - state, logging, package helpers

TKIT_HOME="${TKIT_HOME:-$HOME/.config/tkit}"
TKIT_LOG="$TKIT_HOME/tkit.log"
TKIT_STATE="$TKIT_HOME/installed"
mkdir -p "$TKIT_HOME" 2>/dev/null

DRY_RUN=${DRY_RUN:-0}
YES=${YES:-0}

die()  { ui_err "$*"; exit 1; }
log()  { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$TKIT_LOG" 2>/dev/null; }
is_termux() { [[ "${PREFIX:-}" == *com.termux* ]]; }

require_termux() {
  (( DRY_RUN )) && return 0
  [ -n "${TKIT_FORCE:-}" ] && return 0
  is_termux || die "This command must run inside Termux (use --dry-run to preview)."
}

# Run a command directly (interactive-safe). Honors --dry-run.
run() {
  if (( DRY_RUN )); then
    printf '  %s·%s %sdry-run%s  %s\n' "$GRY" "$NC" "$DIM" "$NC" "$*"
    return 0
  fi
  log "RUN $*"
  "$@"
}

# ---- package cache -------------------------------------------------
declare -A PKG_SET=()
PKG_LOADED=0
INDEX_DONE=0

pkg_cache_load() {
  PKG_SET=(); local p
  while read -r p; do PKG_SET[$p]=1; done < <(dpkg-query -W -f='${Package}\n' 2>/dev/null)
  PKG_LOADED=1
}

pkg_installed() {
  (( PKG_LOADED )) || pkg_cache_load
  [[ -n "${PKG_SET[$1]:-}" ]]
}

# Refresh the package index at most once per day
pkg_index_refresh() {
  (( INDEX_DONE || DRY_RUN )) && return 0
  INDEX_DONE=1
  local stamp="$TKIT_HOME/.index_stamp"
  if [ ! -f "$stamp" ] || [ -n "$(find "$stamp" -mmin +1440 2>/dev/null)" ]; then
    if ui_task "Refreshing package index" pkg update -y; then touch "$stamp"; fi
  fi
}

# Install packages one by one with a spinner. Returns 1 if any failed.
pkg_install() {
  local total=$# n=0 p failed=()
  for p in "$@"; do
    n=$((n+1))
    if pkg_installed "$p"; then ui_skip "$p"; continue; fi
    pkg_index_refresh
    if ui_task "Installing $p ($n/$total)" env DEBIAN_FRONTEND=noninteractive pkg install -y "$p"; then
      PKG_SET[$p]=1
    else
      failed+=("$p")
    fi
  done
  (( ${#failed[@]} == 0 )) || { ui_warn "Failed packages: ${failed[*]}"; return 1; }
}

# ---- state ---------------------------------------------------------
state_add() {
  (( DRY_RUN )) && return 0
  grep -qx "$1" "$TKIT_STATE" 2>/dev/null || echo "$1" >> "$TKIT_STATE"
}
state_del() {
  (( DRY_RUN )) && return 0
  [ -f "$TKIT_STATE" ] && sed -i "/^$1\$/d" "$TKIT_STATE"
  return 0
}
