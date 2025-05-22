#!/bin/bash

# **WARNING: EXPERIMENTAL TOOL** ⚠️  
# **USE AT YOUR OWN RISK. This tool may cause data loss or repository corruption.**

set -e

# Check for required commands
if ! command -v jq > /dev/null; then
  echo "Error: jq is required but not installed. Please install jq for JSON parsing."
  echo "On macOS: brew install jq"
  echo "On Ubuntu/Debian: apt-get install jq"
  exit 1
fi

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <destination-org> <destination-repo> <github-pat>"
  exit 1
fi

DESTINATION_ORG="$1"
DESTINATION_REPO="$2"
GITHUB_PAT="$3"

# Construct destination URL
DEST_REPO_URL="https://git:${GITHUB_PAT}@github.com/${DESTINATION_ORG}/${DESTINATION_REPO}.git"

# Name for the destination remote
DEST_REMOTE="lfs-dest-remote"

# Add the destination remote if not already present
if git remote | grep -q "^$DEST_REMOTE$"; then
  git remote remove "$DEST_REMOTE"
fi
git remote add "$DEST_REMOTE" "$DEST_REPO_URL"
echo "Added remote $DEST_REMOTE to $DEST_REPO_URL"

# Get the LFS endpoint for the current repo
if [ -f .lfsconfig ]; then
  LFS_URL=$(git config -f .lfsconfig lfs.url 2>/dev/null)
fi
if [ -z "$LFS_URL" ]; then
  # Try to guess from remote origin
  ORIGIN_URL=$(git remote get-url origin | sed 's/\.git$//')
  LFS_URL="${ORIGIN_URL}.git/info/lfs"
fi
BATCH_URL="${LFS_URL}/objects/batch"
echo "LFS URL: $LFS_URL"
echo "Batch URL: $BATCH_URL"

# Loop through LFS files using JSON format
git lfs ls-files --all --json | jq -c ".files | .[]" | while read -r json_line; do
    echo $json_line
    oid=$(echo "$json_line" | jq -r '.oid')
    size=$(echo "$json_line" | jq -r '.size')
    file=$(echo "$json_line" | jq -r '.name')

    # Skip if any required field is missing
    if [ -z "$oid" ] || [ -z "$size" ] || [ -z "$file" ] || [ "$oid" = "null" ] || [ "$size" = "null" ] || [ "$file" = "null" ]; then
        echo "Invalid JSON data. Skipping."
        continue
    fi

    echo "Processing $file (OID: $oid, Size: $size)"

    # Prepare Batch API JSON request
    json=$(
      cat <<EOF
{
  "operation": "download",
  "objects": [
    { "oid": "$oid", "size": $size }
  ]
}
EOF
    )
    echo "JSON request: $json"
    
    response=$(curl -s -u "x-access-token:${GITHUB_PAT}" \
      -X POST "$BATCH_URL" \
      -H "Accept: application/vnd.git-lfs+json" \
      -H "Content-Type: application/vnd.git-lfs+json" \
      -d "$json")

    echo "Response: $response"

    # Check for errors in the response
    if echo "$response" | grep -q '"message"'; then
        echo "Error processing $file (OID: $oid): $(echo "$response" | jq -r '.message')"
        continue
    fi

    download_url=$(echo "$response" | jq -r '.objects[0].actions.download.href')
    if [ -z "$download_url" ]; then
        echo "Failed to get download URL for $file (OID: $oid)"
        continue
    fi

    # Compute LFS object path
    dir1=${oid:0:2}
    dir2=${oid:2:2}
    objpath="lfs/objects/$dir1/$dir2"
    mkdir -p "$objpath"

    # Download the object blob
    echo "Downloading LFS object to $objpath/tmp"
    curl -L "$download_url" -o "$objpath/$oid"

    # # Move to final filename
    # mv "$objpath/tmp" "$objpath/data"

    echo "Downloaded $file (OID: $oid) to $objpath/data"

    # Push the object to the destination remote
    echo "Pushing OID $oid to $DEST_REMOTE"
    git lfs push "$DEST_REMOTE" --object-id "$oid"

    # Delete the local object
    if [ -d "$objpath" ]; then
      echo "Deleting local LFS object $objpath"
      rm -rf "$objpath"
    fi
done

echo "Done."