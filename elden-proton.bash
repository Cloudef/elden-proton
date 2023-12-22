#!/usr/bin/env bash
## Noob friendly elden ring mod loader for linux/proton/steam
## If you execute the script without args it will print the launch options you should set for Elden Ring in steam
## If you want to install additional dll mods that aren't included in this script, you can do so by installing them
## in the game directory's mods folder, this script won't manage any dll mods it isn't aware of

set -euo pipefail

STEAM_PATH="${STEAM_PATH:-"$HOME"/.steam/steam}"
ER_PATH="${ER_PATH:-$STEAM_PATH/steamapps/common/ELDEN RING/Game}"
ZENITY=${STEAM_ZENITY:-zenity}
UNZIP=${STEAM_UNZIP:-unzip}
CURL=${STEAM_CURL:-curl}
SHA256SUM=${STEAM_SHA256SUM:-sha256sum}

if [[ -d "$STEAM_RUNTIME" ]]; then
	# https://github.com/Cloudef/elden-proton/issues/4
	OLD_LIBRARY_PATH="$LD_LIBRARY_PATH"
	export LD_LIBRARY_PATH=
	# https://github.com/Cloudef/elden-proton/issues/6
	if [[ ! "$STEAM_ZENITY" ]] || [[ "$STEAM_ZENITY" == zenity ]]; then
		if [[ "$SYSTEM_PATH" ]]; then
			ZENITY="${SYSTEM_ZENITY:-$(PATH="$SYSTEM_PATH" which zenity)}"
		else
			# last fallback
			ZENITY="${SYSTEM_ZENITY:-/usr/bin/zenity}"
		fi
	fi
fi

if [[ "x$@" == "x" ]]; then
	if test -t 0; then
		printf "%s\n" "bash \"$(realpath "$0")\" %command%"
	else
		$ZENITY --info --title "Elden Proton" --text "$(realpath "$0") %command%"
	fi
	exit 0
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

elden_mod_loader_url="https://github.com/techiew/EldenRingModLoader/releases/download/Binary/EldenModLoader.zip"
elden_mod_loader_sha256="41d90de7506474689fd711ac421897642a3f5ff0391c313773263a43a83af66d"

mod_engine_proton_url="https://github.com/Cloudef/ModEngine2/releases/download/2.0.0.1-proton-v4/ModEngine-2.0.0.1-win64.zip"
mod_engine_proton_sha256="2080639cd1186952a3c66875bb52454ecd33ea28675c45811e3d82c2d031c8f3"

read -r -d '' elden_mod_loader_mods <<'EOV' || true
Seamless Co-op
mods/elden_ring_seamless_coop.dll
mods/seamlesscoopsettings.ini
https://github.com/LukeYui/EldenRingSeamlessCoopRelease/releases/download/v.1.5.1/betarealeasecoop1.5.1.zip
657a0fa3229b103f7d995e0cefae106582acf0a45bf8b11065769ab5e2899114
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

download_and_verify() {
	local fpath="$tmpdir/$(basename "$1")"
	if ! $CURL -sSL "$1" -o "$fpath"; then
		$ZENITY --error --title "Elden Proton" --text "Executing curl failed... Do you have curl installed?"
		exit 1
	fi
	local sum=($($SHA256SUM "$fpath"))
	if [[ $? != 0 ]]; then
		$ZENITY --error --title "Elden Proton" --text "Executing sha256sum failed... Do you have sha256sum installed?"
		exit 1
	fi
	if [[ "$sum" != "$2" ]]; then
		$ZENITY --error --title "Elden Proton" --text "Integrity check failed\n$1\ngot: $sum\nexpected: $2"
		exit 1
	fi
	mkdir -p "$ER_PATH"/EldenProton
	printf '%s' "$2" > "$ER_PATH"/EldenProton/"$3.sha256"
}

verify_local_resource() {
	if [[ -f "$ER_PATH"/EldenProton/"$1.sha256" ]] && [[ "$(cat "$ER_PATH"/EldenProton/"$1.sha256")" == "$2" ]]; then
		return 0
	else
		return 1
	fi
}

