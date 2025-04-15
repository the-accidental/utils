#!/bin/bash
# organize_media_parallel.sh
# This script recursively processes photos and videos from a source folder,
# organizing them into year/month/day subfolders at a destination based on metadata.
# Processing for each file is done in parallel using xargs.
#
# Usage:
#   ./organize_media_parallel.sh [--dry-run] <source_folder> <destination_folder>
#
# Options:
#   --dry-run   Echo move commands without performing actual file moves.
#
# Files that cannot be moved (e.g. due to naming collisions) are logged to errors.log.
# Files where no metadata date is found and the file’s creation date is used are logged to nodates.log.

# Function to show script usage
usage() {
    echo "Usage: $0 [--dry-run] <source_folder> <destination_folder>"
    exit 1
}

# Parse dry-run option if provided
DRY_RUN=false
if [ "$1" == "--dry-run" ]; then
    DRY_RUN=true
    shift
fi

# Ensure exactly two arguments remain
if [ "$#" -ne 2 ]; then
    usage
fi

SRC="$1"
DEST="$2"
ERROR_LOG="errors.log"
NODATES_LOG="nodates.log"

# Initialize error log and nodates log
echo "Log for errors encountered on $(date)" > "$ERROR_LOG"
echo "Log for files that used creation date (no metadata) on $(date)" > "$NODATES_LOG"

# Determine the number of processors (cores) for parallel execution
NUM_PROCS=$(sysctl -n hw.ncpu 2>/dev/null)
if [ -z "$NUM_PROCS" ]; then
    NUM_PROCS=4   # Fallback value if hw.ncpu is unavailable
fi

# Define the function to process one file.
process_file() {
    local file="$1"

    # First try to extract the capture date from exif metadata.
    capture_date=$(exiftool -DateTimeOriginal -d "%Y/%m/%d" "$file" | awk -F': ' '{print $2}' | head -n1)
    if [ -z "$capture_date" ]; then
        capture_date=$(exiftool -CreateDate -d "%Y/%m/%d" "$file" | awk -F': ' '{print $2}' | head -n1)
    fi

    # If no exif date is available, use the file creation date.
    if [ -z "$capture_date" ]; then
        # Using macOS stat command to get file creation date formatted as YYYY/MM/DD.
        # %SB with a format (-t) is used for the birth time.
        capture_date=$(stat -f "%SB" -t "%Y/%m/%d" "$file")
        # Log to nodates.log that we're using the file creation date.
        echo "Using creation date for file: $file (date: $capture_date)" >> "$NODATES_LOG"
    fi

    # If still no date, log the error and skip processing this file.
    if [ -z "$capture_date" ]; then
        echo "ERROR: No capture date or creation date found for: $file" >> "$ERROR_LOG"
        return
    fi

    # Build the destination directory and full target path.
    target_dir="$DEST/$capture_date"
    target_file="$target_dir/$(basename "$file")"

    # Create the destination directory if it doesn't exist.
    mkdir -p "$target_dir"

    # Skip the file if a file with the same name already exists.
    if [ -e "$target_file" ]; then
        echo "ERROR: File exists at destination: $target_file. Skipping file: $file" >> "$ERROR_LOG"
        return
    fi

    # Execute move command or output the command if dry-run mode is enabled.
    if [ "$DRY_RUN" = true ]; then
        echo "DRY RUN: mv \"$file\" \"$target_file\""
    else
        mv "$file" "$target_file"
        if [ $? -ne 0 ]; then
            echo "ERROR: Failed to move $file to $target_file" >> "$ERROR_LOG"
        fi
    fi
}

# Export necessary variables and function for access by subshells.
export -f process_file
export DRY_RUN
export DEST
export ERROR_LOG
export NODATES_LOG

# Find all files recursively in the source folder and process them in parallel.
# The -print0 and -0 options handle filenames that include spaces.
find "$SRC" -type f -print0 | xargs -0 -n 1 -P "$NUM_PROCS" bash -c 'process_file "$0"' 

echo "Operation completed. Check $ERROR_LOG for errors and $NODATES_LOG for files with no metadata date."

