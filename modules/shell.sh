MOD_DESC="zsh, tmux, fzf + handy aliases"
MOD_CAT="Essentials"
MOD_DEPS="base"
MOD_PKGS="zsh tmux fzf"
mod_post() {
  local rc="$HOME/.bashrc"
  if grep -q "# --- tkit-aliases ---" "$rc" 2>/dev/null; then
    ui_ok "Aliases already in ~/.bashrc"; return
  fi
  if (( DRY_RUN )); then ui_info "Would append aliases to ~/.bashrc"; return; fi
  cat >> "$rc" << 'EOF'

# --- tkit-aliases ---
alias ll='ls -lah'
alias ..='cd ..'
alias gs='git status'
alias ga='git add .'
alias gc='git commit -m'
alias gp='git push'
alias myip='curl -s ifconfig.me; echo'
EOF
  ui_ok "Aliases added to ~/.bashrc"
}
