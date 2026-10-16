# lib/ui.sh - colors, banner, spinner, interactive menus

SPIN=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)

ui_init() {
  if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && (( ! ${NO_COLOR_FLAG:-0} )); then
    ACC=$'\033[38;5;39m'; GRN=$'\033[38;5;78m'; YLW=$'\033[38;5;221m'
    RED=$'\033[38;5;203m'; GRY=$'\033[38;5;245m'
    BLD=$'\033[1m'; DIM=$'\033[2m'; NC=$'\033[0m'
  else
    ACC=""; GRN=""; YLW=""; RED=""; GRY=""; BLD=""; DIM=""; NC=""
  fi
}

ui_cols() {
  local c; c=$(tput cols 2>/dev/null) || c=80
  [[ "$c" =~ ^[0-9]+$ ]] || c=80
  (( c < 30 )) && c=30
  echo "$c"
}

ui_cursor_hide() { [ -t 1 ] && printf '\033[?25l'; return 0; }
ui_cursor_show() { [ -t 1 ] && printf '\033[?25h'; return 0; }

# ---- messages ------------------------------------------------------
ui_ok()   { printf '  %s✔%s %s\n' "$GRN" "$NC" "$*"; }
ui_err()  { printf '  %s✘%s %s\n' "$RED" "$NC" "$*" >&2; }
ui_warn() { printf '  %s!%s %s\n' "$YLW" "$NC" "$*"; }
ui_info() { printf '  %s•%s %s\n' "$ACC" "$NC" "$*"; }
ui_skip() { printf '  %s•%s %s %s(already installed)%s\n' "$GRY" "$NC" "$1" "$GRY" "$NC"; }
ui_kv()   { printf '  %s%-12s%s %s\n' "$GRY" "$1" "$NC" "$2"; }

