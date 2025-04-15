import os
import shutil
import osxphotos

# === CONFIGURATION ===
PHOTOS_LIBRARY_PATH = os.path.expanduser("~/Pictures/Photos Library.photoslibrary")
PHOTOS_FOLDERS_ROOT = os.path.expanduser("/Volumes/Wallace/photos/iain/masters")  # Root folder of year/month/day structure
DESTINATION_FOLDER = os.path.expanduser("/Volumes/X8_wallace_pingu_tm/py_to_import")
# =======================

# Create the destination folder if it doesn't exist
os.makedirs(DESTINATION_FOLDER, exist_ok=True)

print("Querying the macOS Photos library...")
# Open the Photos library. (The Photos database is inside the Photos Library package.)
photos_db_path = os.path.join(PHOTOS_LIBRARY_PATH, "database/Photos.sqlite")
photo_db = osxphotos.PhotosDB(dbfile=photos_db_path)
library_photos = photo_db.photos()

# Build a set of keys (filename, day) for photos already in the library.
library_keys = set()
for photo in library_photos:
    # Ensure we have both a date and an original filename.
    if photo.date and photo.original_filename:
        # Format the date as YYYY-MM-DD (ensuring two-digit month and day)
        day_str = f"{photo.date.year}-{photo.date.month:02d}-{photo.date.day:02d}"
        key = (photo.original_filename, day_str)
        library_keys.add(key)
print(f"Found {len(library_keys)} photo keys in the library.")

# Function to attempt to extract a day string (YYYY-MM-DD) from the folder structure.
def extract_day_from_path(root, base_root):
    """Given a directory path and the base root of the organized photos,
    try to extract a date formatted as 'YYYY-MM-DD'. Assumes folder structure:
    base_root / year / month / day."""
    rel_path = os.path.relpath(root, base_root)
    parts = rel_path.split(os.sep)
    if len(parts) >= 3:
        try:
            year = int(parts[0])
            month = int(parts[1])
            day = int(parts[2])
            return f"{year}-{month:02d}-{day:02d}"
        except ValueError:
            return None
    return None

photos_copied = 0
print("Scanning your organized folders for missing photos...")

# Walk through your organized photos folders.
for root, dirs, files in os.walk(PHOTOS_FOLDERS_ROOT):
    # Try to extract a day string from the current directory
    day_str = extract_day_from_path(root, PHOTOS_FOLDERS_ROOT)
    # If we can't derive a day, then this folder isn't at the expected level.
    if not day_str:
        #make a new key for this, which will never be in photos (so we'll err on selecting dupes)
        day_str = f"9999-{os.path.dirname(root)[-1]}"
        print(f"Created new key base: {day_str} for root: {root}")
    
    for file in files:
        # Build the key as (filename, day_str)
        key = (file, day_str)
        # If this key is not found in the library keys, copy the file.
        if key not in library_keys:
            source_path = os.path.join(root, file)
            dest_path = os.path.join(DESTINATION_FOLDER, file)
            # Handle potential filename collisions in the destination folder
            if os.path.exists(dest_path):
                base, ext = os.path.splitext(file)
                counter = 1
                while os.path.exists(dest_path):
                    dest_path = os.path.join(DESTINATION_FOLDER, f"{counter}",file)
                    os.makedirs(os.path.join(DESTINATION_FOLDER, f"{counter}"), exist_ok=True)
                    counter += 1

            try:
                shutil.copy2(source_path, dest_path)
                photos_copied += 1
            except Exception as e:
                print(f"Error copying {source_path}: {e}")

print(f"Copied {photos_copied} missing photos to {DESTINATION_FOLDER}.")

