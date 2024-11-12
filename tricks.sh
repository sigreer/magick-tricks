#!/bin/bash


input_image_1=""
input_image_2=""
input_image_3=""
output_image=""
output_image_alt=""
input_image_1_normalised="./${input_image_1%.*}_normalised.png"
input_image_2_normalised="./${input_image_2%.*}_normalised.png"
input_image_3_normalised="./${input_image_3%.*}_normalised.png"
input_image_1_shadow="./${input_image_1%.*}_shadow.png"
input_image_2_shadow="./${input_image_2%.*}_shadow.png"
input_image_3_shadow="./${input_image_3%.*}_shadow.png"
merged_tilted="./${input_image_1%.*}_${input_image_2%.*}_merged_tilted.png"
merged_tilted_alt="./${input_image_2%.*}_${input_image_1%.*}_merged_tilted_alt.png"
input_image_1_tilted="./${input_image_1%.*}_tilted.png"
input_image_2_tilted="./${input_image_2%.*}_tilted.png"
merged_tilted_shadow="./${input_image_1%.*}_${input_image_2%.*}_merged_tilted_shadow.png"
merged_tilted_shadow_alt="./${input_image_2%.*}_${input_image_1%.*}_merged_tilted_shadow_alt.png"
shadow_1="./assets/shadow1.png"
shadow_1_height=300
shadow_2="./assets/shadow2.png"
shadow_2_height=500
shadow_3="./assets/shadow3.png"
shadow_3_height=768
shadow_opacity=0.7
background_color="#000000"
background_opacity=0
no_cleanup=false
timestamp=$(date '+%Y-%m-%d %H:%M:%S')
error_log="${error_log:=./error.log}"
verbosity="${VERBOSITY:-2}" # 0=ERROR, 1=WARN, 2=INFO, 3=DEBUG
console_output="${CONSOLE_OUTPUT:-1}"
file_output="${FILE_OUTPUT:-1}"
compact_mode=false
wide_mode=true
shadow_preset=1

logThis() {
    local severity="$1"
    local log_message="$2"
    
    case "$severity" in
        0) log_level="ERROR" ;;
        1) log_level="WARN"  ;;
        2) log_level="INFO"  ;;
        3) log_level="DEBUG" ;;
        *) log_level="INFO"  ;;
    esac
    
    local level_num=$severity
    local log_entry="[$timestamp] $log_level: $log_message"
    
    if [ $level_num -le $verbosity ]; then
        if [ $console_output -eq 1 ]; then
            case "$log_level" in
                "ERROR") echo -e "\e[31m$log_entry\e[0m" >&2 ;; # Red
                "WARN")  echo -e "\e[33m$log_entry\e[0m" >&2 ;; # Yellow
                *)      echo "$log_entry" ;;
            esac
        fi
        if [ $file_output -eq 1 ]; then
            echo "$log_entry" >> "$error_log"
        fi
    fi
}

