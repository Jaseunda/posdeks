#!/usr/bin/env bash
#
# setup-desktop.sh
# A script to install packages and configure a macOS-like Hyprland desktop,
# including Waybar status bar, Eww dock, Kitty terminal, and keyboard shortcuts.
# Must be run as root inside the installed Arch environment (e.g., in arch-chroot).
#

set -euo pipefail

### 1. CHECK INTERNET CONNECTIVITY ###
echo
echo "=== 1. Checking internet connectivity ==="
if ! ping -c 1 archlinux.org &> /dev/null; then
  echo "ERROR: No internet connection detected. Please ensure networking is up and retry."
  exit 1
fi
echo "Internet OK."

### 2. VARIABLES (ASSUME USER ALREADY EXISTS) ###
USERNAME="private"
USERHOME="/home/${USERNAME}"

# Verify that the user exists; abort if not.
if ! id "${USERNAME}" &> /dev/null; then
  echo "ERROR: User '${USERNAME}' does not exist. Please create the user first and retry."
  exit 1
fi

### 3. INITIALIZE PACMAN KEYS (IF NEEDED) ###
echo
echo "=== 2. Initializing pacman keyring ==="
pacman-key --init
pacman-key --populate archlinux
echo "Pacman keyring populated."

### 4. SYSTEM UPDATE ###
echo
echo "=== 3. System update (pacman -Syu) ==="
pacman -Syu --noconfirm --needed
echo "System is up to date."

### 5. INSTALL DESKTOP PACKAGES ###
echo
echo "=== 4. Installing desktop packages ==="
pacman -S --noconfirm --needed \
  networkmanager \
  pipewire pipewire-pulse wireplumber \
  dbus \
  lightdm lightdm-gtk-greeter \
  hyprland hyprpaper waybar eww mako \
  kitty \
  swaylock-effects \
  thunar gvfs gvfs-afc gvfs-smb \
  firefox trash-cli \
  papirus-icon-theme \
  ttf-iosevka ttf-jetbrains-mono \
  qt5ct qt6ct gnome-themes-extra \
  wofi \
  grim slurp pamixer pavucontrol-qt
echo "Desktop packages installed."

### 6. ENABLE SERVICES ###
echo
echo "=== 5. Enabling critical services ==="
systemctl enable NetworkManager.service
systemctl enable dbus.service
systemctl enable pipewire.service
systemctl enable pipewire-pulse.service
systemctl enable wireplumber.service
systemctl enable lightdm.service
echo "Services enabled."

### 7. CREATE USER CONFIG DIRECTORIES ###
echo
echo "=== 6. Creating configuration directories for ${USERNAME} ==="
runuser -l "${USERNAME}" -c 'mkdir -p ~/.config/hypr ~/.config/waybar ~/.config/eww ~/.config/mako ~/.config/kitty ~/.config/qt5ct ~/.config/gtk-3.0 ~/.icons ~/.themes ~/Pictures/Screenshots'
echo "Directories created."

### 8. WRITE HYPRLAND CONFIGURATION ###
echo
echo "=== 7. Writing ~/.config/hypr/hyprland.conf ==="
runuser -l "${USERNAME}" bash -c 'cat > ~/.config/hypr/hyprland.conf << "EOF"
# ============== Hyprland General ==============
monitor=*,1920x1080,1.0,0x0
cursor_theme = breeze_cursors
cursor_size = 24
workspace_names=1:,2:,3:,4:,5:,6:,7:,8:,9:,10:
window_gap_size = 8
split_ratio = 0.52
window_decoration = none
workspace_bar_enabled = 1
workspace_bar_position = top
workspace_bar_h_padding = 6
workspace_bar_v_padding = 2

