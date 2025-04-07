#!/usr/bin/env bash
## Noob friendly elden ring mod loader for linux/proton/steam
## If you execute the script without args it will print the launch options you should set for Elden Ring in steam
## If you want to install additional dll mods that aren't included in this script, you can do so by installing them
## in the game directory's mods folder, this script won't manage any dll mods it isn't aware of

set -euo pipefail

# Paths and defaults
STEAM_PATH="${STEAM_PATH:-"$HOME"/.steam/steam}"
ER_PATH="${ER_PATH:-$STEAM_PATH/steamapps/common/ELDEN RING/Game}"
ZENITY=${STEAM_ZENITY:-zenity}
UNZIP=${STEAM_UNZIP:-unzip}
CURL=${STEAM_CURL:-curl}
SHA256SUM=${STEAM_SHA256SUM:-sha256sum}
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
LOG_FILE="$SCRIPT_DIR/elden-proton.log"

# Initialize log file
log_init() {
    mkdir -p "$SCRIPT_DIR"
    echo "=== Elden Proton Log Started $(date) ===" > "$LOG_FILE"
    echo "STEAM_PATH: $STEAM_PATH" >> "$LOG_FILE"
    echo "ER_PATH: $ER_PATH" >> "$LOG_FILE"
    echo "SCRIPT_DIR: $SCRIPT_DIR" >> "$LOG_FILE"
    chmod 644 "$LOG_FILE"
}

# Log messages with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Log errors with timestamp
log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
}

# Initialize log
log_init

# Steam runtime handling
if [[ -d "${STEAM_RUNTIME:-}" ]]; then
    log_message "Steam runtime detected"
	# https://github.com/Cloudef/elden-proton/issues/4
    OLD_LIBRARY_PATH="$LD_LIBRARY_PATH"
    export LD_LIBRARY_PATH=
	# https://github.com/Cloudef/elden-proton/issues/6
    if [[ ! "${STEAM_ZENITY:-}" ]] || [[ "${STEAM_ZENITY:-}" == zenity ]]; then
        if [[ "${SYSTEM_PATH:-}" ]]; then
            ZENITY="${SYSTEM_ZENITY:-$(PATH="$SYSTEM_PATH" which zenity)}"
        else
			# last fallback
            ZENITY="${SYSTEM_ZENITY:-/usr/bin/zenity}"
        fi
    fi
    log_message "Using zenity: $ZENITY"
fi

# Print launch options if no arguments
if [[ "x$@" == "x" ]]; then
    log_message "No arguments provided, displaying launch options"
    if test -t 0; then
        printf "%s\n" "bash \"$(realpath "$0")\" %command%"
    else
        $ZENITY --info --title "Elden Proton" --text "$(realpath "$0") %command%"
    fi
    exit 0
fi

# effortless nixos support, requires flakes enabled
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    if [[ "$ID" == nixos ]]; then
        log_message "NixOS detected, using nix tools"
        UNZIP="${STEAM_UNZIP:-$(nix shell nixpkgs#unzip -c which unzip)}"
        CURL="${STEAM_CURL:-$(nix shell nixpkgs#curl -c which curl)}"
        SHA256SUM="${STEAM_SHA256SUM:-$(nix shell nixpkgs#coreutils -c which sha256sum)}"
    fi
fi

# Check unzip availability
if ! $UNZIP -v 1>/dev/null; then
    log_error "Unzip command failed"
    $ZENITY --error --title "Elden Proton" --text "Executing unzip failed... Do you have unzip installed?"
    exit 1
fi

# Temporary directory for downloads
tmpdir="$(mktemp -d)"
log_message "Created temporary directory: $tmpdir"
trap 'rm -rf "$tmpdir"; log_message "Removed temporary directory"' EXIT

# URLs and checksums for required files
elden_mod_loader_url="https://github.com/techiew/EldenRingModLoader/releases/download/Binary/EldenModLoader.zip"
elden_mod_loader_sha256="41d90de7506474689fd711ac421897642a3f5ff0391c313773263a43a83af66d"

mod_engine_proton_url="https://github.com/Cloudef/ModEngine2/releases/download/2.1.0.0-proton-v1/ModEngine-2.1.0.0-win64.zip"
mod_engine_proton_sha256="b8c858594529be3fc428840c263ed5a367283243111d01e1d75fbb40903d95c2"

# List of DLL mods
read -r -d '' elden_mod_loader_mods <<'EOV' || true
Adjust The Fov
mods/AdjustTheFov.dll
mods/AdjustTheFov/config.ini
https://github.com/techiew/EldenRingMods/releases/download/Binaries/AdjustTheFov.zip
339a27e94780c1550380d0fbc81026265da0539f95cfd004b012ec5c99c8323b
Disable Rune Loss
mods/DisableRuneLoss.dll

