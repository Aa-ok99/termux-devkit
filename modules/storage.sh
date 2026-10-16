MOD_DESC="Access phone storage (~/storage)"
MOD_CAT="Essentials"
mod_check() { [ -d "$HOME/storage" ]; }
mod_post()  { run termux-setup-storage; }
