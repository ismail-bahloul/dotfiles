#!/bin/bash
# =============================================================================
# run_once_08-kde-settings.sh
# Run once by chezmoi (re-runs if this file changes)
# KDE Plasma 6 — enforce the settings we care about via kwriteconfig6
#
# Why: kwinrc / kdeglobals / appletsrc are rewritten at runtime (Plasma itself,
# or kde-material-you-colors for the colors). Versioning them as whole files
# causes constant drift and `chezmoi apply` clobbers runtime tweaks. So we only
# *impose* the settings below; Plasma/daemons stay the owner of everything else.
#
# Files NOT versioned (managed here or by a daemon):
#   - kwinrc      -> keys imposed below ; Plasma manages the rest (Tiling UUIDs...)
#   - kdeglobals  -> the COLORS are managed by kde-material-you-colors ; we only
#                    impose the non-color keys below
#   - appletsrc   -> create_ prefix (deployed only on a fresh install)
#
# Files versioned because stable (edited via the UI, re-committed after
# changes): kwinrulesrc, kxkbrc, kglobalshortcutsrc, katerc, dolphinrc,
#                konsolerc
# =============================================================================
set -e

# Logging helpers: .lib_logging.sh ships in the chezmoi source dir and is always
# present when run_once scripts run under chezmoi, so no fallback is needed.
source "${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}/.lib_logging.sh"

if ! command -v kwriteconfig6 &>/dev/null; then
  log_fatal "kwriteconfig6 not found (KDE Plasma required)"
fi

# --- KWin: effect plugins ---------------------------------------------------
log_info "KWin: effect plugins..."
kwriteconfig6 --file kwinrc --group Plugins --key better_blur_dxEnabled true
kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key translucencyEnabled true
kwriteconfig6 --file kwinrc --group Plugins --key wobblywindowsEnabled true
kwriteconfig6 --file kwinrc --group Plugins --key kwin4_effect_geometry_changeEnabled true
kwriteconfig6 --file kwinrc --group Plugins --key krohnkiteEnabled false

# --- KWin: better-blur effect ("blur everything" mode, optional exceptions) --
# BlurMatching=false + BlurNonMatching=true: everything is forced to blur EXCEPT
# the classes listed in WindowClasses (EXCEPTIONS list; empty = blur everything).
# This mode is preferred because it removes the class of bugs "translucent window
# but not blurred": no more class to remember to add. The blur is only VISIBLE
# under translucent windows; opaque windows do not change.
# (A former "lag when dragging on the external screen" had been wrongly blamed on
#  the global blur: the real cause was colorPowerTradeoff=PreferAccuracy on DP-2.)
log_info "KWin: better-blur effect (blur everything)..."
kwriteconfig6 --file kwinrc --group Effect-better-blur-dx --key BlurDecorations true
kwriteconfig6 --file kwinrc --group Effect-better-blur-dx --key BlurDocks true
kwriteconfig6 --file kwinrc --group Effect-better-blur-dx --key BlurMenus true
kwriteconfig6 --file kwinrc --group Effect-better-blur-dx --key BlurStrength 12
kwriteconfig6 --file kwinrc --group Effect-better-blur-dx --key Brightness 150
kwriteconfig6 --file kwinrc --group Effect-better-blur-dx --key Contrast 200
kwriteconfig6 --file kwinrc --group Effect-better-blur-dx --key NoiseStrength 0
kwriteconfig6 --file kwinrc --group Effect-better-blur-dx --key Saturation 200
# NOTE: kwriteconfig6 escapes backslashes -> real newlines are required.
# WindowClasses = EXCEPTIONS list (empty = blur everyone).
kwriteconfig6 --file kwinrc --group Effect-better-blur-dx --key WindowClasses ""
kwriteconfig6 --file kwinrc --group Effect-better-blur-dx --key BlurMatching false
kwriteconfig6 --file kwinrc --group Effect-better-blur-dx --key BlurNonMatching true

# --- KWin: desktops & Xwayland ----------------------------------------------
log_info "KWin: desktops / Xwayland..."
kwriteconfig6 --file kwinrc --group Desktops --key Number 2
kwriteconfig6 --file kwinrc --group Desktops --key Rows 1
kwriteconfig6 --file kwinrc --group Xwayland --key Scale 1

# --- Plasma desktop: middle-click paste / right-click menu --------------------
log_info "Plasma: desktop click actions..."
kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc --group ActionPlugins --group 0 --key 'MiddleButton;NoModifier' org.kde.paste
kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc --group ActionPlugins --group 0 --key 'RightButton;NoModifier' org.kde.contextmenu
kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc --group ActionPlugins --group 1 --key 'RightButton;NoModifier' org.kde.contextmenu

# --- kdeglobals: NON-color keys (colors = kde-material-you-colors) ----------
# NB: we do NOT touch the accent (neither accentColorFromWallpaper nor AccentColor):
# it is set manually by the user (gray accent) and must stay that way.
log_info "kdeglobals: non-color preferences..."
kwriteconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage org.kde.breezedark.desktop
kwriteconfig6 --file kdeglobals --group KDE --key ShowDeleteCommand false
kwriteconfig6 --file kdeglobals --group KDE --key contrast 4
kwriteconfig6 --file kdeglobals --group KDE --key frameContrast 0.2
kwriteconfig6 --file kdeglobals --group PreviewSettings --key EnableRemoteFolderThumbnail false
kwriteconfig6 --file kdeglobals --group PreviewSettings --key MaximumRemoteSize 0
# File dialogs (KFileDialog Settings)
kwriteconfig6 --file kdeglobals --group 'KFileDialog Settings' --key 'View Style' DetailTree
kwriteconfig6 --file kdeglobals --group 'KFileDialog Settings' --key 'Show hidden files' false
kwriteconfig6 --file kdeglobals --group 'KFileDialog Settings' --key 'Show Full Path' false
kwriteconfig6 --file kdeglobals --group 'KFileDialog Settings' --key 'Breadcrumb Navigation' false
kwriteconfig6 --file kdeglobals --group 'KFileDialog Settings' --key 'Show Inline Previews' true
kwriteconfig6 --file kdeglobals --group 'KFileDialog Settings' --key 'Show Preview' false
kwriteconfig6 --file kdeglobals --group 'KFileDialog Settings' --key 'Show Speedbar' true
kwriteconfig6 --file kdeglobals --group 'KFileDialog Settings' --key 'Sort by' Name
kwriteconfig6 --file kdeglobals --group 'KFileDialog Settings' --key 'Sort directories first' true
kwriteconfig6 --file kdeglobals --group 'KFileDialog Settings' --key 'Sort hidden files last' false
kwriteconfig6 --file kdeglobals --group 'KFileDialog Settings' --key 'Sort reversed' false
kwriteconfig6 --file kdeglobals --group 'KFileDialog Settings' --key 'Speedbar Width' 140
kwriteconfig6 --file kdeglobals --group 'KFileDialog Settings' --key 'Decoration position' 2
kwriteconfig6 --file kdeglobals --group 'KFileDialog Settings' --key 'Allow Expansion' false
kwriteconfig6 --file kdeglobals --group 'KFileDialog Settings' --key 'Automatically select filename extension' true

# --- Apply without logout (best-effort) --------------------------------------
log_info "Reloading KWin config..."
if command -v qdbus6 &>/dev/null; then
  qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
elif command -v qdbus &>/dev/null; then
  qdbus org.kde.KWin /KWin reconfigure 2>/dev/null || true
fi

log_pass "KDE settings applied."