https://github.com/techiew/EldenRingMods/releases/download/Binaries/DisableRuneLoss.zip
6d69b51cde189b8ebedcd858aa5b25bb394c49e8e1df79c207a28d46ce0ccf6b
Fix The Camera
mods/CameraFix.dll
mods/CameraFix/config.ini
https://github.com/techiew/EldenRingMods/releases/download/Binaries/FixTheCamera.zip
749174278e9147fb099c37592f98811c9e737645c913d12fe64b9b94bd03250d
Increase Animation Distance
mods/IncreaseAnimationDistance.dll

https://github.com/techiew/EldenRingMods/releases/download/Binaries/IncreaseAnimationDistance.zip
4a120852e5eb71e42abd2d7180a7fbf0a4eb8fbcda797d4cbba54c865b1dc4af
Pause The Game
mods/PauseTheGame.dll
mods/PauseTheGame/pause_keybinds.ini
https://github.com/techiew/EldenRingMods/releases/download/Binaries/PauseTheGame.zip
9040fc6442d45f70c44d4a711cea6f4078b811e0761f799d36b5e133987d8928
Remove Black Bars
mods/UltrawideFix.dll

https://github.com/techiew/EldenRingMods/releases/download/Binaries/RemoveBlackBars.zip
905f1ebc76a411d89f9276677000a10de200951209d0eacad812c4aefc3c13e0
Remove Chromatic Aberration
mods/RemoveChromaticAbberation.dll

https://github.com/techiew/EldenRingMods/releases/download/Binaries/RemoveChromaticAberration.zip
2b9725dbc9c0825bb7f366bc8d01e659d62db4bc12d89ceb4d55287a3c23d13f
Remove Vignette
mods/RemoveVignette.dll

https://github.com/techiew/EldenRingMods/releases/download/Binaries/RemoveVignette.zip
cdd9a3faf127d7f6fdf57e0e3772d1e849603b2c20ad32a41b8883fb6e3600d6
Skip The Intro
mods/SkipTheIntro.dll
mods/SkipTheIntro/config.ini
https://github.com/techiew/EldenRingMods/releases/download/Binaries/SkipTheIntro.zip
5a23e1f1aafbf439072801f4f16cd624664f9d64761e9816fe29b597e17bef75
Unlock The Fps
mods/UnlockTheFps.dll
mods/UnlockTheFps/config.ini
https://github.com/techiew/EldenRingMods/releases/download/Binaries/UnlockTheFps.zip
116a523d858ab76ed38ca8a918c1f1e393d646f4d632ea2f692a614524b86a51
EOV

# Function to download and verify files
download_and_verify() {
    log_message "Downloading: $1"
    local fpath="$tmpdir/$(basename "$1")"
    if ! $CURL -sSL "$1" -o "$fpath"; then
        log_error "Curl download failed for: $1"
        $ZENITY --error --title "Elden Proton" --text "Executing curl failed... Do you have curl installed?"
        exit 1
    fi
    local sum=($($SHA256SUM "$fpath"))
    if [[ $? != 0 ]]; then
        log_error "SHA256 check failed"
        $ZENITY --error --title "Elden Proton" --text "Executing sha256sum failed... Do you have sha256sum installed?"
        exit 1
    fi
    if [[ "$sum" != "$2" ]]; then
        log_error "Integrity check failed for: $1 (expected: $2, got: $sum)"
        $ZENITY --error --title "Elden Proton" --text "Integrity check failed\n$1\ngot: $sum\nexpected: $2"
        exit 1
    fi
    log_message "Download successful, checksum verified"
    mkdir -p "$ER_PATH/EldenProton"
    printf '%s' "$2" > "$ER_PATH/EldenProton/$3.sha256"
}

# Function to verify local resource
verify_local_resource() {
    log_message "Verifying local resource: $1"
    if [[ -f "$ER_PATH/EldenProton/$1.sha256" ]] && [[ "$(cat "$ER_PATH/EldenProton/$1.sha256")" == "$2" ]]; then
        log_message "Resource verified: $1"
        return 0
    else
        log_message "Resource needs download: $1"
        return 1
    fi
}

# Function to download DLL mod
download_dll_mod() {
    if verify_local_resource "$3" "$2"; then
        return 0
    fi

    local fpath="$tmpdir/$(basename "$1")"
    download_and_verify "$1" "$2" "$3"
    log_message "Extracting DLL mod: $3"
    (cd "$ER_PATH" && $UNZIP -qq -o "$fpath")
}

