#!/bin/bash

SERVER_IP="194.87.94.159"
TOKEN="SuperSecretToken123"
BASE_URL="http://${SERVER_IP}/share"
FILE_LIST_URL="${BASE_URL}/?token=${TOKEN}"
TOKEN_URL="http://${SERVER_IP}/share/token.php"
SUBMIT_URL="http://${SERVER_IP}/share/submit.php"
BRIGADE_NUMBER="2.6"

FOUND_FLAGS_FILE="found_flags.txt"
FLAGS_AND_FILES_OUTPUT="flags_files.txt"
LOG_FILE="logs/log_$(date '+%Y-%m-%d_%H:%M:%S').log"

log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local color='\033[0;33m'
    local reset='\033[0m'
    local message="${color}[$timestamp]${reset} $*"
    echo -e "$message"
    echo -e "$message" >> "$LOG_FILE"
}

log_file() {
    local text="$1"
    local content="$2"
    local filename="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local message="[$timestamp] $text"
    echo "$message" >> "$FLAGS_AND_FILES_OUTPUT"
    echo "$content" >> "files/${filename}_$(date '+%Y-%m-%d_%H-%M-%S')"
}

get_file_list() {
    curl -s "$FILE_LIST_URL" | grep -o 'href="[^"]*"' | sed 's/href="//;s/"$//' | grep -v '^$'
}

download_file_content() {
    local filename="$1"
    curl -s "${BASE_URL}/${filename}"
}

find_flags() {
    local content="$1"
    echo "$content" | grep -E '.*\{MBKS2.6\}.*'
}

submit_flag() {
    local flag="$1"
    curl -s -X POST "$SUBMIT_URL" \
        -d "brigade=$BRIGADE_NUMBER" \
        -d "flag=$flag" \
        && log "Flag $flag submitted successfully" \
        || log "ERROR: Error while submitting flag $flag"
}

is_flag_found() {
    local flag="$1"
    grep -q "^$flag$" "$FOUND_FLAGS_FILE" 2>/dev/null
}

save_flag() {
    local flag="$1"
    echo "$flag" >> "$FOUND_FLAGS_FILE"
    log "Flag $flag saved"
}

check_flags() {
    local content="$1"
    local filename="$2"
    flags=$(find_flags "$content")
            for flag in $flags; do
                if ! is_flag_found "$flag"; then
                    log "Found new flag: $flag"
                    log_file "flag [$flag] in file [$filename]" "$content" "$filename"
                    save_flag "$flag"
                    submit_flag "$flag"
                else
                    log "WARNING: Flag $flag has already been found earlier"
                fi
            done
}

update_token() {
    TOKEN=$(curl -s "$TOKEN_URL")
    FILE_LIST_URL="http://${SERVER_IP}/share/?token=${TOKEN}"
    log "Token updated successfully: ${TOKEN}"
    return 0
}

log "Start program"

while true; do
    file_list=$(get_file_list)
    if [ -z "$file_list" ]; then
        log "Can't get list of files! Try to update token"
        update_token
        sleep 2
        continue
    fi

    for filename in $file_list; do
        decoded_filename=$(printf '%b' "${filename//%/\\x}")
        log "Checking file '$decoded_filename'"
        content=$(download_file_content "$filename")
        if [ -n "$content" ]; then
#            echo $content >> "$decoded_filename.txt"
            check_flags "$content" "$decoded_filename"
        fi
    done
done    
