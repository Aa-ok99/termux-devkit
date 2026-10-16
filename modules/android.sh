MOD_DESC="Android dev: adb, JDK 17, Gradle, Termux:API"
MOD_CAT="Platforms"
MOD_DEPS="base"
MOD_PKGS="termux-api android-tools openjdk-17 gradle"
mod_post() { ui_warn "Install the Termux:API app (F-Droid) so termux-* commands work"; }
