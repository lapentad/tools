#!/bin/bash
####################################################################################################################
#This script will iterate over child directories, and bump semantic verions for pom.xml generic-tag.yaml and README#
####################################################################################################################

OLD_VERSION="j-release"
NEW_VERSION="k-release"

# Function to increment semantic version MAJOR.MINOR.PATCH
generate_new_version() {
    local version=$1
    IFS='.' read -r -a parts <<< "$version"

    # Increment the PATCH version
    parts[2]=$((parts[2] + 1))

    # If the PATCH part reaches 10, reset it and increment the MINOR
    if [ "${parts[2]}" -eq 10 ]; then
        parts[2]=0
        parts[1]=$((parts[1] + 1))
    fi

    # If the MINOR part reaches 10, reset it and increment the MAJOR
    if [ "${parts[1]}" -eq 10 ]; then
        parts[1]=0
        parts[0]=$((parts[0] + 1))
    fi

    echo "${parts[0]}.${parts[1]}.${parts[2]}"
}

# Update container-tag.yaml
update_container_tag() {
    local file=$1
    while IFS= read -r line; do
        if [[ "$line" =~ ^tag:\ ([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
            old_version=${BASH_REMATCH[1]}
            new_version=$(generate_new_version "$old_version")
            sed -i "s/tag: $old_version/tag: $new_version/" "$file"
            echo "Updated $file: $old_version -> $new_version"
        fi
    done < "$file"
}

# Update pom.xml
update_pom_version() {
    local file=$1

    current_version=$(mvn -f "$(dirname "$file")" help:evaluate -Dexpression=project.version -q -DforceStdout)
    if [[ $? -ne 0 || -z "$current_version" ]]; then
        echo "Failed to get version from Maven for $file. Skipping..."
        return
    fi

    if [[ "$current_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-SNAPSHOT)?$ ]]; then
        base_version=${current_version%-SNAPSHOT}
        new_version=$(generate_new_version "$base_version")

        if [[ "$current_version" == *"-SNAPSHOT" ]]; then
            sed -i "s/<version>$current_version<\/version>/<version>$new_version-SNAPSHOT<\/version>/" "$file"
            echo "Updated $file: $current_version -> $new_version-SNAPSHOT"
        else
            sed -i "s/<version>$current_version<\/version>/<version>$new_version<\/version>/" "$file"
            echo "Updated $file: $current_version -> $new_version"
        fi
    else
        echo "Invalid version format: $current_version in $file. Skipping..."
    fi
}


# Iterate over child directories
for dir in */; do
    echo "Processing directory: $dir"

    sed -i "s/$OLD_VERSION/$NEW_VERSION/g" README.md

    find $dir -type f -name "container-tag.yaml" | while IFS= read -r file; do
        update_container_tag "$file"
    done

    find $dir -type f -name "pom.xml" | while IFS= read -r file; do
        update_pom_version "$file"
    done
done
