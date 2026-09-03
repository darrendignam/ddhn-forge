#!/bin/bash
# Runtime desktop configuration for the ViPER container.
#
# Desktop appearance comes from the system-wide dconf database baked into the image. This
# script only handles what cannot be done at build time, because /config is a volume mount
# and is replaced when the container starts:
#   - populating /config/Desktop with the tool launchers
#   - marking those launchers trusted, which is per-file user metadata
#   - the Conky config and process

LOG_FILE="/config/viper-post-install.log"
DESKTOP_DIR="/config/Desktop"
MARKER_FILE="/config/.viper-desktop-configured"
SOURCE_DESKTOP_DIR="/usr/local/share/viper/desktop"

log() { echo "$(date): $*" >> "$LOG_FILE"; }

CURRENT_USER=$(whoami)

run_as_abc() {
  if [[ "$CURRENT_USER" == "root" ]]; then
    runuser -u abc -- bash -c "$1"
  else
    bash -c "$1"
  fi
}

# mate-session restarts an autostart entry whose process misbehaves, and an earlier
# version of this script quit Caja at the end, which retriggered it in a tight loop:
# 49 concurrent copies and 14 stray conky processes on one boot. The Caja restart is
# gone, and this lock makes a second instance impossible regardless.
exec 9>/config/.viper-post-install.lock
if ! flock -n 9; then
  log "Another instance holds the lock, exiting"
  exit 0
fi

log "Starting ViPER desktop configuration as $CURRENT_USER"

# toggle-conky.sh owns the whole job: it resolves the screen geometry, the network
# interface and the working volume, fills in every placeholder in the template and
# starts conky. Doing any of that here as well means two implementations that drift,
# and they did: this used to substitute only the interface, which left __CPUGRAPH__,
# __WORKDIR__ and the rest showing as literal text in the panel.
start_conky() {
  [[ -x /usr/local/bin/toggle-conky.sh ]] || return 0
  log "Starting Conky system monitor"
  run_as_abc 'export DISPLAY=:1; pkill -x conky; sleep 1; /usr/local/bin/toggle-conky.sh' >> "$LOG_FILE" 2>&1
}

# zsh opens a blocking zsh-newuser-install menu the first time a terminal starts if the
# account has no .zshrc. /config is a volume, so the file cannot be baked into the image
# and has to be placed here, on every start rather than once: a user who deletes it
# should not be dropped back into the setup menu.
if [[ -f /usr/local/share/viper/zshrc && ! -f /config/.zshrc ]]; then
  cp /usr/local/share/viper/zshrc /config/.zshrc
  chown abc:abc /config/.zshrc
  chmod 644 /config/.zshrc
  log "Installed default .zshrc"
fi

# Seed the shell history so the grey autosuggestions work on a first run. viper.zsh does
# this too, but only for a shell whose HOME already has no history; doing it here means
# it is present before the first terminal ever opens.
if [[ -f /usr/local/share/viper/viper-history && ! -f /config/.zsh_history ]]; then
  cp /usr/local/share/viper/viper-history /config/.zsh_history
  chown abc:abc /config/.zsh_history
  chmod 600 /config/.zsh_history
  log "Seeded zsh history"
fi

if [[ -f "$MARKER_FILE" ]]; then
  log "Desktop already configured, starting Conky only"
  start_conky
  exit 0
fi

# Caja draws the desktop, so there is nothing to populate until it is running.
log "Waiting for the MATE session"
for _ in {1..30}; do
  if pgrep -x caja > /dev/null && pgrep -x marco > /dev/null; then
    log "MATE session is ready"
    break
  fi
  sleep 1
done

mkdir -p "$DESKTOP_DIR"
chmod 755 "$DESKTOP_DIR"

if [[ -r "$SOURCE_DESKTOP_DIR" ]]; then
  log "Copying tool launchers from $SOURCE_DESKTOP_DIR"
  cp -v "$SOURCE_DESKTOP_DIR"/*.desktop "$DESKTOP_DIR/" >> "$LOG_FILE" 2>&1
  chmod 755 "$DESKTOP_DIR"/*.desktop
else
  # Distinguish the two failure modes: an absent staging directory means the build
  # skipped desktop-staging.yml, an unreadable one means a permissions regression.
  if [[ -e "$SOURCE_DESKTOP_DIR" ]]; then
    log "ERROR: $SOURCE_DESKTOP_DIR exists but is not readable by $CURRENT_USER"
  else
    log "ERROR: $SOURCE_DESKTOP_DIR is missing, the desktop will have no tool icons"
  fi
fi

# Caja shows "Untrusted application launcher" instead of running a .desktop file unless
# this metadata flag is set. It is per-file and per-user, so it cannot be baked in.
log "Marking launchers as trusted for Caja"
for file in "$DESKTOP_DIR"/*.desktop; do
  [[ -f "$file" ]] || continue
  run_as_abc "gio set '$file' metadata::caja-trusted-launcher true" >> "$LOG_FILE" 2>&1
done

# Folder shortcuts. A symlink to a directory is what Caja needs; unlike a .desktop
# launcher it opens on double click with no trust flag and accepts dropped files.
FOLDER_LIST=/usr/local/share/viper/desktop-folders.conf
if [[ -f "$FOLDER_LIST" ]]; then
  while IFS=$'\t' read -r name target; do
    [[ -z "${name}" || "${name}" == \#* ]] && continue
    [[ -d "$target" ]] || { log "WARNING: shortcut target $target is missing, skipping"; continue; }
    ln -sfn "$target" "$DESKTOP_DIR/$name"
    chown -h abc:abc "$DESKTOP_DIR/$name"
    log "Linked $name to $target"
  done < "$FOLDER_LIST"
fi

if [[ -f /usr/local/share/conky/conky.conf ]]; then
  # Nothing to do here. The config is generated by toggle-conky.sh at start_conky time,
  # from the template in /usr/local/share/conky, so that the geometry matches the
  # display the session actually came up at.
  log "Conky template present, config is generated at start"
fi

log "Setting Firefox as the default browser"
for mime in x-scheme-handler/http x-scheme-handler/https text/html; do
  run_as_abc "export DISPLAY=:1; xdg-mime default firefox.desktop $mime" >> "$LOG_FILE" 2>&1
done

# No Caja restart here. Caja watches the desktop directory with a file monitor and
# picks up new launchers on its own, and quitting it made mate-session relaunch this
# script in a loop.
start_conky

touch "$MARKER_FILE"
log "ViPER desktop configuration completed"
