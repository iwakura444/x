#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

log()  { printf '%b\n' "$*"; }
ok()   { log "✅ $*"; }
warn() { log "⚠️  $*"; }
fail() { log "❌ $*"; }

on_err() {
  local exit_code=$?
  fail "Install failed (exit ${exit_code})."
  fail "Check the output above; nothing is deleted, re-run is safe."
  exit "${exit_code}"
}
trap on_err ERR

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { fail "Missing command: $1"; exit 1; }
}

is_arch() {
  [[ -r /etc/os-release ]] || return 1
  # shellcheck disable=SC1091
  . /etc/os-release
  [[ "${ID:-}" == "arch" || "${ID_LIKE:-}" == *"arch"* ]]
}

pacman_install() {
  local -a pkgs=("$@")
  sudo pacman -Syu --needed --noconfirm "${pkgs[@]}"
}

ensure_aur_helper() {
  if command -v yay >/dev/null 2>&1; then
    ok "AUR helper detected: yay"
    return 0
  fi

  warn "No AUR helper found. Installing yay…"
  require_cmd git
  require_cmd makepkg
  local tmp
  tmp="$(mktemp -d)"
  (
    cd "${tmp}"
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
  )
  rm -rf "${tmp}"
  ok "Installed yay"
}

symlink_item() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname -- "${dest}")"
  if [[ -L "${dest}" || -e "${dest}" ]]; then
    if [[ -L "${dest}" && "$(readlink -- "${dest}")" == "${src}" ]]; then
      ok "Symlink already OK: ${dest}"
      return 0
    fi
    local backup="${dest}.bak.$(date +%Y%m%d-%H%M%S)"
    mv -f -- "${dest}" "${backup}"
    warn "Backed up existing: ${dest} -> ${backup}"
  fi
  ln -s -- "${src}" "${dest}"
  ok "Linked: ${dest} -> ${src}"
}

main() {
  ok "Starting Transparent Pink rice installer"

  if ! is_arch; then
    fail "This installer supports Arch Linux only."
    fail "Detected: $(uname -a)"
    exit 1
  fi
  ok "Arch Linux detected"

  require_cmd sudo
  require_cmd pacman

  ok "Installing core packages (pacman)…"
  pacman_install \
    hyprland xdg-desktop-portal-hyprland \
    waybar \
    kitty \
    fish \
    rofi \
    mako \
    grim slurp wl-clipboard swappy \
    swaybg \
    hyprlock \
    wlogout \
    brightnessctl pamixer \
    pipewire pipewire-pulse wireplumber \
    polkit-gnome \
    network-manager-applet \
    fastfetch \
    ttf-jetbrains-mono-nerd \
    noto-fonts noto-fonts-cjk noto-fonts-emoji \
    gtk3 gtk4 \
    gsettings-desktop-schemas \
    unzip jq
  ok "Pacman packages installed"

  ensure_aur_helper
  ok "Installing AUR packages (yay)…"
  yay -S --needed --noconfirm \
    rofi-lbonn-wayland-git \
    catppuccin-gtk-theme-mocha \
    papirus-icon-theme
  ok "AUR packages installed"

  ok "Symlinking dotfiles into ~/.config…"
  mkdir -p "${HOME}/.config"
  if [[ -d "${REPO_ROOT}/dotfiles/.config" ]]; then
    while IFS= read -r -d '' dir; do
      rel="${dir#${REPO_ROOT}/dotfiles/.config/}"
      symlink_item "${dir}" "${HOME}/.config/${rel}"
    done < <(find "${REPO_ROOT}/dotfiles/.config" -mindepth 1 -maxdepth 1 -type d -print0)
  else
    fail "Missing ${REPO_ROOT}/dotfiles/.config (repo corrupted?)"
    exit 1
  fi

  ok "Symlinking scripts into ~/scripts…"
  mkdir -p "${HOME}/scripts"
  if [[ -d "${REPO_ROOT}/scripts" ]]; then
    while IFS= read -r -d '' f; do
      base="$(basename -- "${f}")"
      symlink_item "${f}" "${HOME}/scripts/${base}"
      chmod +x -- "${f}" || true
    done < <(find "${REPO_ROOT}/scripts" -maxdepth 1 -type f -print0)
  fi

  ok "Setting Fish as default shell…"
  if ! grep -qx '/usr/bin/fish' /etc/shells; then
    warn "/usr/bin/fish not listed in /etc/shells; adding it (requires sudo)."
    echo '/usr/bin/fish' | sudo tee -a /etc/shells >/dev/null
  fi
  if [[ "${SHELL:-}" != "/usr/bin/fish" ]]; then
    chsh -s /usr/bin/fish || warn "chsh failed (log out/in and re-run if needed)."
  fi
  ok "Default shell configured"

  ok "Applying GTK theme + icons (best-effort)…"
  mkdir -p "${HOME}/.config/gtk-3.0" "${HOME}/.config/gtk-4.0"
  cp -f -- "${REPO_ROOT}/dotfiles/.config/gtk-3.0/settings.ini" "${HOME}/.config/gtk-3.0/settings.ini"
  cp -f -- "${REPO_ROOT}/dotfiles/.config/gtk-4.0/settings.ini" "${HOME}/.config/gtk-4.0/settings.ini"
  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface gtk-theme 'Catppuccin-Mocha-Standard-Pink-Dark' || true
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' || true
    gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice' || true
  fi
  ok "GTK settings applied"

  ok "Done. Reboot or log out/in, then start Hyprland."
  ok "Tip: place your image at assets/fetch.png in the repo (or update fastfetch config)."
}

main "$@"

