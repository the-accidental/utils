#!/bin/zsh

# Ensure both input and output arguments are provided
if [[ -z "$1" ]] || [[ -z "$2" ]]; then
    echo "Usage: $0 /path/to/input_folder /path/to/output_folder"
    exit 1
fi

INPUT_DIR="${1%/}"
OUTPUT_DIR="${2%/}"

# Dependency Check
dependencies=(exiftool magick ffmpeg)
for cmd in $dependencies; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: Required dependency '$cmd' is not installed or not in your PATH."
        exit 1
    fi
done

# Ensure input directory exists
if [[ ! -d "$INPUT_DIR" ]]; then
    echo "Error: Input directory '$INPUT_DIR' does not exist."
    exit 1
fi

# Enable case-insensitive globbing locally for this script
setopt local_options nocaseglob

echo "Scanning recursively: $INPUT_DIR..."
echo "Syncing structural output to: $OUTPUT_DIR..."
echo "------------------------------------------------"

# Step 1: Process all Images (JPG, JPEG, HEIC, PNG)
for img_in_path in "$INPUT_DIR"/**/*.(jpg|jpeg|heic|png)(N); do
    
    # Determine relative paths and structures
    relative_path="${img_in_path#$INPUT_DIR/}"
    relative_dir=$(dirname "$relative_path")
    filename=$(basename "$relative_path")
    extension="${filename##*.}"
    filename_no_ext="${filename%.*}"
    
    dest_dir="$OUTPUT_DIR/$relative_dir"
    mkdir -p "$dest_dir"
    
    is_motion_photo=false
    
    # Only check for motion data if it's a JPG/JPEG
    if [[ "$extension" =~ ^(jpg|jpeg)$ ]]; then
        has_motion=$(exiftool -s3 -MotionPhoto "$img_in_path" 2>/dev/null)
        if [[ "$has_motion" == "1" ]] || exiftool -EmbeddedVideoFile "$img_in_path" &>/dev/null; then
            is_motion_photo=true
        fi
    fi

    if [[ "$is_motion_photo" == true ]]; then
        echo "⚡ Processing Motion Photo -> Converting to HEIC/MOV: $relative_path"
        
        # Temp staging paths for intermediate extractions
        tmp_mp4="${dest_dir}/${filename_no_ext}_tmp.mp4"
        
        # Target unified output paths
        heic_out_path="${dest_dir}/${filename_no_ext}.heic"
        mov_out_path="${dest_dir}/${filename_no_ext}.mov"
	mp4_out_path="${dest_dir}/${filename_no_ext}.mp4"
        
        # 1. Extract raw embedded MP4 track via ExifTool safely
        exiftool -MotionPhotoVideo -b "$img_in_path" > "$tmp_mp4" 2>/dev/null
        #exiftool -MotionPhotoVideo -b "$img_in_path" > "$mp4_out_path" 2>/dev/null

        if [[ -s "$tmp_mp4" ]]; then
            # 2. Convert JPG image payload to HEIC using ImageMagick
            magick "$img_in_path" "$heic_out_path"
            
            # 3. Transcode MP4 wrapper container to QuickTime MOV cleanly (lossless stream copy)
	    #update to fix colour space
            ffmpeg -y -i "$tmp_mp4" -c:v libx264 -pix_fmt yuv420p -colorspace bt709 -color_trc bt709 -color_primaries bt709 -c:a copy "$mov_out_path" &>/dev/null

            #ffmpeg -y -i "$tmp_mp4" -c copy "$mov_out_path" &>/dev/null
            rm -f "$tmp_mp4"
            
            # 4. Clone all original metadata from source JPG back into the fresh HEIC
            exiftool -overwrite_original -TagsFromFile "$img_in_path" "-all:all>all:all" "$heic_out_path" &>/dev/null
            
            # 5. Generate paired Apple metadata ID for linking inside macOS Photos
            uuid=$(uuidgen 2>/dev/null || echo "PIXEL_LIVE_$(date +%N)_$RANDOM")
            
            # 6. Inject synchronization IDs
            #exiftool -overwrite_original -Apple:ContentIdentifier="$uuid" "$heic_out_path"
	    #copy the apple binary data then set the matching uuid
	    exiftool -overwrite_original -TagsFromFile reference.heic -MakerNotes -Make -Model -Apple:All= -Apple:ContentIdentifier="$uuid" "$heic_out_path"
	    exiftool -overwrite_original -Apple:ContentIdentifier="$uuid"  "$heic_out_path"

	    #fix the make and model 
	    make=$(exiftool -s3 -Make "$img_in_path")
            model=$(exiftool -s3 -Model "$img_in_path")
	    exiftool -overwrite_original -m  -Model="$model" -Make="$make" "$heic_out_path"
 	    

            exiftool -overwrite_original -Keys:ContentIdentifier="$uuid" "$mov_out_path"
        else
            echo "❌ Failed to extract valid video payload for $filename. Copying image unchanged."
            cp "$img_in_path" "$dest_dir/$filename"
            rm -f "$tmp_mp4"
        fi
        
    else
        echo "📸 Copying Standard Image: $relative_path"
        cp "$img_in_path" "$dest_dir/$filename"
    fi
done

# Step 2: Process Standalone Videos (MP4, MOV)
for vid_in_path in "$INPUT_DIR"/**/*.(mp4|mov)(N); do
    
    relative_path="${vid_in_path#$INPUT_DIR/}"
    relative_dir=$(dirname "$relative_path")
    filename=$(basename "$relative_path")
    filename_no_ext="${filename%.*}"
    
    dest_dir="$OUTPUT_DIR/$relative_dir"
    mkdir -p "$dest_dir"

    # Check if a matching photo asset exists in the INPUT directory
    matched_photo_exists=false
    for ext in jpg jpeg heic png; do
        if [[ -f "$(dirname "$vid_in_path")/${filename_no_ext}.${ext}" ]]; then
            matched_photo_exists=true
            break
        fi
    done

    # If it's a true standalone video, copy it over unchanged
    if [[ "$matched_photo_exists" == false ]]; then
        echo "🎥 Copying Standalone Video: $relative_path"
        cp "$vid_in_path" "$dest_dir/$filename"
    fi
done

echo "------------------------------------------------"
echo "🎉 Comprehensive Sync and Conversion Complete!"