# Function to list DLL mods
dll_mod_list() {
    log_message "Generating DLL mod list"
    while {
        read -r name
        read -r dll
        read -r config
        read -r url
        read -r sha256
    }; do
        if grep -Fx "$name" "$ER_PATH/EldenProton/dllmods.enabled" > /dev/null; then
            printf '%s\n%s\n' "TRUE" "$name"
        else
            printf '%s\n%s\n' "FALSE" "$name"
        fi
    done <<<"$elden_mod_loader_mods"
}

# Function to list configs
config_list() {
    log_message "Generating config list"
    printf '%s\n%s\n' "Elden Mod Loader" "mod_loader_config.ini"
    while {
        read -r name
        read -r dll
        read -r config
        read -r url
        read -r sha256
    }; do
        if [[ "x$config" != x ]] && grep -Fx "$name" "$ER_PATH/EldenProton/dllmods.enabled" > /dev/null; then
            printf '%s\n%s\n' "$name" "$config"
        fi
    done <<<"$elden_mod_loader_mods"
}

# Function to download enabled DLL mods
download_enabled_dll_mods() {
    log_message "Downloading enabled DLL mods"
    while {
        read -r name
        read -r dll
        read -r config
        read -r url
        read -r sha256
    }; do
        if grep -Fx "$name" "$ER_PATH/EldenProton/dllmods.enabled" > /dev/null; then
            [[ -f "$ER_PATH/$dll.disabled" ]] && mv "$ER_PATH/$dll.disabled" "$ER_PATH/$dll"
            download_dll_mod "$url" "$sha256" "$name"
        elif [[ -f "$ER_PATH/$dll" ]]; then
            mv "$ER_PATH/$dll" "$ER_PATH/$dll.disabled"
        fi
    done <<<"$elden_mod_loader_mods"
    touch "$tmpdir/integrity.ok"
}

# Function to download required files
download_required_files() {
    echo "10"
    if ! verify_local_resource elden_mod_loader "$elden_mod_loader_sha256"; then
        download_and_verify "$elden_mod_loader_url" "$elden_mod_loader_sha256" elden_mod_loader
        (cd "$ER_PATH" && $UNZIP -qq -o "$tmpdir/EldenModLoader.zip")
        sed -i 's/load_delay = 5000/load_delay = 2000/' "$ER_PATH/mod_loader_config.ini"
    fi
    echo "45"
    if ! verify_local_resource mod_engine_proton "$mod_engine_proton_sha256"; then
        download_and_verify "$mod_engine_proton_url" "$mod_engine_proton_sha256" mod_engine_proton
        (cd "$ER_PATH/mods" && $UNZIP -qq -jo "$tmpdir/ModEngine-2.1.0.0-win64.zip" "ModEngine-2.1.0.0-win64/modengine2/bin/*")
    fi
    echo "100"
    touch "$tmpdir/integrity.ok"
}

# Check if Elden Ring is installed
if [[ ! -f "$ER_PATH/eldenring.exe" ]]; then
    log_error "Elden Ring not found at: $ER_PATH"
    $ZENITY --error --title "Elden Proton" --text "Could not find Elden Ring installation in $ER_PATH"
    exit 1
fi

# Download required files
log_message "Downloading required files"
download_required_files | $ZENITY --progress --auto-close --percentage=0 --title "Elden Proton" --text "Downloading required files" || true

if [[ ! -f "$tmpdir/integrity.ok" ]]; then
    log_error "Required files failed to download"
    $ZENITY --error --title "Elden Proton" --text "Required files failed to download"
    exit 1
else
    log_message "Required files downloaded successfully"
    rm -f "$tmpdir/integrity.ok"
fi

# Ensure EldenProton directory exists
mkdir -p "$ER_PATH/EldenProton"

# State files
[[ -f "$ER_PATH/EldenProton/state" ]] || printf 1 > "$ER_PATH/EldenProton/state"
[[ -f "$ER_PATH/EldenProton/save_manager.state" ]] || printf 0 > "$ER_PATH/EldenProton/save_manager.state"

while :; do
    log_message "Main menu loop"
    mods_enabled=$(cat "$ER_PATH/EldenProton/state")
    save_manager_enabled=$(cat "$ER_PATH/EldenProton/save_manager.state")

    # Menu options based on state
    if [[ $mods_enabled == 1 ]]; then
        if [[ $save_manager_enabled == 1 ]]; then
            option="$($ZENITY --list --width 700 --height 500 --title "Elden Proton" --text "" --column "Choice" <<'EOC'