# ============== Keybindings (macOS Style) ==============
bind=SUPER+RETURN,exec,kitty
bind=SUPER+Q,kill,focused
bind=SUPER+H,dispatch,moveactive workspace=west
bind=SUPER+L,dispatch,moveactive workspace=east
bind=SUPER+J,dispatch,moveactive workspace=down
bind=SUPER+K,dispatch,moveactive workspace=up
bind=SUPER+TAB,dispatch,workspace next
bind=SUPER+SHIFT+TAB,dispatch,workspace prev
bind=SUPER+SHIFT+H,dispatch,movecontainer west
bind=SUPER+SHIFT+L,dispatch,movecontainer east
bind=SUPER+SHIFT+J,dispatch,movecontainer down
bind=SUPER+SHIFT+K,dispatch,movecontainer up
bind=SUPER+CONTROL+H,dispatch,resizecontainer left 20
bind=SUPER+CONTROL+L,dispatch,resizecontainer right 20
bind=SUPER+CONTROL+J,dispatch,resizecontainer down 20
bind=SUPER+CONTROL+K,dispatch,resizecontainer up 20
bind=SUPER+SPACE,dispatch,togglefloating
bind=SUPER+F,exec,thunar
bind=SUPER+B,exec,firefox
bind=SUPER+P,exec,wofi --show drun
bind=SUPER+D,exec,eww toggle dock
bind=SUPER+L,exec,swaylock-effects --blur 8x4 --screenshots --indicator --clock
bind=PRINT,exec,slurp | xargs grim -g - ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png

# ============== Autostart Programs ==============
autostart = waybar
autostart = eww daemon
autostart = mako
autostart = hyprpaper img /usr/share/backgrounds/archlinux/arch-wallpaper.jpg

# ============== Window Rules ==============
windowrulev2 = float,app_id:thunar
windowrulev2 = float,app_id:pavucontrol
windowrulev2 = float,window_class:confirm
EOF'
echo "Hyprland config written."

### 9. WRITE WAYBAR CONFIG & STYLE ###
echo
echo "=== 8. Writing ~/.config/waybar/config and style.css ==="
runuser -l "${USERNAME}" bash -c 'cat > ~/.config/waybar/config << "EOF"
{
  "layer": "top",
  "position": "top",
  "height": 30,
  "background": "#2e2e2eDD",
  "modules-left": ["workspaces"],
  "modules-center": ["clock"],
  "modules-right": ["network", "pulseaudio", "cpu", "memory", "battery", "tray"],

  "workspaces": {
    "format": "{name}",
    "tooltip-format": "<b>Workspace</b>: {name}"
  },

  "clock": {
    "format": "%a %b %d %I:%M %p"
  },

  "network": {
    "format-online": " {essid}",
    "format-offline": "睊"
  },

  "pulseaudio": {
    "format": " {volume}",
    "format-muted": " Muted"
  },

  "cpu": {
    "format": " {load}%",
    "tooltip": false
  },

  "memory": {
    "format": " {used_mem}M/{total_mem}M"
  },

  "battery": {
    "format": " {capacity}%",
    "format-discharging": " {capacity}%"
  },

  "tray": {
    "icon-size": 20,
    "pin-workspace": false
  }
}
EOF'

runuser -l "${USERNAME}" bash -c 'cat > ~/.config/waybar/style.css << "EOF"
/* Waybar macOS-style theming */
* {
  font-family: "Iosevka Nerd Font", sans-serif;
  font-size: 12px;
  color: #EEEEEE;
}

#window {
  background: rgba(46, 46, 46, 0.9);
  border: none;
}

.module {
  margin: 0 8px;
}

.workspaces button.focused {
  background-color: #5d8aa8;
}

.workspaces button:hover {
  background-color: #3c3c3c;
}
EOF'
echo "Waybar config & style written."

### 10. WRITE EWW DOCK CONFIG ###
echo
echo "=== 9. Writing ~/.config/eww/dock.yml ==="
runuser -l "${USERNAME}" bash -c 'cat > ~/.config/eww/dock.yml << "EOF"
# eww "dock" widget for Hyprland
windows:
  dock:
    popup:
      width: 400
      height: 60
      y: 0.95
      x: 0.5
      anchor: center-top
      border: false
      background: "#2e2e2eCC"
      margin: 0
      edging: 0

    children:
      - button:
          class: "dock-button"
          onclick: "kitty"
          child:
            image:
              path: "/usr/share/icons/Papirus/48x48/apps/utilities-terminal.svg"
      - button:
          class: "dock-button"
          onclick: "thunar"
          child:
            image:
              path: "/usr/share/icons/Papirus/48x48/apps/xfce4-filemanager.svg"
      - button:
          class: "dock-button"
          onclick: "firefox"
          child:
            image:
              path: "/usr/share/icons/Papirus/48x48/apps/firefox.svg"
      - button:
          class: "dock-button"
          onclick: "trash-empty"
          child:
            image:
              path: "/usr/share/icons/Papirus/48x48/places/user-trash-full.svg"
