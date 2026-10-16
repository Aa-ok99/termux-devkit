# lib/modules.sh - module loader, dependency resolver, profiles

CAT_ORDER=("Essentials" "Languages" "Platforms" "Tools")

module_path() {
  local d
  for d in "$TKIT_HOME/modules" "$TKIT_ROOT/modules"; do
    [ -f "$d/$1.sh" ] && { echo "$d/$1.sh"; return 0; }
  done
  return 1
}

all_modules() {
  local d f
  for d in "$TKIT_ROOT/modules" "$TKIT_HOME/modules"; do
    for f in "$d"/*.sh; do [ -e "$f" ] && basename "$f" .sh; done
  done | sort -u
}

load_module() {
  local p
  p=$(module_path "$1") || { ui_err "Unknown module: $1  (try: tkit list)"; return 1; }
  unset MOD_DESC MOD_CAT MOD_DEPS MOD_PKGS
  unset -f mod_post mod_check mod_remove 2>/dev/null
  # shellcheck disable=SC1090
  source "$p"
}

# Modules ordered by category, then name
modules_sorted() {
  local m c i k
  for m in $(all_modules); do
    load_module "$m" 2>/dev/null || continue
    c="${MOD_CAT:-Tools}"; i=9
    for k in "${!CAT_ORDER[@]}"; do [ "${CAT_ORDER[k]}" = "$c" ] && i=$k; done
    echo "$i $m"
  done | sort -k1,1n -k2,2 | awk '{print $2}'
}

# prints: installed | partial | none   (module must be loaded)
module_status() {
  if declare -F mod_check >/dev/null; then
    mod_check && echo installed || echo none; return
  fi
  local p total=0 have=0
  for p in ${MOD_PKGS:-}; do
    total=$((total+1)); pkg_installed "$p" && have=$((have+1))
  done
  if   (( total == 0 ));    then echo none
  elif (( have == total )); then echo installed
  elif (( have > 0 ));      then echo partial
  else echo none; fi
}

# ---- install / remove ----------------------------------------------
declare -A DONE=()

install_module() {
  local m="$1" d
  [[ -n "${DONE[$m]:-}" ]] && return 0
  DONE[$m]=1
  load_module "$m" || return 1
  for d in ${MOD_DEPS:-}; do install_module "$d" || return 1; done
  load_module "$m"   # reload: dependencies overwrite MOD_* variables

  ui_rule "$m"
  ui_info "${MOD_DESC:-}"
  if [ -n "${MOD_PKGS:-}" ]; then
    # shellcheck disable=SC2086
    pkg_install $MOD_PKGS || return 1
  fi
  if declare -F mod_post >/dev/null; then mod_post || true; fi
  state_add "$m"
}

install_modules() {
  local m okn=0 failed=()
  DONE=()
  for m in "$@"; do
    if install_module "$m"; then okn=$((okn+1)); else failed+=("$m"); fi
  done
  ui_rule "Summary"
  (( okn )) && ui_ok "$okn module(s) ready"
  if (( ${#failed[@]} )); then
    ui_err "Failed: ${failed[*]}"
    ui_info "Details: tkit log"
    return 1
  fi
}

remove_module() {
  local m="$1" d deps=() p
  load_module "$m" || return 1
  for d in $(all_modules); do
    [ "$d" = "$m" ] && continue
    grep -qx "$d" "$TKIT_STATE" 2>/dev/null || continue
    load_module "$d" && [[ " ${MOD_DEPS:-} " == *" $m "* ]] && deps+=("$d")
  done
  load_module "$m"
  ui_rule "Remove $m"
  if (( ${#deps[@]} )); then
    ui_warn "Required by: ${deps[*]}"
    confirm "Remove anyway?" || return 0
  fi
  if declare -F mod_remove >/dev/null; then mod_remove; fi
  if [ -n "${MOD_PKGS:-}" ] && confirm "Uninstall packages: $MOD_PKGS ?"; then
    for p in $MOD_PKGS; do ui_task "Removing $p" pkg uninstall -y "$p"; done
  fi
  state_del "$m"
}

# ---- profiles --------------------------------------------------------
PROFILE_NAMES=(minimal web backend android full)

profile_mods() {
  case "$1" in
    minimal) echo "storage base shell" ;;
    web)     echo "storage base shell git nodejs web" ;;
    backend) echo "storage base shell git python nodejs web" ;;
    android) echo "storage base shell git android" ;;
    full)    modules_sorted ;;
    *)       return 1 ;;
  esac
}

profile_desc() {
  case "$1" in
    minimal) echo "Storage, core tools and shell" ;;
    web)     echo "Frontend & Node.js web development" ;;
    backend) echo "Python + Node.js + web server & DB" ;;
    android) echo "Android development with Termux:API" ;;
    full)    echo "Everything tkit offers" ;;
  esac
}
