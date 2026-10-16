# lib/commands.sh - tkit sub-commands

# ---- list / info / search ---------------------------------------------
cmd_list() {
  local filter=all
  case "${1:-}" in
    --names)     modules_sorted; return ;;
    --installed) filter=installed ;;
    --available) filter=available ;;
  esac
  pkg_cache_load
  local m st last="" category icon
  for m in $(modules_sorted); do
    load_module "$m" || continue
    st=$(module_status)
    [ "$filter" = installed ] && [ "$st" != installed ] && continue
    [ "$filter" = available ] && [ "$st" = installed ] && continue
    category="${MOD_CAT:-Tools}"
    if [ "$category" != "$last" ]; then ui_rule "$category"; last="$category"; fi
    case "$st" in
      installed) icon="${GRN}●${NC}" ;;
      partial)   icon="${YLW}◐${NC}" ;;
      *)         icon="${GRY}○${NC}" ;;
    esac
    printf '  %s %-11s %s%s%s\n' "$icon" "$m" "$GRY" "${MOD_DESC:-}" "$NC"
  done
  echo
  printf '  %s●%s installed  %s◐%s partial  %s○%s not installed\n' "$GRN" "$NC" "$YLW" "$NC" "$GRY" "$NC"
}

cmd_info() {
  local m="${1:-}" p mark
  [ -n "$m" ] || die "Usage: tkit info <module>"
  load_module "$m" || exit 1
  pkg_cache_load
  ui_rule "$m"
  ui_kv "Description" "${MOD_DESC:-}"
  ui_kv "Category"    "${MOD_CAT:-Tools}"
  ui_kv "Status"      "$(module_status)"
  ui_kv "Depends on"  "${MOD_DEPS:--}"
  ui_kv "Source"      "$(module_path "$m")"
  if [ -n "${MOD_PKGS:-}" ]; then
    echo; ui_kv "Packages" ""
    for p in $MOD_PKGS; do
      if pkg_installed "$p"; then mark="${GRN}✔${NC}"; else mark="${GRY}○${NC}"; fi
      printf '    %s %s\n' "$mark" "$p"
    done
  fi
}

cmd_search() {
  local q="${1:-}" m hit=0
  [ -n "$q" ] || die "Usage: tkit search <keyword>"
  for m in $(modules_sorted); do
    load_module "$m" || continue
    if echo "$m ${MOD_DESC:-} ${MOD_PKGS:-}" | grep -qi -- "$q"; then
      printf '  %s%-11s%s %s%s%s\n' "$ACC" "$m" "$NC" "$GRY" "${MOD_DESC:-}" "$NC"; hit=1
    fi
  done
  (( hit )) || ui_warn "No module matches '$q'"
}

# ---- install / remove / profile ---------------------------------------
cmd_install() {
  (( $# )) || die "Usage: tkit install <module...|all>"
  require_termux
  local m mods=()
  for m in "$@"; do
    if [ "$m" = all ]; then mapfile -t mods < <(modules_sorted); break; fi
    if module_path "$m" >/dev/null; then mods+=("$m"); else ui_err "Unknown module: $m  (try: tkit list)"; fi
  done
  (( ${#mods[@]} )) || exit 1
  install_modules "${mods[@]}"
}

cmd_remove() {
  (( $# )) || die "Usage: tkit remove <module...>"
  require_termux
  local m
  for m in "$@"; do remove_module "$m"; done
}

cmd_profile() {
  local name="${1:-}" p mods
  if [ -z "$name" ] || [ "$name" = list ]; then
    ui_rule "Profiles"
    for p in "${PROFILE_NAMES[@]}"; do
      printf '  %s%-9s%s %s%s%s\n' "$ACC" "$p" "$NC" "$GRY" "$(profile_desc "$p")" "$NC"
    done
    echo; ui_info "Usage: tkit profile <name>"
    return
  fi
  mods=$(profile_mods "$name") || die "Unknown profile: $name  (try: tkit profile)"
  require_termux
  ui_info "Profile ${BLD}$name${NC}: $(echo $mods)"
  # shellcheck disable=SC2086
  install_modules $mods
}

# ---- doctor -------------------------------------------------------------
_chk() {   # status label detail
  local icon
  case "$1" in ok) icon="${GRN}✔${NC}" ;; warn) icon="${YLW}!${NC}" ;; *) icon="${RED}✘${NC}" ;; esac
  printf '  %s %-13s %s%s%s\n' "$icon" "$2" "$GRY" "$3" "$NC"
}

_tool_version() {
  case "$1" in
    tmux) tmux -V ;;
    java) java -version 2>&1 | head -n1 ;;
    node) node -v ;;
    adb)  adb version 2>&1 | head -n1 ;;
    *)    "$1" --version 2>&1 | head -n1 ;;
  esac | cut -c1-34
}

