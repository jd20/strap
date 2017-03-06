#!/bin/bash
#/ Usage: bin/strap.sh [--debug]
#/ Install development dependencies on macOS.
set -e

# Keep sudo timestamp updated while Strap is running.
if [ "$1" = "--sudo-wait" ]; then
  while true; do
    mkdir -p "/var/db/sudo/$SUDO_USER"
    touch "/var/db/sudo/$SUDO_USER"
    sleep 1
  done
  exit 0
fi

[ "$1" = "--debug" ] && STRAP_DEBUG="1"
STRAP_SUCCESS=""

cleanup() {
  set +e
  if [ -n "$STRAP_SUDO_WAIT_PID" ]; then
    sudo kill "$STRAP_SUDO_WAIT_PID"
  fi
  sudo -k
  rm -f "$CLT_PLACEHOLDER"
  if [ -z "$STRAP_SUCCESS" ]; then
    if [ -n "$STRAP_STEP" ]; then
      echo "!!! $STRAP_STEP FAILED" >&2
    else
      echo "!!! FAILED" >&2
    fi
    if [ -z "$STRAP_DEBUG" ]; then
      echo "!!! Run '$0 --debug' for debugging output." >&2
      echo "!!! If you're stuck: file an issue with debugging output at:" >&2
      echo "!!!   $STRAP_ISSUES_URL" >&2
    fi
  fi
}

trap "cleanup" EXIT

if [ -n "$STRAP_DEBUG" ]; then
  set -x
else
  STRAP_QUIET_FLAG="-q"
  Q="$STRAP_QUIET_FLAG"
fi

STDIN_FILE_DESCRIPTOR="0"
[ -t "$STDIN_FILE_DESCRIPTOR" ] && STRAP_INTERACTIVE="1"

# Set by web/app.rb
# STRAP_GIT_NAME=
# STRAP_GIT_EMAIL=
# STRAP_GITHUB_USER=
# STRAP_GITHUB_TOKEN=
STRAP_ISSUES_URL="https://github.com/jd20/strap/issues/new"

STRAP_FULL_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

abort() { STRAP_STEP="";   echo "!!! $*" >&2; exit 1; }
log()   { STRAP_STEP="$*"; echo "--> $*"; }
logn()  { STRAP_STEP="$*"; printf -- "--> %s " "$*"; }
logk()  { STRAP_STEP="";   echo "OK"; }

[ "$USER" = "root" ] && abort "Run Strap as yourself, not root."
  groups | grep $Q admin || abort "Add $USER to the admin group."

if [ "$(uname -s)" == "Darwin" ]
then
  sw_vers -productVersion | grep $Q -E "^10.(9|10|11|12)" || {
    abort "Run Strap on macOS 10.9/10/11/12."
  }
else
  abort "Linux support coming soon..."
fi

# Initialise sudo now to save prompting later.
log "Enter your password (for sudo access):"
sudo -k
sudo /usr/bin/true
[ -f "$STRAP_FULL_PATH" ]
sudo bash "$STRAP_FULL_PATH" --sudo-wait &
STRAP_SUDO_WAIT_PID="$!"
ps -p "$STRAP_SUDO_WAIT_PID" &>/dev/null
logk

if [ "$(uname -s)" == "Darwin" ]
then
  # Install the Xcode Command Line Tools.
  DEVELOPER_DIR=$("xcode-select" -print-path 2>/dev/null || true)
  if [ -z "$DEVELOPER_DIR" ] || ! [ -f "$DEVELOPER_DIR/usr/bin/git" ] \
                            || ! [ -f "/usr/include/iconv.h" ]
  then
    log "Installing the Xcode Command Line Tools:"
    CLT_PLACEHOLDER="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
    sudo touch "$CLT_PLACEHOLDER"
    CLT_PACKAGE=$(softwareupdate -l | \
                  grep -B 1 -E "Command Line (Developer|Tools)" | \
                  awk -F"*" '/^ +\*/ {print $2}' | sed 's/^ *//' | head -n1)
    sudo softwareupdate -i "$CLT_PACKAGE"
    sudo rm -f "$CLT_PLACEHOLDER"
    if ! [ -f "/usr/include/iconv.h" ]; then
      if [ -n "$STRAP_INTERACTIVE" ]; then
        echo
        logn "Requesting user install of Xcode Command Line Tools:"
        xcode-select --install
      else
        echo
        abort "Run 'xcode-select --install' to install the Xcode Command Line Tools."
      fi
    fi
    logk
  fi

  # Check if the Xcode license is agreed to and agree if not.
  xcode_license() {
    if /usr/bin/xcrun clang 2>&1 | grep $Q license; then
      if [ -n "$STRAP_INTERACTIVE" ]; then
        logn "Asking for Xcode license confirmation:"
        sudo xcodebuild -license
        logk
      else
        abort "Run 'sudo xcodebuild -license' to agree to the Xcode license."
      fi
    fi
  }
  xcode_license
fi

# Setup Git configuration.
logn "Configuring Git:"
if [ -n "$STRAP_GIT_NAME" ] && ! git config user.name >/dev/null; then
  git config --global user.name "$STRAP_GIT_NAME"
fi

if [ -n "$STRAP_GIT_EMAIL" ] && ! git config user.email >/dev/null; then
  git config --global user.email "$STRAP_GIT_EMAIL"
fi

if [ -n "$STRAP_GITHUB_USER" ] && [ "$(git config github.user)" != "$STRAP_GITHUB_USER" ]; then
  git config --global github.user "$STRAP_GITHUB_USER"
fi

# Setup GitHub HTTPS credentials.
#if git credential-osxkeychain 2>&1 | grep $Q "git.credential-osxkeychain"
#then
#  if [ "$(git config --global credential.helper)" != "osxkeychain" ]
#  then
#    git config --global credential.helper osxkeychain
#  fi
#
#  if [ -n "$STRAP_GITHUB_USER" ] && [ -n "$STRAP_GITHUB_TOKEN" ]
#  then
#    printf "protocol=https\nhost=github.com\n" | git credential-osxkeychain erase
#    printf "protocol=https\nhost=github.com\nusername=%s\npassword=%s\n" \
#          "$STRAP_GITHUB_USER" "$STRAP_GITHUB_TOKEN" \
#          | git credential-osxkeychain store
#  fi
#fi
logk

# Setup dotfiles
if [ -n "$STRAP_GITHUB_USER" ]; then
  DOTFILES_URL="https://github.com/$STRAP_GITHUB_USER/dotfiles"

  if git ls-remote "$DOTFILES_URL" &>/dev/null; then
    log "Fetching $STRAP_GITHUB_USER/dotfiles from GitHub:"
    if [ ! -d "$HOME/dotfiles" ]; then
      log "Cloning to ~/dotfiles:"
      git clone $Q "$DOTFILES_URL" ~/dotfiles
    else
      (
        cd ~/dotfiles
        git pull $Q --rebase --autostash
      )
    fi
    (
      cd ~/dotfiles
      for i in script/setup script/bootstrap; do
        if [ -f "$i" ] && [ -x "$i" ]; then
          log "Running dotfiles $i:"
          "$i" 2>/dev/null
          break
        fi
      done
    )
    logk
  fi
fi

STRAP_SUCCESS="1"
log "Your system is now Strap'd!"
