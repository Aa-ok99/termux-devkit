MOD_DESC="Python 3 + pip (requests, flask optional)"
MOD_CAT="Languages"
MOD_DEPS="base"
MOD_PKGS="python python-pip"
mod_post() {
  if confirm "Install requests, flask, beautifulsoup4?"; then
    run pip install requests flask beautifulsoup4
  fi
}