cmd_doctor() {
  local issues=0 avail stamp c
  ui_rule "System"
  if is_termux; then _chk ok "Termux" "running inside Termux"; else _chk warn "Termux" "not running inside Termux"; fi
  _chk ok "Architecture" "$(uname -m)"
  command -v getprop >/dev/null 2>&1 && _chk ok "Android" "$(getprop ro.build.version.release)"
  avail=$(df -k "$HOME" 2>/dev/null | awk 'NR==2{print $4}')
  if [[ "$avail" =~ ^[0-9]+$ ]] && (( avail < 1048576 )); then
    _chk warn "Disk space" "$(df -h "$HOME" | awk 'NR==2{print $4}') free (low)"; issues=$((issues+1))
  else
    _chk ok "Disk space" "$(df -h "$HOME" 2>/dev/null | awk 'NR==2{print $4}') free"
  fi
  if curl -fsI --max-time 5 https://github.com >/dev/null 2>&1; then
    _chk ok "Network" "github.com reachable"
  else
    _chk fail "Network" "cannot reach github.com"; issues=$((issues+1))
  fi
  if [ -d "$HOME/storage" ]; then _chk ok "Storage" "~/storage available"
  else _chk warn "Storage" "run: tkit install storage"; issues=$((issues+1)); fi
  stamp="$TKIT_HOME/.index_stamp"
  if [ -f "$stamp" ] && [ -z "$(find "$stamp" -mmin +10080 2>/dev/null)" ]; then
    _chk ok "Pkg index" "refreshed within 7 days"
  else
    _chk warn "Pkg index" "stale - run: tkit update"; issues=$((issues+1))
  fi

  ui_rule "Tools"
  for c in git gh python pip node npm nvim tmux zsh java adb ffmpeg yt-dlp nginx php; do
    if command -v "$c" >/dev/null 2>&1; then
      printf '  %s✔%s %-9s %s%s%s\n' "$GRN" "$NC" "$c" "$GRY" "$(_tool_version "$c")" "$NC"
    else
      printf '  %s○%s %-9s %snot installed%s\n' "$GRY" "$NC" "$c" "$GRY" "$NC"
    fi
  done
  echo
  if (( issues == 0 )); then ui_ok "All checks passed"; else ui_warn "$issues issue(s) found"; return 1; fi
}

# ---- maintenance -----------------------------------------------------------
cmd_update() {
  require_termux
  ui_rule "Update packages"
  run pkg update -y && run pkg upgrade -y
  (( DRY_RUN )) || touch "$TKIT_HOME/.index_stamp"
}

cmd_self_update() {
  ui_rule "Update tkit"
  if [ -d "$TKIT_ROOT/.git" ]; then
    run git -C "$TKIT_ROOT" pull --ff-only
  else
    ui_warn "tkit was not installed from git."
    ui_info "Re-download from: $TKIT_REPO"
  fi
}

cmd_log() {
  [ -f "$TKIT_LOG" ] || { ui_info "Log is empty"; return; }
  tail -n "${1:-40}" "$TKIT_LOG"
}

# ---- interactive menu ------------------------------------------------------------
menu_install() {
  local m st
  ch_reset; pkg_cache_load
  for m in $(modules_sorted); do
    load_module "$m" || continue
    st=$(module_status)
    CH_KEYS+=("$m"); CH_LABELS+=("$m"); CH_HINTS+=("${MOD_DESC:-}")
    if [ "$st" = installed ]; then CH_BADGES+=("✔"); else CH_BADGES+=(""); fi
    CH_DETAILS+=("[${MOD_CAT:-Tools}] needs: ${MOD_DEPS:--}  |  pkgs: ${MOD_PKGS:--}")
    CH_PRE+=(0)
  done
  ui_choose multi "Select modules to install" || return 0
  ui_banner; echo
  require_termux
  install_modules "${CH_OUT[@]}"
  ui_pause
}

menu_profile() {
  local p
  ch_reset
  for p in "${PROFILE_NAMES[@]}"; do
    CH_KEYS+=("$p"); CH_LABELS+=("$p"); CH_HINTS+=("$(profile_desc "$p")")
    CH_DETAILS+=("modules: $(profile_mods "$p" | tr '\n' ' ')")
  done
  ui_choose single "Choose a profile" || return 0
  ui_banner; echo
  cmd_profile "${CH_OUT[0]}"
  ui_pause
}

menu_new() {
  local t name
  ch_reset
  for t in "${TEMPLATES[@]}"; do
    CH_KEYS+=("$t"); CH_LABELS+=("$t"); CH_HINTS+=("$(template_desc "$t")")
    CH_DETAILS+=("requires: $(template_needs "$t")")
  done
  ui_choose single "Choose a project template" || return 0
  t="${CH_OUT[0]}"
  ui_banner; echo
  read -rp "  Project name: " name
  [ -n "$name" ] && scaffold "$t" "$name"
  ui_pause
}