process_args() {
    no_cleanup=false
    input_files=()
    compact_mode=false
    wide_mode=false
    if [ $# -lt 1 ]; then
        echo "Error: No subcommand provided"
        show_usage
        exit 1
    fi
    subcommand="$1"
    shift
    for arg in "$@"; do
        case "$arg" in
            "--no-cleanup") no_cleanup=true ;;
            "--compact") compact_mode=true ;;
            "--wide") wide_mode=true ;;
            "--background-color=*")
                background_color="${arg#*=}"
                ;;
            "--background-opacity=*")
                background_opacity="${arg#*=}"
                ;;
            --shadow=*)
                shadow_preset="${arg#*=}"
                if [[ ! "$shadow_preset" =~ ^[1-3]$ ]]; then
                    logThis 0 "Invalid shadow preset: $shadow_preset. Must be 1, 2, or 3."
                    exit 1
                fi
                ;;
            --shadow-opacity=*)
                shadow_opacity="${arg#*=}"
                if ! [[ "$shadow_opacity" =~ ^0*\.?[0-9]+$ ]] || [ "$(echo "$shadow_opacity > 1" | bc -l)" -eq 1 ] || [ "$(echo "$shadow_opacity < 0" | bc -l)" -eq 1 ]; then
                    logThis 0 "Invalid shadow opacity: $shadow_opacity. Must be between 0 and 1."
                    exit 1
                fi
                ;;
            *) input_files+=("$arg") ;;
        esac
    done
    if [ ${#input_files[@]} -ne 3 ]; then
        echo "Error: Script requires exactly 3 input images"
        show_usage
        exit 1
    fi
    input_image_1="${input_files[0]}"
    input_image_2="${input_files[1]}"
    input_image_3="${input_files[2]}"
    
    for img in "$input_image_1" "$input_image_2" "$input_image_3"; do
        if [ ! -f "$img" ]; then
            logThis 0 "File '$img' does not exist"
            exit 1
        fi
    done
    input_image_1_normalised="./${input_image_1%.*}_normalised.png"
    input_image_2_normalised="./${input_image_2%.*}_normalised.png"
    input_image_3_normalised="./${input_image_3%.*}_normalised.png"
    input_image_1_shadow="./${input_image_1%.*}_shadow.png"
    input_image_2_shadow="./${input_image_2%.*}_shadow.png"
    input_image_3_shadow="./${input_image_3%.*}_shadow.png"
    input_image_1_tilted="./${input_image_1%.*}_tilted.png"
    input_image_2_tilted="./${input_image_2%.*}_tilted.png"
    input_image_3_tilted="./${input_image_3%.*}_tilted.png"
    input_image_3_shadow_centered="./${input_image_3%.*}_shadow_centered.png"
    output_image="./${subcommand}_1.png"
    output_image_alt="./${subcommand}_2.png"
}

show_usage() {
    echo "Usage: $0 <perspective|mirrortilt> image1 image2 image3 [options]"
    echo ""
    echo "Use the following subcommands to create screenshot collages with:"
    echo "  perspective     a central image and two outer images with central vanishing point."
    echo "  mirrortilt      a central image and two outer images with mirrored tilt effect."
    echo "                  both sub-commands auomatically create inverted variants of the output collage."
    echo ""
    echo "Options:"
    echo "  --compact     Overlap the background images for a more compact layout"
    echo "  --wide        Add a gap in between the output images for better visibility of each screenshot (default)."
    echo "  --shadow=N    Use shadow preset (1, 2, or 3), defaults to 1."
    echo "  --shadow-opacity=N    Set shadow opacity. Decimal or percentage. Defaults to 70%."
    echo "  --background-color=HEX    Set background color. Defaults to black (#000000)."
    echo "  --background-opacity=N    Set background opacity. Decimal or percentage. Defaults to zero (transparent)."
    echo "  --no-cleanup  Keep temporary files (useful for debugging or if you want to use the individual elements)"
}

normalize_height() {
    local target_height=768
    local target_width=1600
    local input_file="$1"
    local output_file="$2"
    local current_height=$(magick identify -format "%h" "$input_file")
    if [ "$current_height" -ne "$target_height" ]; then
        echo "Normalizing height of $input_file..."
        magick "$input_file" -resize "${target_width}x${target_height}" "$output_file"
    else
        cp "$input_file" "$output_file"
    fi
    if [ $? -eq 0 ]; then
        logThis 2 "Done normalizing height of $input_file"
        return 0
    else
        logThis 0 "Error normalizing height"
        cleanup
        exit 1
    fi
}

shadow() {
    local input_file="$1"
    local output_file="$2"
    local shadow_preset="${3:-1}"  # Default to shadow_1 if not specified
    
    # Select shadow file and height based on preset
    local shadow_file="./shadow${shadow_preset}.png"
    local shadow_height
    case "$shadow_preset" in
        1) shadow_file="$shadow_1"; shadow_height=$shadow_1_height ;;
        2) shadow_file="$shadow_2"; shadow_height=$shadow_2_height ;;
        3) shadow_file="$shadow_3"; shadow_height=$shadow_3_height ;;
        *) logThis 0 "Invalid shadow preset: $shadow_preset"; return 1 ;;
    esac
    
    if [ ! -f "$shadow_file" ]; then
        logThis 0 "Error: Shadow file '$shadow_file' not found"
        cleanup
        exit 1
    fi
    
    # Get dimensions of input image and shadow
    local img_width=$(magick identify -format "%w" "$input_file")
    local shadow_width=$(magick identify -format "%w" "$shadow_file")
    
    local x_offset=$(( (img_width - shadow_width) / 2 ))
    
    magick "$input_file" \
        \( "$shadow_file" -resize "x${shadow_height}" -alpha set -channel A -evaluate multiply "${shadow_opacity}" \) \
        -gravity north -geometry "+${x_offset}+0" \
        -composite "$output_file"
        
    if [ $? -eq 0 ]; then
        logThis 2 "Done adding shadow to $input_file using shadow preset $shadow_preset"
        return 0
    else
        logThis 0 "Error adding shadow"
        cleanup
        exit 1
    fi
}

