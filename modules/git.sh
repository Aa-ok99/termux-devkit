MOD_DESC="Git & GitHub: gh CLI, SSH key, identity"
MOD_CAT="Essentials"
MOD_DEPS="base"
MOD_PKGS="git gh openssh"
mod_post() {
  local n e
  n=$(git config --global user.name 2>/dev/null)
  e=$(git config --global user.email 2>/dev/null)
  if [ -z "$n" ]; then n=$(ask "Git user name: ");  [ -n "$n" ] && run git config --global user.name "$n"; fi
  if [ -z "$e" ]; then e=$(ask "Git user email: "); [ -n "$e" ] && run git config --global user.email "$e"; fi
  run git config --global init.defaultBranch main

  if [ ! -f "$HOME/.ssh/id_ed25519" ] && confirm "Create an SSH key for GitHub?"; then
    run ssh-keygen -t ed25519 -C "${e:-termux}" -f "$HOME/.ssh/id_ed25519" -N ""
    if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
      ui_info "Add this public key at GitHub > Settings > SSH keys:"
      cat "$HOME/.ssh/id_ed25519.pub"
    fi
  fi
  if (( ! YES && ! DRY_RUN )) && confirm "Log in to GitHub CLI now?"; then run gh auth login; fi
}
