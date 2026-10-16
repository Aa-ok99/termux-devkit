MOD_DESC="Automation: cron, ffmpeg, yt-dlp"
MOD_CAT="Tools"
MOD_DEPS="base"
MOD_PKGS="cronie termux-services ffmpeg yt-dlp"
mod_post() { ui_info "Enable cron after restarting Termux:  sv-enable crond"; }
