MOD_DESC="Node.js LTS + npm (nodemon optional)"
MOD_CAT="Languages"
MOD_DEPS="base"
MOD_PKGS="nodejs-lts"
mod_post() {
  if confirm "Install nodemon & express-generator globally?"; then
    run npm install -g nodemon express-generator
  fi
}