cmd_menu() {
  while true; do
    ch_reset
    CH_KEYS=(install profile new doctor update quit)
    CH_LABELS=("Install" "Profiles" "New project" "Doctor" "Update" "Quit")
    CH_HINTS=("Pick tools and languages" "One-tap bundles (web, backend...)" "Scaffold from a template" "Check your environment" "Upgrade packages" "")
    CH_DETAILS=("tkit install <module>" "tkit profile <name>" "tkit new <template> <name>" "tkit doctor" "tkit update" "")
    ui_choose single "What would you like to do?" || break
    case "${CH_OUT[0]}" in
      install) menu_install ;;
      profile) menu_profile ;;
      new)     menu_new ;;
      doctor)  ui_banner; cmd_doctor; ui_pause ;;
      update)  ui_banner; cmd_update; ui_pause ;;
      quit)    break ;;
    esac
  done
  echo
}

# ---- completion & help -------------------------------------------------------------
cmd_completion() {
  cat << 'EOF'
_tkit_complete() {
  local cur="${COMP_WORDS[COMP_CWORD]}" prev="${COMP_WORDS[COMP_CWORD-1]}"
  local cmds="menu install remove list info search profile new doctor update self-update log completion version help"
  case "$prev" in
    install|add|i|remove|rm|uninstall|info) COMPREPLY=($(compgen -W "$(tkit list --names) all" -- "$cur")) ;;
    profile) COMPREPLY=($(compgen -W "list minimal web backend android full" -- "$cur")) ;;
    new)     COMPREPLY=($(compgen -W "python-cli flask-api express-api static-site telegram-bot" -- "$cur")) ;;
    list|ls) COMPREPLY=($(compgen -W "--installed --available" -- "$cur")) ;;
    *)       COMPREPLY=($(compgen -W "$cmds -y -n --yes --dry-run --no-color -h --help" -- "$cur")) ;;
  esac
}
complete -F _tkit_complete tkit
EOF
}

cmd_help() {
  case "${1:-}" in
    install|add|i) cat << EOF
${BLD}tkit install${NC} <module...|all>
  Install modules. Dependencies are resolved automatically.
  tkit install python nodejs
  tkit install all -y
EOF
    ;;
    remove|rm|uninstall) cat << EOF
${BLD}tkit remove${NC} <module...>
  Uninstall a module's packages (asks before removing shared ones).
EOF
    ;;
    list|ls) cat << EOF
${BLD}tkit list${NC} [--installed | --available]
  Show all modules grouped by category with install status.
EOF
    ;;
    profile) cat << EOF
${BLD}tkit profile${NC} [name]
  Install a bundle of modules in one go.
  Profiles: ${PROFILE_NAMES[*]}
EOF
    ;;
    new) cat << EOF
${BLD}tkit new${NC} [template] [name]
  Scaffold a ready-to-run project.
  Templates: ${TEMPLATES[*]}
  tkit new flask-api my-api
EOF
    ;;
    *) cat << EOF
${BLD}tkit${NC} ${GRY}v$TKIT_VERSION${NC} - Termux DevKit
Turn Termux into a complete development workstation.

${BLD}USAGE${NC}
  tkit [command] [options]

${BLD}COMMANDS${NC}
  ${ACC}(none)${NC}, menu       Interactive menu
  ${ACC}install${NC} <mod...>   Install modules             (add, i)
  ${ACC}remove${NC}  <mod...>   Remove modules              (rm)
  ${ACC}list${NC}               List modules & status       (ls)
  ${ACC}info${NC}    <module>   Show module details
  ${ACC}search${NC}  <word>     Search modules
  ${ACC}profile${NC} [name]     Install a bundle (minimal web backend android full)
  ${ACC}new${NC} [tpl] [name]   Scaffold a project from a template
  ${ACC}doctor${NC}             Diagnose your environment
  ${ACC}update${NC}             Update package index & upgrade packages
  ${ACC}self-update${NC}        Update tkit itself
  ${ACC}log${NC}                Show the install log
  ${ACC}completion${NC}         Print bash completion script

${BLD}OPTIONS${NC}
  -y, --yes        Answer "yes" to every prompt
  -n, --dry-run    Preview only, change nothing
      --no-color   Disable colors
  -v, --version    Print version
  -h, --help       Show help (tkit help <command>)

${BLD}EXAMPLES${NC}
  tkit profile web -y
  tkit install python git --dry-run
  tkit new telegram-bot my-bot
EOF
    ;;
  esac
}