Launch Elden Ring
Disable Mods
Choose ModEngine2 mod
Choose DLL mods
Edit Settings
Disable Save Manager
Change Save Path
Reinstall Save Manager
EOC
)"
        else
            option="$($ZENITY --list --width 700 --height 500 --title "Elden Proton" --text "" --column "Choice" <<'EOC'
Launch Elden Ring
Disable Mods
Choose ModEngine2 mod
Choose DLL mods
Edit Settings
Enable Save Manager
EOC
)"
        fi
    else
        if [[ $save_manager_enabled == 1 ]]; then
            option="$($ZENITY --list --width 700 --height 500 --title "Elden Proton" --text "" --column "Choice" <<'EOC'
Launch Elden Ring
Enable Mods
Disable Save Manager
Change Save Path
Reinstall Save Manager
EOC
)"
        else
            option="$($ZENITY --list --width 700 --height 500 --title "Elden Proton" --text "" --column "Choice" <<'EOC'
Launch Elden Ring
Enable Mods
Enable Save Manager
EOC
)"
        fi
    fi

    log_message "User selected: $option"
    case "$option" in
        "Launch Elden Ring")
            log_message "Launching Elden Ring"
            if [[ -d "${STEAM_RUNTIME:-}" ]]; then
                log_message "Restoring LD_LIBRARY_PATH"
                export LD_LIBRARY_PATH="$OLD_LIBRARY_PATH"
            fi

            if [[ $save_manager_enabled == 1 ]]; then
                # Ensure save_manager.bash exists
                if [[ ! -f "$SCRIPT_DIR/save_manager.bash" ]]; then
                    log_message "Downloading save_manager.bash"
                    $CURL -sSL "https://raw.githubusercontent.com/Cloudef/elden-proton/main/save_manager.bash" -o "$SCRIPT_DIR/save_manager.bash"
                    chmod +x "$SCRIPT_DIR/save_manager.bash"
                fi
                log_message "Launching save manager"
                "$SCRIPT_DIR/save_manager.bash" --game-pid=$$ &
            fi

            if [[ $mods_enabled == 1 ]]; then
                log_message "Launching with mods enabled"
                args=("$@")
                set --
                for arg in "${args[@]}"; do
                    set -- "$@" "$(sed 's/start_protected_game.exe/eldenring.exe/' <<<"$arg")"
                done
                mod_path=
				# https://github.com/Cloudef/elden-proton/issues/13
                [[ -f "$ER_PATH/dinput8.dll.disabled" ]] && mv "$ER_PATH/dinput8.dll.disabled" "$ER_PATH/dinput8.dll"
                [[ -f "$ER_PATH/EldenProton/modengine2.modpath" ]] && mod_path="$(cat "$ER_PATH/EldenProton/modengine2.modpath")"
                log_message "Launching game with command: WINEDLLOVERRIDES=\"dinput8.dll=n,b\" MODENGINE_CONFIG=\"$mod_path\"/config_eldenring.toml $*"
                WINEDLLOVERRIDES="dinput8.dll=n,b" MODENGINE_CONFIG="$mod_path"/config_eldenring.toml "$@" &
                game_pid=$!
                log_message "Game started with PID: $game_pid"
            else
				# https://github.com/Cloudef/elden-proton/issues/13
                log_message "Launching without mods"
                [[ -f "$ER_PATH/dinput8.dll" ]] && mv "$ER_PATH/dinput8.dll" "$ER_PATH/dinput8.dll.disabled"
                log_message "Launching game with command: WINEDLLOVERRIDES=\"dinput8.dll=b\" $*"
                WINEDLLOVERRIDES="dinput8.dll=b" "$@" &
                game_pid=$!
                log_message "Game started with PID: $game_pid"
            fi

            wait $game_pid
            game_exit=$?
            log_message "Game exited with code: $game_exit"
            exit $game_exit
            ;;
        "Enable Mods")
            log_message "Enabling mods"
            printf 1 > "$ER_PATH/EldenProton/state"
            ;;
        "Disable Mods")
            log_message "Disabling mods"
            printf 0 > "$ER_PATH/EldenProton/state"
            ;;
        "Choose ModEngine2 mod")
            log_message "Selecting ModEngine2 mod"
            set +e
            dir="$($ZENITY --file-selection --title "Elden Proton" --directory)"
            set -e
            if [[ "x$dir" != x ]]; then
                log_message "User selected directory: $dir"
                if [[ -f "$dir/config_eldenring.toml" ]]; then
                    log_message "Valid ModEngine2 mod detected, setting path"
                    printf '%s' "$dir" > "$ER_PATH/EldenProton/modengine2.modpath"
                else
                    log_error "No config_eldenring.toml found in selected directory"
                    $ZENITY --error --title "Elden Proton" --text "No config_eldenring.toml in the mod directory, is this really a ModEngine2 mod?"
                fi
            else
                log_message "ModEngine2 mod selection cancelled"
            fi
            ;;
        "Choose DLL mods")
            log_message "Selecting DLL mods"
            set +e
            log_message "Displaying DLL mod selection dialog"
            dll_mod_list | $ZENITY --list --width 700 --height 500 --checklist --title "Elden Proton" --text "" --print-column=2 --separator="\n" --column "Enabled" --column "Mod" > "$tmpdir/dllmods.enabled"
            if [[ $? == 0 ]]; then
                log_message "User confirmed DLL mod selection"
                cp -f "$tmpdir/dllmods.enabled" "$ER_PATH/EldenProton/dllmods.enabled"
            else
                log_message "DLL mod selection cancelled"
            fi
            set -e
            log_message "Downloading required DLL mods"
            download_enabled_dll_mods | $ZENITY --progress --auto-close --pulsate --title "Elden Proton" --text "Downloading required files" || true
            if [[ ! -f "$tmpdir/integrity.ok" ]]; then
                log_error "Required files failed to download"
                $ZENITY --error --title "Elden Proton" --text "Required files failed to download"
                exit 1
            else
                log_message "DLL mods downloaded successfully"
                rm -f "$tmpdir/integrity.ok"
            fi
            ;;
        "Edit Settings")
            log_message "Editing settings"
            set +e
            log_message "Displaying config selection dialog"
            config="$(config_list | $ZENITY --list --width 700 --height 500 --title "Elden Proton" --text "" --print-column=ALL --print-column=2 --column "Title" --column "Config")"
            set -e
            if [[ -f "$ER_PATH/$config" ]]; then
                log_message "Opening config file: $ER_PATH/$config"
                if [[ "x${STEAM_EDITOR:-}" != x ]]; then
                    log_message "Using STEAM_EDITOR: $STEAM_EDITOR"
                    $STEAM_EDITOR "$ER_PATH/$config"
                elif ! xdg-open "$ER_PATH/$config"; then
                    log_error "Failed to open config with xdg-open"
                    $ZENITY --error --title "Elden Proton" --text "'xdg-open $ER_PATH/$config' failed, if you do not have xdg-open set STEAM_EDITOR env variable to an graphical editor instead"
                fi
            elif [[ "x$config" != x ]]; then
                log_error "Config file not found: $ER_PATH/$config"
                $ZENITY --error --title "Elden Proton" --text "File $ER_PATH/$config does not exist"
            else
                log_message "Config selection cancelled"
            fi
            ;;
        "Enable Save Manager")
            log_message "Enabling save manager"
            set +e
            save_path="$($ZENITY --file-selection --title "Select Save Path" --directory)"
            set -e
            if [[ "x$save_path" != x ]]; then
                printf '%s' "$save_path" > "$ER_PATH/EldenProton/save_path"
                printf 1 > "$ER_PATH/EldenProton/save_manager.state"
                log_message "Save path set to: $save_path"
                # Download save_manager.bash
                $CURL -sSL "https://raw.githubusercontent.com/Cloudef/elden-proton/main/save_manager.bash" -o "$SCRIPT_DIR/save_manager.bash"
                chmod +x "$SCRIPT_DIR/save_manager.bash"
                log_message "Save manager enabled and script downloaded"
            else
                log_message "Save path selection cancelled"
            fi
            ;;
        "Disable Save Manager")
            log_message "Disabling save manager"
            printf 0 > "$ER_PATH/EldenProton/save_manager.state"
            ;;
        "Change Save Path")
            log_message "Changing save path"
            set +e
            save_path="$($ZENITY --file-selection --title "Select New Save Path" --directory)"
            set -e
            if [[ "x$save_path" != x ]]; then
                printf '%s' "$save_path" > "$ER_PATH/EldenProton/save_path"
                log_message "Save path changed to: $save_path"
            else
                log_message "Save path change cancelled"
            fi
            ;;
        "Reinstall Save Manager")
            log_message "Reinstalling save manager"
            $CURL -sSL "https://raw.githubusercontent.com/Cloudef/elden-proton/refs/heads/master/save_manager.bash" -o "$SCRIPT_DIR/save_manager.bash"
            chmod +x "$SCRIPT_DIR/save_manager.bash"
            log_message "Save manager reinstalled"
            ;;
        *)
            log_message "Main menu cancelled or invalid option selected"
            ;;
    esac
done
