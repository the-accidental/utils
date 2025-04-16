import os
import shutil
import osxphotos

# --- CONFIGURATION ---
# Path to your Photos library package. The database is inside the package.
PHOTOS_LIBRARY_PATH = os.path.expanduser("~/Pictures/Photos Library.photoslibrary")
# Path to the directory containing the .MOV files to process.
MOV_FILES_ROOT = os.path.expanduser("/Volumes/X8_wallace_pingu_tm/py_to_import/MOVsToCheck")
# Destination folder to move the matching .MOV files into.
DESTINATION_FOLDER = os.path.expanduser("/Volumes/X8_wallace_pingu_tm/py_to_import/MOVsToCheck/remove)
# ---------------------

# Ensure the destination folder exists
os.makedirs(DESTINATION_FOLDER, exist_ok=True)

print("Opening the macOS Photos library...")
# Path to the Photos sqlite database (inside the Photos Library package)
photos_db_path = os.path.join(PHOTOS_LIBRARY_PATH, "database/Photos.sqlite")
photo_db = osxphotos.PhotosDB(dbfile=photos_db_path)
photos = photo_db.photos()

# Build a set of filename stems from the Photos library
photo_stems = set()
for photo in photos:
    if photo.original_filename:
        stem, _ = os.path.splitext(photo.original_filename)
        photo_stems.add(stem)
print(f"Found {len(photo_stems)} photo filename stems in the library.")

# Counters for logging
moved_count = 0
processed_count = 0

# Process the MOV files directory recursively
for root, dirs, files in os.walk(MOV_FILES_ROOT):
    for file in files:
        # Process only .mov files (case-insensitive)
        if file.lower().endswith(".mov"):
            processed_count += 1
            mov_path = os.path.join(root, file)
            mov_stem, mov_ext = os.path.splitext(file)
            
            # Check if the MOV's stem is found in the photo stems.
            if mov_stem in photo_stems:
                dest_path = os.path.join(DESTINATION_FOLDER, file)
                # Handle potential name collisions in the destination folder.
                if os.path.exists(dest_path):
                    base, ext = os.path.splitext(file)
                    counter = 1
                    while os.path.exists(dest_path):
                        dest_path = os.path.join(DESTINATION_FOLDER, f"{base}_{counter}{ext}")
                        counter += 1
                try:
                    shutil.move(mov_path, dest_path)
                    moved_count += 1
                    print(f"Moved: {mov_path} -> {dest_path}")
                except Exception as e:
                    print(f"Error moving {mov_path}: {e}")

print(f"Processed {processed_count} .MOV files; moved {moved_count} files that matched library photo stems.")