right_tilt() {
    logThis 2 "Tilting right image..."
    magick "$1" \
        -alpha set -background none \
        -virtual-pixel transparent \
        +distort Perspective \
        '0,0,0,0 0,768,0,768 1600,768,1380,868 1600,0,1380,100' \
        "$2"
    if [ $? -eq 0 ]; then
        logThis 2 "Done tilting right image"
        return 0
    else
        logThis 0 "Error tilting right image"
        cleanup
        exit 1
    fi
}

left_tilt() {
    logThis 2 "Tilting left image..."
    magick "$1" \
        -alpha set -background none \
        -virtual-pixel transparent \
        +distort Perspective \
        '0,0,220,100 0,768,220,868 1600,768,1600,768 1600,0,1600,0' \
        "$2"
    if [ $? -eq 0 ]; then
        logThis 2 "Done tilting left image"
        return 0
    else
        logThis 0 "Error tilting left image"
        cleanup
        exit 1
    fi
}

right_perspective() {
    logThis 2 "Adding perspective to right image..."
    magick "$1" \
        -alpha set -background none \
        -virtual-pixel transparent \
        +distort Perspective \
        '0,0,0,0 0,768,0,768 1600,768,1300,668 1600,0,1300,100' \
        "$2"
    if [ $? -eq 0 ]; then
        logThis 2 "Done adding perspective to right image"
        return 0
    else
        logThis 0 "Error adding perspective to right image"
        cleanup
        exit 1
    fi
}

left_perspective() {
    logThis 2 "Adding perspective to left image..."
    magick "$1" \
        -alpha set -background none \
        -virtual-pixel transparent \
        +distort Perspective \
        '0,0,300,100 0,768,300,668 1600,768,1600,768 1600,0,1600,0' \
        "$2"
    if [ $? -eq 0 ]; then
        logThis 2 "Done adding perspective to left image"
        return 0
    else
        logThis 0 "Error adding perspective to left image"
        cleanup
        exit 1
    fi
}

merge_tilted_images() {
    logThis 3 "Attempting to merge tilted images: $1 and $2"
    if [ ! -f "$1" ] || [ ! -f "$2" ]; then
        logThis 0 "Input files for merge_tilted_images don't exist"
        return 1
    fi
    
    if [ "$wide_mode" = true ]; then
        local width1=$(magick identify -format "%w" "$1")
        local width2=$(magick identify -format "%w" "$2")
        local height=$(magick identify -format "%h" "$1")
        local offset=$((width1 + 300))
        local total_width=$((width1 + width2 + 300))
        
        magick -size "${total_width}x${height}" xc:none \
            \( "$1" -alpha set -background none -repage "+0+0" \) \
            \( "$2" -alpha set -background none -repage "+${offset}+0" \) \
            -background none -layers merge "$3"
    elif [ "$compact_mode" = true ]; then
        local width1=$(magick identify -format "%w" "$1")
        local width2=$(magick identify -format "%w" "$2")
        local height=$(magick identify -format "%h" "$1")
        local offset=$((width1 - 200))
        local total_width=$((width1 + width2 - 200))
        
        magick -size "${total_width}x${height}" xc:none \
            \( "$1" -alpha set -background none -repage "+0+0" \) \
            \( "$2" -alpha set -background none -repage "+${offset}+0" \) \
            -background none -layers merge "$3"
    else
        magick "$1" "$2" -alpha set -background none +append "$3"
    fi
    
    local status=$?
    if [ $status -eq 0 ]; then
        logThis 2 "Successfully merged tilted images"
        if [ ! -f "$3" ]; then
            logThis 0 "Merged file wasn't created despite successful command"
            return 1
        fi
        return 0
    else
        logThis 0 "Error merging tilted images (status: $status)"
        return 1
    fi
}

add_shadow_to_tilted_images() {
    logThis 3 "Attempting to add shadow to tilted image: $1"
    if [ ! -f "$1" ]; then
        logThis 0 "Input file for add_shadow_to_tilted_images doesn't exist"
        return 1
    fi
    
    magick "$1" \
        \( +clone -alpha extract -background none -shadow "80x20+15+15" \) \
        +swap -background none -layers merge -alpha set \
        "$2"
    local status=$?
    if [ $status -eq 0 ]; then
        logThis 2 "Successfully added shadow to tilted images"
        if [ ! -f "$2" ]; then
            logThis 0 "Shadow file wasn't created despite successful command"
            return 1
        fi
        return 0
    else
        logThis 0 "Error adding shadow to tilted images (status: $status)"
        return 1
    fi
}

add_shadow_to_center_image() {
    magick "$1" \
        \( +clone -background none -shadow "60x10+8+8" \) \
        +swap -background none -layers merge -alpha set \
        "$2"
    if [ $? -eq 0 ]; then
        logThis 2 "Done adding shadow to center image"
        return 0
    else
        logThis 0 "Error adding shadow to center image"
        cleanup
        exit 1
    fi
}