styles:
  .dock-button:
    margin: 0 12px
    background: none
    border: none
    hover:
      background: "#3c3c3c"
      border-radius: 8px
    child:
      image:
        width: 36px
        height: 36px
        margin: 0
EOF'
echo "Eww dock config written."

### 11. WRITE KITTY CONFIGURATION ###
echo
echo "=== 10. Writing ~/.config/kitty/kitty.conf ==="
runuser -l "${USERNAME}" bash -c 'cat > ~/.config/kitty/kitty.conf << "EOF"
# Kitty — macOS-style transparent terminal

font_family      Iosevka Nerd Font
bold_font        auto
italic_font      auto
bold_italic_font auto

font_size        12.0

background_opacity 0.75

scrollback_lines 10000

decorations none

cursor_shape block
cursor_beam_thickness 1
cursor_underline_thickness 1

map cmd+shift+t new_window
map cmd+shift+w close_window
EOF'
echo "Kitty config written."

### 12. WRITE MAKO CONFIGURATION ###
echo
echo "=== 11. Writing ~/.config/mako/config ==="
runuser -l "${USERNAME}" bash -c 'cat > ~/.config/mako/config << "EOF"
# Mako notifications (macOS-style)
monitor=*
anchor=top_right
margin=10
padding=12
gap=8
max-visible=3
timeout=5.0

corner-radius=8

format="{app_name}: {summary}"
background="#333333cc"
foreground="#EEEEEE"
frame-color="#555555cc"
frame-width=1
font="Iosevka Nerd Font 11"
EOF'
echo "Mako config written."

### 13. WRITE GTK & QT THEME SETTINGS ###
echo
echo "=== 12. Writing GTK & QT theme settings ==="
runuser -l "${USERNAME}" bash -c 'cat > ~/.config/gtk-3.0/settings.ini << "EOF"
[Settings]
gtk-theme-name = WhiteSur-Dark
gtk-icon-theme-name = Papirus
gtk-font-name = Iosevka Nerd Font 11
gtk-cursor-theme-name = breeze_cursors
gtk-cursor-theme-size = 24
gtk-toolbar-style = GTK_TOOLBAR_BOTH_HORIZ
EOF'

runuser -l "${USERNAME}" bash -c 'cat > ~/.config/qt5ct/qt5ct.conf << "EOF"
[Appearance]
style=Adwaita
Palette=Dark

[Fonts]
font_family=Iosevka Nerd Font
font_size=10

[Icons]
theme=Papirus
EOF'
echo "GTK & QT settings written."

### 14. INSTALL WHITE SUR GTK THEME (OPTIONAL) ###
echo
echo "=== 13. Installing WhiteSur GTK theme (optional) ==="
runuser -l "${USERNAME}" bash -c 'bash -c "
  cd /tmp
  if [ ! -d WhiteSur-gtk-theme ]; then
    git clone https://github.com/vinceliuice/WhiteSur-gtk-theme.git
  fi
  cd WhiteSur-gtk-theme
  ./install.sh --yes
"'
echo "WhiteSur theme installed."

### 15. SET OWNERSHIP OF USER CONFIGS ###
echo
echo "=== 14. Setting ownership of user configs ==="
chown -R "${USERNAME}":"${USERNAME}" "${USERHOME}/.config" "${USERHOME}/.icons" "${USERHOME}/.themes" "${USERHOME}/Pictures/Screenshots"
echo "Ownership set."

### 16. FINAL MESSAGE ###
echo
echo "================================================================"
echo "Desktop environment installation and configuration complete!"
echo "✓ Reboot now, log in as ${USERNAME}, and choose the 'Hyprland' session."
echo "✓ Use Super (⌘) + D to toggle the dock, Super+Enter for Kitty, Super+L to lock, etc."
echo "================================================================"
