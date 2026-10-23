#!/usr/bin/env bash
# Checks whether a newer Open3D release exists upstream, and whether our
# Embree ISA patch (scripts/patch_embree.py) still applies cleanly to it.
# If there's a newer release, opens a PR bumping open3d-version.txt, noting
# patch compatibility so a bad bump doesn't get merged blind.
#
# Run by .github/workflows/check-open3d-version.yml on a schedule.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CURRENT="$(tr -d '[:space:]' < "$REPO_ROOT/open3d-version.txt")"

LATEST_TAG="$(gh api repos/isl-org/Open3D/releases/latest --jq .tag_name)"
LATEST="${LATEST_TAG#v}"

echo "Pinned: ${CURRENT}  Latest upstream: ${LATEST}"

if [ "$LATEST" = "$CURRENT" ]; then
    echo "Already up to date."
    exit 0
fi

# Does our patch's expected block still exist in the candidate version's
# embree.cmake? This is what "track Open3D's own requirements/third-party
# pins" means in practice for us - embree is the only thing we patch.
TMP_EMBREE="$(mktemp)"
curl -sL "https://raw.githubusercontent.com/isl-org/Open3D/${LATEST_TAG}/3rdparty/embree/embree.cmake" -o "$TMP_EMBREE"

if python3 "$REPO_ROOT/scripts/patch_embree.py" --check "$TMP_EMBREE"; then
    EMBREE_NOTE="Embree ISA block unchanged - the existing patch should apply cleanly."
else
    EMBREE_NOTE="**Open3D changed \`3rdparty/embree/embree.cmake\`'s structure in this release.** \`scripts/patch_embree.py\` needs manual review before merging this bump - otherwise the build will fail loudly rather than silently skipping the patch, but it won't succeed until the script is updated."
fi
rm -f "$TMP_EMBREE"

BRANCH="bump-open3d-${LATEST}"
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git checkout -b "$BRANCH"
echo "$LATEST" > "$REPO_ROOT/open3d-version.txt"
git add open3d-version.txt
git commit -m "Bump pinned Open3D version to ${LATEST}"
git push -u origin "$BRANCH"

gh pr create \
    --title "Bump Open3D to ${LATEST}" \
    --body "Open3D \`${LATEST_TAG}\` was released upstream: https://github.com/isl-org/Open3D/releases/tag/${LATEST_TAG}

${EMBREE_NOTE}

Merging this will trigger a rebuild and publish a new wheel release." \
    --base main \
    --head "$BRANCH"
