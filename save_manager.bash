#!/usr/bin/env bash

# Save Manager for Elden Ring
# Manages save files with a user-friendly interface

# Paths
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
BACKUP_PATH="$SCRIPT_DIR/er_saves"
STEAM_PATH="${STEAM_PATH:-"$HOME"/.steam/steam}"
ER_PATH="${ER_PATH:-$STEAM_PATH/steamapps/common/ELDEN RING/Game}"
SAVE_PATH_FILE="$ER_PATH/EldenProton/save_path"
LOG_FILE="$SCRIPT_DIR/elden-proton.log"
ZENITY=${STEAM_ZENITY:-zenity}

# Log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SaveManager] $1" >> "$LOG_FILE"
}

log_message "Starting save manager"

# Steam runtime handling
if [[ -d "${STEAM_RUNTIME:-}" ]]; then
    log_message "Steam runtime detected"
    OLD_LIBRARY_PATH="$LD_LIBRARY_PATH"
    export LD_LIBRARY_PATH=
    if [[ ! "${STEAM_ZENITY:-}" ]] || [[ "${STEAM_ZENITY:-}" == zenity ]]; then
        if [[ "${SYSTEM_PATH:-}" ]]; then
            ZENITY="${SYSTEM_ZENITY:-$(PATH="$SYSTEM_PATH" which zenity)}"
        else
            ZENITY="${SYSTEM_ZENITY:-/usr/bin/zenity}"
        fi
    fi
    log_message "Using zenity: $ZENITY"
fi

# Check SAVE_PATH
if [[ ! -f "$SAVE_PATH_FILE" ]]; then
    log_message "Error: $SAVE_PATH_FILE does not exist"
    $ZENITY --error --title "Save Manager" --text "Save path file not found. Please set it in Elden Proton."
    exit 1
fi
SAVE_PATH=$(cat "$SAVE_PATH_FILE")
if [[ -z "$SAVE_PATH" ]]; then
    log_message "Error: SAVE_PATH is empty"
    $ZENITY --error --title "Save Manager" --text "Save path is empty. Please set it in Elden Proton."
    exit 1
fi
log_message "Save path set to: $SAVE_PATH"

# Ensure backup directory exists
if ! mkdir -p "$BACKUP_PATH"; then
    log_message "Error: Failed to create backup directory $BACKUP_PATH"
    $ZENITY --error --title "Save Manager" --text "Failed to create backup directory $BACKUP_PATH."
    exit 1
fi
log_message "Backup directory ensured: $BACKUP_PATH"

# Array to hold backup files and their timestamps
declare -a save_files
declare -a timestamps

# Function to format timestamp for display
format_datetime() {
    local timestamp=$1
    date -d "@$timestamp" "+%Y-%m-%d %H:%M:%S.%3N"
}

# Function to load save files sorted by creation time
load_save_files() {
    save_files=()
    timestamps=()
    log_message "Loading save files"
    
    # remove .sl2 from the filename before putting it to the array
    while IFS=$'\t' read -r timestamp file; do
        save_files+=("$(basename "$file" .sl2)")
        # Format the timestamp to human-readable format
        formatted_time=$(format_datetime "$timestamp")
        timestamps+=("$formatted_time")
    done < <(find "$BACKUP_PATH" -name "*.sl2" -printf "%T@\t%p\n" | sort -r -n)
    
    log_message "Save files loaded: ${#save_files[@]} files"
}

# Function to create a new save file
backup_save_file() {
    timestamp=$(date +"%Y%m%d%H%M%S%3N")
    save_file_name="quicksave_${timestamp}.sl2"
    save_file="$BACKUP_PATH/$save_file_name"
    log_message "Creating save file: \`$save_file\`"
    if cp "$SAVE_PATH/ER0000.sl2" "$save_file"; then
        log_message "Save file created: \`$save_file\`"
        # return the save file name to caller
        echo "$save_file_name"
    else
        log_message "Failed to backup save file"
        $ZENITY --error --title "Save Manager" --text "Failed to backup save file."
    fi
}

