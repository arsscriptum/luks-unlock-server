#!/bin/bash

# ┌────────────────────────────────────────────────────────────────────────────────┐
# │                                                                                │
# │   decrypt_fs.sh                                                                │
# │   decrypt the root fs, using the last version of the unlock-cryptroot file     │
# │                                                                                │
# ┼────────────────────────────────────────────────────────────────────────────────┼
# │   Guillaume Plante  <guillaumeplante.qc@gmail.com>                             │
# └────────────────────────────────────────────────────────────────────────────────┘


# Colors for output
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# handy logging and error handling functions
pecho() { printf %s\\n "$*"; }
log() { pecho "$@"; }
debug() { : log "DEBUG: $@" >&2; }
error() { log "ERROR: $@" >&2; }
fatal() { error "$@"; exit 1; }
try() { "$@" || fatal "'$@' failed"; }
usage_fatal() { usage >&2; pecho "" >&2; fatal "$@"; }

# quote special characters so that:
#    eval "set -- $(shell_quote "$@")"
# is always a no-op no matter what values are in the positional
# parameters.  note that it is run in a subshell to protect the
# caller's environment.
shell_quote() (
    sep=
    for i in "$@"; do
        iesc=$(pecho "${i}eoi" | sed -e "s/'/'\\\\''/g")
        iesc=\'${iesc%eoi}\'
        printf %s "${sep}${iesc}"
        sep=" "
    done
)

# Verbose output function
log_info() {
    echo -e "${CYAN}[INFO] $1${NC}"
    logger "[INFO] $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
    logger "[WARNING] $1"
}

# Local variables
remote_url="https://raw.githubusercontent.com/rhansen/unlock-cryptroot/master/unlock-cryptroot"
file_hash="8ae9cbff6cc0928b2338a74ee4797465"
local_path="/srv/scripts/unlock-cryptroot"

# Check if the user has root privileges
if [[ $EUID -ne 0 ]]; then
    log_warning "This script must be run as root. Exiting."
    exit 1
fi

# Parse command-line arguments for '-f' or '--force'
force_download=false
for arg in "$@"; do
    if [[ "$arg" == "-f" || "$arg" == "--force" ]]; then
        force_download=true
    fi
done

# Function to verify the file hash
verify_hash() {
    log_info "Verifying the file hash..."
    downloaded_file_hash=$(md5sum "$local_path" | awk '{ print $1 }')

    if [[ "$downloaded_file_hash" != "$file_hash" ]]; then
        log_warning "File hash verification failed. Expected $file_hash but got $downloaded_file_hash."
        return 1
    else
        log_info "File hash verification succeeded."
        return 0
    fi
}

# Download the file if it doesn't exist or if force download is enabled
if [[ ! -f "$local_path" || "$force_download" == true ]]; then
    log_info "Downloading the file from $remote_url..."
    curl -s -o "$local_path" "$remote_url"

    if [[ $? -ne 0 ]]; then
        log_warning "Failed to download the file from $remote_url."
        exit 1
    fi

    log_info "File downloaded to $local_path."

    # Verify the file hash after download
    if ! verify_hash; then
        log_warning "Downloaded file hash verification failed. Exiting."
        exit 1
    fi
else
    log_info "File already exists at $local_path."

    # Verify the existing file's hash
    if ! verify_hash; then
        log_warning "Existing file hash verification failed. Exiting."
        exit 1
    fi
fi

# Make the file executable
log_info "Setting the file as executable..."
chmod +x "$local_path"

if [[ $? -ne 0 ]]; then
    log_warning "Failed to set $local_path as executable."
    exit 1
fi

log_info "Executing the script with arguments: $@"
# Execute the downloaded file and pass all arguments to it
# "$local_path" "$@"

if [[ $? -ne 0 ]]; then
    log_warning "Execution of $local_path failed."
    exit 1
else
    log_info "Script executed successfully."
fi