overlay_center_image() {
    local scale_factor=1
    if [ "$compact_mode" = true ]; then
        scale_factor=0.85
    fi
    local original_width=$(magick identify -format "%w" "$2")
    local original_height=$(magick identify -format "%h" "$2")
    local combined_width=$(magick identify -format "%w" "$1")
    local combined_height=$(magick identify -format "%h" "$1")
    local new_width=$(printf "%.0f" $(echo "$original_width * $scale_factor" | bc))
    local new_height=$(printf "%.0f" $(echo "$original_height * $scale_factor" | bc))
    local x_offset=$(( (combined_width - new_width) / 2 ))
    local y_offset=$(( (combined_height - new_height - 10) / 2 ))
    local bg_opacity_value
    if [[ "$background_opacity" =~ ^[0-9]+$ ]]; then
        bg_opacity_value=$background_opacity
    else
        bg_opacity_value=$(echo "$background_opacity * 100" | bc)
    fi
    local bg_color_with_opacity="${background_color}${bg_opacity_value}"

    magick -size "${combined_width}x${combined_height}" xc:"${bg_color_with_opacity}" \
        \( "$1" -alpha set -background none -repage "+0+0" \) \
        \( "$2" -alpha set -background none -resize ${new_width}x${new_height} -repage "+${x_offset}+${y_offset}" \) \
        -background none -layers merge -alpha set \
        "$3"
        
    if [ $? -eq 0 ]; then
        logThis 2 "Done overlaying center image $2"
        return 0
    else
        logThis 0 "Error overlaying center image $2"
        cleanup
        exit 1
    fi
}

cleanup() {
    if [ "$no_cleanup" = true ]; then
        logThis 2 "Skipping cleanup..."
        return 0
    fi
    rm -f "$merged_tilted" "$merged_tilted_shadow" "$merged_tilted_shadow_alt" \
        "$input_image_1_normalised" "$input_image_2_normalised" "$input_image_3_normalised" \
        "$input_image_1_shadow" "$input_image_2_shadow" "$input_image_3_shadow" \
        "$input_image_1_tilted" "$input_image_2_tilted" \
        "$input_image_3_shadow_centered"
}

main() {
    process_args "$@"
    normalize_height "$input_image_1" "$input_image_1_normalised"
    normalize_height "$input_image_2" "$input_image_2_normalised"
    normalize_height "$input_image_3" "$input_image_3_normalised"
    shadow "$input_image_1_normalised" "$input_image_1_shadow" "$shadow_preset"
    shadow "$input_image_2_normalised" "$input_image_2_shadow" "$shadow_preset"
    shadow "$input_image_3_normalised" "$input_image_3_shadow" "$shadow_preset"

    case "$subcommand" in
        perspective)
            left_perspective "$input_image_1_shadow" "$input_image_1_tilted"
            right_perspective "$input_image_2_shadow" "$input_image_2_tilted"
            ;;
        mirrortilt)
            left_tilt "$input_image_1_shadow" "$input_image_1_tilted"
            right_tilt "$input_image_2_shadow" "$input_image_2_tilted"
            ;;
        # cascade)
        #     cascade_1 "$input_image_1_shadow" "$input_image_1_tilted"
        #     cascade_2 "$input_image_2_shadow" "$input_image_2_tilted"
        #     cascade_3 "$input_image_3_shadow" "$input_image_3_tilted"
        # ;;
        *)
            echo "Error: Unknown subcommand '$subcommand'"
            show_usage
            exit 1
            ;;
    esac

    merge_tilted_images "$input_image_2_tilted" "$input_image_1_tilted" "$merged_tilted"
    merge_tilted_images "$input_image_1_tilted" "$input_image_2_tilted" "$merged_tilted_alt"
    add_shadow_to_tilted_images "$merged_tilted" "$merged_tilted_shadow"
    add_shadow_to_tilted_images "$merged_tilted_alt" "$merged_tilted_shadow_alt"
    add_shadow_to_center_image "$input_image_3_shadow" "$input_image_3_shadow_centered"
    overlay_center_image "$merged_tilted_shadow" "$input_image_3_shadow_centered" "$output_image"
    overlay_center_image "$merged_tilted_shadow_alt" "$input_image_3_shadow_centered" "$output_image_alt"
    cleanup
    logThis 2 "Created cascade image: $output_image"
    logThis 2 "Created inverted cascade image: $output_image_alt"
}

# Replace the direct command execution with main
main "$@"