download_dll_mod() {
	if verify_local_resource "$3" "$2"; then
		return 0
	fi

	local fpath="$tmpdir/$(basename "$1")"
	download_and_verify "$1" "$2" "$3"

	if [[ "$3" == "Seamless Co-op" ]]; then
		(cd "$ER_PATH" && $UNZIP -qq -o "$fpath")
		rm -f "$ER_PATH"/launch_elden_ring_seamlesscoop.exe "$ER_PATH"/mods/elden_ring_seamless_coop.dll "$ER_PATH"/mods/seamlesscoopsettings.ini
		mv "$ER_PATH"/SeamlessCoop/elden_ring_seamless_coop.dll "$ER_PATH"/mods/
		mv "$ER_PATH"/SeamlessCoop/seamlesscoopsettings.ini "$ER_PATH"/mods/
	else
		(cd "$ER_PATH" && $UNZIP -qq -o "$fpath")
	fi
}

dll_mod_list() {
	while {
		read -r name
		read -r dll
		read -r config
		read -r url
		read -r sha256
	}; do
		if grep -Fx "$name" "$ER_PATH"/EldenProton/dllmods.enabled > /dev/null; then
			printf '%s\n%s\n' "TRUE" "$name"
		else
			printf '%s\n%s\n' "FALSE" "$name"
		fi
	done <<<"$elden_mod_loader_mods"
}

config_list() {
	printf '%s\n%s\n' "Elden Mod Loader" "mod_loader_config.ini"
	while {
		read -r name
		read -r dll
		read -r config
		read -r url
		read -r sha256
	}; do
		if [[ "x$config" != x ]] && grep -Fx "$name" "$ER_PATH"/EldenProton/dllmods.enabled > /dev/null; then
			printf '%s\n%s\n' "$name" "$config"
		fi
	done <<<"$elden_mod_loader_mods"
}

download_enabled_dll_mods() {
	while {
		read -r name
		read -r dll
		read -r config
		read -r url
		read -r sha256
	}; do
		if grep -Fx "$name" "$ER_PATH"/EldenProton/dllmods.enabled > /dev/null; then
			[[ -f "$ER_PATH/$dll.disabled" ]] && mv "$ER_PATH/$dll"
			download_dll_mod "$url" "$sha256" "$name"
		elif [[ -f "$ER_PATH/$dll" ]]; then
			mv "$ER_PATH/$dll" "$ER_PATH/$dll.disabled"
		fi
	done <<<"$elden_mod_loader_mods"
	touch "$tmpdir"/integrity.ok
}

download_required_files() {
	echo "10"
	if ! verify_local_resource elden_mod_loader "$elden_mod_loader_sha256"; then
		download_and_verify "$elden_mod_loader_url" "$elden_mod_loader_sha256" elden_mod_loader
		(cd "$ER_PATH" && $UNZIP -qq -o "$tmpdir"/EldenModLoader.zip)
		sed -i 's/load_delay = 5000/load_delay = 2000/' "$ER_PATH"/mod_loader_config.ini
	fi
	echo "45"
	if ! verify_local_resource mod_engine_proton "$mod_engine_proton_sha256"; then
		download_and_verify "$mod_engine_proton_url" "$mod_engine_proton_sha256" mod_engine_proton
		(cd "$ER_PATH"/mods && $UNZIP -qq -jo "$tmpdir"/ModEngine-2.0.0.1-win64.zip "ModEngine-2.0.0.1-win64/modengine2/bin/*")
	fi
	echo "100"
	touch "$tmpdir"/integrity.ok
}

if [[ ! -f "$ER_PATH"/eldenring.exe ]]; then
	$ZENITY --error --title "Elden Proton" --text "Could not find Elden Ring installation in $ER_PATH"
	exit 1
fi

download_required_files | $ZENITY --progress --auto-close --percentage=0 --title "Elden Proton" --text "Downloading required files" || true

if [[ ! -f "$tmpdir"/integrity.ok ]]; then
	$ZENITY --error --title "Elden Proton" --text "Required files failed to download"
	exit 1
else
	rm -f "$tmpdir"/integrity.ok
