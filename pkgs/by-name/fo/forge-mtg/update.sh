#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl nix-update gnused python3

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

check_launch4j_in_pom() {
    local pom_file="$1"
    if [[ -f "$pom_file" ]]; then
        grep -q "com.akathist.maven.plugins.launch4j" "$pom_file" 2>/dev/null
    else
        return 1
    fi
}

update_patch() {
    local version="$1"
    local temp_dir=$(mktemp -d)
    
    echo "Downloading forge source version $version to check for launch4j plugins..."
    curl -L "https://github.com/Card-Forge/forge/archive/forge-$version.tar.gz" | tar -xz -C "$temp_dir"
    local source_dir="$temp_dir/forge-forge-$version"
    
    # Check if we need to update the patch
    local needs_update=false
    local patch_content=""
    
    # Find all pom.xml files that contain launch4j plugin
    while IFS= read -r -d '' pom_file; do
        if check_launch4j_in_pom "$pom_file"; then
            needs_update=true
            echo "Found launch4j plugin in: $pom_file"
            
            # Generate patch content for this file
            local relative_path=$(echo "$pom_file" | sed "s|^$source_dir/||")
            local temp_original="$temp_dir/original_$(basename "$pom_file")"
            local temp_patched="$temp_dir/patched_$(basename "$pom_file")"
            
            cp "$pom_file" "$temp_original"
            cp "$pom_file" "$temp_patched"
            
            # Remove launch4j plugin sections using the dedicated script
            python3 "$SCRIPT_DIR/erase-plugin.py" "$temp_patched" "launch4j-maven-plugin"
            
            # Generate diff for this file
            if ! cmp -s "$temp_original" "$temp_patched"; then
                local file_diff=$(diff -u "$temp_original" "$temp_patched" | sed "s|$temp_original|a/$relative_path|g; s|$temp_patched|b/$relative_path|g" | sed '1,2s/\t.*$//')
                if [[ -n "$file_diff" ]]; then
                    patch_content+="$file_diff"$'\n'
                fi
            fi
        fi
    done < <(find "$source_dir" -name "pom.xml" -print0)
    
    if [[ "$needs_update" == "true" && -n "$patch_content" ]]; then
        echo "Updating no-launch4j.patch..."
        echo "$patch_content" > "$SCRIPT_DIR/no-launch4j.patch"
        echo "Patch updated successfully!"
    else
        echo "No launch4j plugins found or patch is already up to date."
    fi
    
    rm -rf "$temp_dir"
}

echo "Updating forge-mtg package..."

# Get current version from package.nix for patch generation
current_version=$(grep 'version = ' "$SCRIPT_DIR/package.nix" | sed 's/.*"\(.*\)".*/\1/')
echo "Current version: $current_version"

# First, let nix-update handle version and hash updates
echo "Running nix-update to check for version updates..."
nix-update --version-regex=forge-'(.*)' forge-mtg

# Get the potentially updated version
new_version=$(grep 'version = ' "$SCRIPT_DIR/package.nix" | sed 's/.*"\(.*\)".*/\1/')

# Update the patch (either for current or new version)
if [[ "$current_version" != "$new_version" ]]; then
    echo "Version updated from $current_version to $new_version, updating patch..."
    update_patch "$new_version"
else
    echo "No version change, checking if patch needs updating..."
    update_patch "$current_version"
fi

echo "Update complete!"