# Function to rename a save file
rename_save_file() {
    selected="$1"
    new_name="$($ZENITY --entry --title "Rename Save File" --text "Enter new name for\n\`$selected\`" --entry-text="")"
    # return if Cancel was clicked
    if [[ $? -ne 0 ]]; then
        return
    fi

    # Check or add .sl2 to the new name if not empty
    if [[ -n "$new_name" && "$new_name" != *.sl2 ]]; then
        new_name="${new_name}.sl2"
    fi
    
    log_message "Renaming save file: \`$selected\` to \`$new_name\`"
    if [[ -n "$new_name" ]]; then
        if [[ -f "$BACKUP_PATH/$new_name" && "$new_name" != "$selected" ]]; then
            log_message "Error: File \`$new_name\` already exists"
            $ZENITY --error --title "Save Manager" --text "File with name \`$new_name\` already exists. Please choose a different name."
            return
        fi
        
        if mv "$BACKUP_PATH/$selected" "$BACKUP_PATH/$new_name"; then
            log_message "Save file renamed to: \`$new_name\`"
            # return new_name to caller
            echo "$new_name"
        else
            log_message "Failed to rename save file"
            $ZENITY --error --title "Save Manager" --text "Failed to rename save file."
        fi
    fi
}

# Function to restore a save file
restore_save_file() {
    # Backup the current save with "load" prefix
    timestamp=$(date +"%Y%m%d%H%M%S%3N")
    backup_file="$BACKUP_PATH/load_${timestamp}.sl2"
    log_message "Backing up current save: \`$backup_file\`"
    if ! cp "$SAVE_PATH/ER0000.sl2" "$backup_file"; then
        log_message "Failed to backup current save"
        $ZENITY --error --title "Save Manager" --text "Failed to backup current save before restoring."
        return
    fi
    log_message "Current save backed up: \`$backup_file\`"

    selected="$1"
    log_message "Restoring save file: \`$selected\`"
    if cp "$BACKUP_PATH/$selected" "$SAVE_PATH/ER0000.sl2"; then
        log_message "Save file restored: \`$selected\`"
    else
        log_message "Failed to restore save file"
        $ZENITY --error --title "Save Manager" --text "Failed to restore save file."
    fi
}

# Function to delete a save file
delete_save_file() {
    selected="$1"
    log_message "Deleting save file: \`$selected\`"
    if rm "$BACKUP_PATH/$selected"; then
        log_message "Save file deleted: \`$selected\`"
        return 0
    else
        log_message "Failed to delete save file"
        $ZENITY --error --title "Save Manager" --text "Failed to delete save file."
        return 1
    fi
}

# Main loop for the save manager interface
load_save_files
selected_save_file=""
last_action_description=""

while true; do
    # Prepare header text
    header_text="<b>Save Manager for Elden Ring</b>"
    if [[ -n "$selected_save_file" ]]; then
        header_text="$header_text\n<b>Selected file:</b> $selected_save_file"
    else
        header_text="$header_text\n<i>Select a save file from the list for further actions</i>"
    fi

    if [[ -n "$last_action_description" ]]; then
        header_text="$header_text\n<i>$last_action_description</i>"
    fi

    # Prepare data for the list
    list_data=()
    for i in "${!save_files[@]}"; do
        # Mark the selected save file with an indicator
        if [[ "${save_files[$i]}.sl2" == "$selected_save_file" ]]; then
            list_data+=("> ${save_files[$i]}" "${timestamps[$i]}")
        else
            list_data+=("    ${save_files[$i]}" "${timestamps[$i]}")
        fi
    done
    log_message "Ready to show ${#save_files[@]} save files"

    action=""
    if [[ -n "$selected_save_file" ]]; then
        # Show dialog with 2 columns and extra buttons
        action=$($ZENITY --list --title "Save Manager" --text="$header_text" \
            --column="Backup File Name" --column="Create Date" "${list_data[@]}" \
            --width 700 --height 500 \
            --print-column=1 \
            --cancel-label "Exit" \
            --ok-label "Select" \
            --extra-button "Refresh" \
            --extra-button "Rename" \
            --extra-button "Load" \
            --extra-button "Delete" \
            --extra-button "Quicksave")
    else
        # Show dialog with 2 columns but fewer buttons if nothing is selected
        action=$($ZENITY --list --title "Save Manager" --text="$header_text" \
            --column="Backup File Name" --column="Create Date" "${list_data[@]}" \
            --width 700 --height 500 \
            --print-column=1 \
            --cancel-label "Exit" \
            --ok-label "Select" \
            --extra-button "Refresh" \
            --extra-button "Quicksave")
    fi
    
    # Get the exit status to determine if a save file was selected or a button was clicked
    status=$?
    
    # If exit status is 0, a save file was selected from the list
    if [[ $status -eq 0 && -n "$action" ]]; then
        # Remove the arrow indicator if present
        selected_save_file="${action#> }"
        selected_save_file="${selected_save_file#    }"
        # check if the selected save present in the list
        if [[ ! " ${save_files[@]} " =~ " ${selected_save_file} " ]]; then
            log_message "Invalid save file: \`$selected_save_file\`"
            selected_save_file=""
            last_action_description="Invalid save file: \`$selected_save_file\`"
        else
            # add .sl2 to the selected save file
            selected_save_file="${selected_save_file}.sl2"
            log_message "Save file selected: \`$selected_save_file\`"
        fi
    fi
    
    log_message "Action: \`$action\`, Status: \`$status\`, Selected save file: \`$selected_save_file\`"
    
    case "$action" in
        "Quicksave")
            save_file=$(backup_save_file)
            if [[ -n "$save_file" ]]; then
                last_action_description="Quicksave created: \`$save_file\`"
                selected_save_file="$save_file"
                load_save_files
            else
                last_action_description="Failed to create quicksave"
            fi
            ;;
        "Delete")
            if [[ -n "$selected_save_file" ]]; then
                if $ZENITY --question --title "Save Manager" --text "Are you sure you want to delete save file: \`$selected_save_file\`?"; then
                    if delete_save_file "$selected_save_file"; then
                        last_action_description="Save file \`$selected_save_file\` deleted"
                        selected_save_file=""
                        load_save_files
                    else
                        last_action_description="Failed to delete save file \`$selected_save_file\`"
                    fi
                fi
            else
                $ZENITY --error --title "Save Manager" --text "Please select a save file to delete"
                last_action_description=""
            fi
            ;;
        "Rename")
            if [[ -n "$selected_save_file" ]]; then
                new_name=$(rename_save_file "$selected_save_file")
                if [[ -n "$new_name" ]]; then
                    last_action_description="Save renamed: \`$selected_save_file\` -> \`$new_name\`"
                    selected_save_file="$new_name"
                else
                    last_action_description="Failed to rename save"
                fi
                load_save_files
            else
                $ZENITY --error --title "Save Manager" --text "Please select a save file to rename"
                last_action_description=""
            fi
            ;;
        "Refresh")
            load_save_files
            last_action_description="Reloaded ${#save_files[@]} save files"
            ;;
        "Load")
            if [[ -n "$selected_save_file" ]]; then
                restore_save_file "$selected_save_file"
                load_save_files
                last_action_description="Save loaded: \`$selected_save_file\`"
            else
                $ZENITY --error --title "Save Manager" --text "Please select a save file to load"
                last_action_description=""
            fi
            ;;
        "Exit")
            # Request confirmation
            if $ZENITY --question --title "Save Manager" --text "Are you sure you want to exit the save manager?"; then
                log_message "Exiting save manager"
                exit 0
            fi
            ;;
        *)
            # If no action was taken and we have a non-zero status, user closed the dialog
            if [[ $status -ne 0 && -z "$action" ]]; then
                # Request confirmation
                if $ZENITY --question --title "Save Manager" --text "Are you sure you want to exit the save manager?"; then
                    log_message "Exiting save manager"
                    exit 0
                fi
            fi
            ;;
    esac
done