ui_rule() {
  local w t fill
  w=$(ui_cols); (( w > 60 )) && w=60
  t=" $1 "; fill=$(( w - ${#t} - 4 )); (( fill < 2 )) && fill=2
  printf '\n%s──%s%s%s%s' "$GRY" "$BLD$ACC" "$t" "$NC$GRY" ""
  printf '─%.0s' $(seq 1 "$fill")
  printf '%s\n' "$NC"
}

ui_banner() {
  local w inner bar rest ver tag pad
  w=$(ui_cols); (( w > 50 )) && w=50
  inner=$(( w - 2 ))
  bar=$(printf '─%.0s' $(seq 1 "$inner"))
  rest=" tkit  Termux DevKit"; ver="v$TKIT_VERSION "
  pad=$(( inner - 1 - ${#rest} - ${#ver} )); (( pad < 0 )) && pad=0
  tag=" Turn your phone into a dev workstation"
  tag="${tag:0:inner}"
  printf '%s╭%s╮%s\n' "$ACC" "$bar" "$NC"
  printf '%s│%s%s▲%s%s%s%s%*s%s%s%s%s│%s\n' "$ACC" "$NC" "$ACC" "$NC" "$BLD" "$rest" "$NC" "$pad" "" "$GRY" "$ver" "$NC" "$ACC" "$NC"
  printf '%s│%s%s%-*s%s%s│%s\n' "$ACC" "$NC" "$GRY" "$inner" "$tag" "$NC" "$ACC" "$NC"
  printf '%s╰%s╯%s\n' "$ACC" "$bar" "$NC"
}

# ---- prompts -------------------------------------------------------
confirm() {
  (( YES || DRY_RUN )) && return 0
  local a; read -rp "  $1 [y/N]: " a
  [[ "$a" =~ ^[Yy]$ ]]
}

ask() {
  local a=""
  (( YES || DRY_RUN )) || read -rp "  $1" a
  echo "$a"
}

ui_pause() {
  [ -t 0 ] || return 0
  echo; read -rsp "  Press Enter to continue..." _; echo
}

# ---- spinner task --------------------------------------------------
# ui_task "label" command args...
ui_task() {
  local label="$1"; shift
  if (( DRY_RUN )); then
    printf '  %s·%s %s  %sdry-run%s\n' "$GRY" "$NC" "$label" "$DIM" "$NC"
    return 0
  fi
  log "TASK $label :: $*"
  local rc pid i=0
  if [ ! -t 1 ]; then
    "$@" >>"$TKIT_LOG" 2>&1 </dev/null; rc=$?
  else
    "$@" >>"$TKIT_LOG" 2>&1 </dev/null &
    pid=$!
    ui_cursor_hide
    while kill -0 "$pid" 2>/dev/null; do
      printf '\r  %s%s%s %s' "$ACC" "${SPIN[i % 10]}" "$NC" "$label"
      i=$((i+1)); sleep 0.1
    done
    wait "$pid"; rc=$?
    printf '\r\033[K'
    ui_cursor_show
  fi
  if (( rc == 0 )); then ui_ok "$label"; else ui_err "$label  ${GRY}(see: tkit log)${NC}"; fi
  return $rc
}

# ---- interactive chooser ------------------------------------------
# Fill: CH_KEYS CH_LABELS CH_HINTS [CH_BADGES CH_DETAILS CH_PRE]
# Result: CH_OUT. Return 0=confirmed 1=cancelled 2=no tty
ch_reset() { CH_KEYS=(); CH_LABELS=(); CH_HINTS=(); CH_BADGES=(); CH_DETAILS=(); CH_PRE=(); CH_OUT=(); }

ui_choose() {
  local mode="$1" title="$2"
  if [ ! -t 0 ] || [ ! -t 1 ]; then
    ui_err "Interactive menu needs a terminal. Run 'tkit help' for CLI usage."; return 2
  fi
  local n=${#CH_KEYS[@]} cur=0 i lw=0 cols hw key rest d
  local -a sel=()
  for ((i=0; i<n; i++)); do
    sel[i]="${CH_PRE[i]:-0}"
    (( ${#CH_LABELS[i]} > lw )) && lw=${#CH_LABELS[i]}
  done
  CH_OUT=()
  ui_cursor_hide
  while true; do
    cols=$(ui_cols)
    if [ "$mode" = multi ]; then hw=$(( cols - lw - 9 )); else hw=$(( cols - lw - 7 )); fi
    printf '\033[H\033[J'
    ui_banner
    printf '\n %s%s%s\n\n' "$BLD" "$title" "$NC"
    for ((i=0; i<n; i++)); do
      local mk="" bd=" " lab hint
      printf -v lab '%-*s' "$lw" "${CH_LABELS[i]}"
      hint="${CH_HINTS[i]:-}"
      if (( hw <= 6 )); then hint=""; elif (( ${#hint} > hw )); then hint="${hint:0:hw-1}…"; fi
      [ -n "${CH_BADGES[i]:-}" ] && bd="${GRN}${CH_BADGES[i]}${NC}"
      if [ "$mode" = multi ]; then
        if [ "${sel[i]}" = 1 ]; then mk="${GRN}◉${NC} "; else mk="${GRY}○${NC} "; fi
      fi
      if (( i == cur )); then
        printf ' %s❯%s %s%s%s%s%s %s %s%s%s\n' "$ACC" "$NC" "$mk" "$BLD" "$ACC" "$lab" "$NC" "$bd" "$GRY" "$hint" "$NC"
      else
        printf '   %s%s %s %s%s%s\n' "$mk" "$lab" "$bd" "$GRY" "$hint" "$NC"
      fi
    done
    d="${CH_DETAILS[cur]:-}"
    printf '\n %s%s%s\n' "$GRY" "${d:0:cols-2}" "$NC"
    if [ "$mode" = multi ]; then
      printf ' %s↑↓ move  space pick  enter ok  q quit%s\n' "$DIM" "$NC"
    else
      printf ' %s↑↓ move  enter select  q quit%s\n' "$DIM" "$NC"
    fi

    IFS= read -rsn1 key || { ui_cursor_show; return 1; }
    if [[ $key == $'\e' ]]; then
      IFS= read -rsn2 -t 0.05 rest || true
      key+="$rest"
    fi
    case "$key" in
      $'\e[A'|$'\eOA'|k) cur=$(( (cur - 1 + n) % n )) ;;
      $'\e[B'|$'\eOB'|j) cur=$(( (cur + 1) % n )) ;;
      ' ') [ "$mode" = multi ] && sel[cur]=$(( 1 - sel[cur] )) ;;
      a|A) [ "$mode" = multi ] && for ((i=0; i<n; i++)); do sel[i]=1; done ;;
      n|N) [ "$mode" = multi ] && for ((i=0; i<n; i++)); do sel[i]=0; done ;;
      ''|$'\n'|$'\r')
        if [ "$mode" = multi ]; then
          for ((i=0; i<n; i++)); do [ "${sel[i]}" = 1 ] && CH_OUT+=("${CH_KEYS[i]}"); done
          (( ${#CH_OUT[@]} )) || CH_OUT=("${CH_KEYS[cur]}")
        else
          CH_OUT=("${CH_KEYS[cur]}")
        fi
        ui_cursor_show; printf '\033[H\033[J'; return 0 ;;
      q|Q|$'\e')
        ui_cursor_show; printf '\033[H\033[J'; return 1 ;;
    esac
  done
}

ui_init