fi

mkdir -p "$ER_PATH"/EldenProton
[[ -f "$ER_PATH"/EldenProton/state ]] || printf 1 > "$ER_PATH"/EldenProton/state
while :; do
	mods_enabled=$(cat "$ER_PATH"/EldenProton/state)
	if [[ $mods_enabled == 1 ]]; then
		option="$($ZENITY --list --title "Elden Proton" --text "" --column "Choice" <<'EOC'
Launch Elden Ring
Disable Mods
Choose ModEngine2 mod
Choose DLL mods
Edit Settings
EOC
)"
	else
		option="$($ZENITY --list --title "Elden Proton" --text "" --column "Choice" <<'EOC'
Launch Elden Ring
Enable Mods
EOC
)"
	fi
	case "$option" in
		"Launch Elden Ring")
			if [[ -d "$STEAM_RUNTIME" ]]; then
				export LD_LIBRARY_PATH="$OLD_LIBRARY_PATH"
			fi
			if [[ $mods_enabled == 1 ]]; then
				args=("$@")
				set --
				for arg in "${args[@]}"; do
					set -- "$@" "$(sed 's/start_protected_game.exe/eldenring.exe/' <<<"$arg")"
				done
				mod_path=
				[[ -f "$ER_PATH"/EldenProton/modengine2.modpath ]] && mod_path="$(cat "$ER_PATH"/EldenProton/modengine2.modpath)"
				WINEDLLOVERRIDES="dinput8.dll=n,b" MODENGINE_CONFIG="$mod_path"/config_eldenring.toml "$@"
				exit $?
			else
				WINEDLLOVERRIDES="dinput8.dll=b" "$@"
				exit $?
			fi
			;;
		"Enable Mods")
			printf 1 > "$ER_PATH"/EldenProton/state
			;;
		"Disable Mods")
			printf 0 > "$ER_PATH"/EldenProton/state
			;;
		"Choose ModEngine2 mod")
			set +e
			dir="$($ZENITY --file-selection --title "Elden Proton" --directory)"
			set -e
			if [[ "x$dir" != x ]]; then
				if [[ -f "$dir"/config_eldenring.toml ]]; then
					printf '%s' "$dir" > "$ER_PATH"/EldenProton/modengine2.modpath
				else
					$ZENITY --error --title "Elden Proton" --text "No config_eldenring.toml in the mod directory, is this really an ModEngine2 mod?"
				fi
			fi
			;;
		"Choose DLL mods")
			set +e
			dll_mod_list | $ZENITY --list --checklist --title "Elden Proton" --text "" --print-column=2 --separator="\n" --column "Enabled" --column "Mod" > "$tmpdir"/dllmods.enabled
			[[ $? == 0 ]] && cp -f "$tmpdir"/dllmods.enabled "$ER_PATH"/EldenProton/dllmods.enabled
			set -e
			download_enabled_dll_mods | $ZENITY --progress --auto-close --pulsate --title "Elden Proton" --text "Downloading required files" || true
			if [[ ! -f "$tmpdir"/integrity.ok ]]; then
				$ZENITY --error --title "Elden Proton" --text "Required files failed to download"
				exit 1
			else
				rm -f "$tmpdir"/integrity.ok
			fi
			;;
		"Edit Settings")
			set +e
			config="$(config_list | $ZENITY --list --title "Elden Proton" --text "" --print-column=ALL --print-column=2 --column "Title" --column "Config")"
			set -e
			if [[ -f "$ER_PATH/$config" ]]; then
				if [[ "x${STEAM_EDITOR:-}" != x ]]; then
					$STEAM_EDITOR "$ER_PATH/$config"
				elif ! xdg-open "$ER_PATH/$config"; then
					$ZENITY --error --title "Elden Proton" --text "'xdg-open $ER_PATH/$config' failed, if you do not have xdg-open set STEAM_EDITOR env variable to an graphical editor instead"
				fi
			elif [[ "x$config" != x ]]; then
				$ZENITY --error --title "Elden Proton" --text "File $ER_PATH/$config does not exist"
			fi
			;;
	esac
done
