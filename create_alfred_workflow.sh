#!/usr/bin/env bash

if [ -t 1 ]; then
    # stdout is a terminal
    GREEN=$'\e[0;32m'
    RED=$'\e[0;31m'
    CYAN=$'\e[1;34m'
    NC=$'\e[0m'
fi

# TODO: WHen a PR is merged, copying content of $workflow_dir will possibly overwrite the content of PR!
# We need to find a way of fixing this while making sure changes that I make to $workflow_dir can also be automatically
# added for release creation. <13-12-22, hamid> #
# set -x
version_tag=$1
msg=$2
push_it=$3

if [ -z "$version_tag" ]; then
    echo "You need to provide a semver tag: v0.9.10"
    exit
fi

alfred_pinboard_rs="/Volumes/manzel/hamid/src/learn/rust/alfred-pinboard-rs"
workflow_dir="$HOME/Documents/Alfred.alfredpreferences/workflows/user.workflow.7F236DA2-2C66-4C31-B1D5-7DFDCB7CA715"
res_dir="$alfred_pinboard_rs/res/workflow"

cd "$alfred_pinboard_rs" || exit
git checkout master || exit

printf "\n-> %sCopying resoursces from Alfred's workflow dir...%s\n" "${CYAN}" "${NC}"
cp -r "$workflow_dir"/* "$res_dir" || exit
if ! git diff --name-only --diff-filter=AMDR --quiet "$res_dir"; then
    echo "$res_dir"
    echo "  is different than git repo."
    echo "  Check if we are not overwriting changes from PRs or upstream."
    git diff --name-status --diff-filter=AMDR "$res_dir"
    exit
fi
cargo update || exit

# Run clippy
printf "\n-> %sRunning full pedantic clippy tests%s\n" "${CYAN}" "${NC}"
if ! cargo clippy --tests --workspace -- -Dclippy::all -Dclippy::pedantic -D warnings; then
    exit
fi

# Use rustc 1.65 (should be the same as macos-universal.yml) to ensure that github's workflow doesn't fail
MRV=1.65
printf "\n-> %sSetting rustc to %s%s%s\n" "${CYAN}" "${RED}" "$MRV" "${NC}"
rustup override set "$MRV"
cargo update
cargo fmt || printf 'cargo fmt %sfailed!%s\n' "${RED}" "${NC}"
cargo clippy --tests --workspace -- -Dclippy::all -Dclippy::pedantic -D warnings || printf 'cargo clippy %sfailed!%s\n' "${RED}" "${NC}"
cargo build > "build_$MRV.log" || printf 'cargo build %sfailed!%s\n' "${RED}" "${NC}"

# Switch back to stable
printf "\n-> %sSetting rustc to %s%s%s\n" "${CYAN}" "${RED}" "stable" "${NC}"
rustup override set stable
cargo fmt || printf 'cargo fmt %sfailed!%s\n' "${RED}" "${NC}"
cargo clippy --tests --workspace -- -Dclippy::all -Dclippy::pedantic -D warnings || printf 'cargo clippy %sfailed!%s\n' "${RED}" "${NC}"

# Bump Cargo.toml version
printf "\n-> %sBumping Cargo.toml version to %s%s%s\n" "${CYAN}" "${RED}" "$version_tag" "${NC}"
python res/fix_cargo_version.py "$version_tag" || exit
cargo generate-lockfile || exit

printf "\n-> %sBuilding the crate...%s\n" "${CYAN}" "${NC}"
cargo build > build.log 2>&1

printf "\n-> %sCopying executable to workflow's folder...%s\n" "${CYAN}" "${NC}"
strip target/debug/alfred-pinboard-rs
cp target/debug/alfred-pinboard-rs "$res_dir"

printf "\n-> %sUpdating version in info.plist%s\n" "${CYAN}" "${NC}"
# version_tag=$(git describe --tags --abbrev=0)
defaults write "$res_dir"/info.plist version "$version_tag"
plutil -convert xml1 "$res_dir"/info.plist

# Copy updated info.plist to my workflow_dir
#cp "$res_dir"/info.plist "$workflow_dir" || exit

printf "\n-> %sCreating the workflow bundle...%s\n" "${CYAN}" "${NC}"
rm -f AlfredPinboardRust.alfredworkflow
cd "$res_dir" || exit
rm -f AlfredPinboardRust.alfredworkflow

zip -r AlfredPinboardRust.alfredworkflow ./*

printf "\n-> %sMoving bundle to executable folder...%s\n" "${CYAN}" "${NC}"
mv AlfredPinboardRust.alfredworkflow "$alfred_pinboard_rs"
rm alfred-pinboard-rs

cd "$alfred_pinboard_rs" || exit
git add .github
git add res/workflow
git add res/images
git add Cargo.toml
git add Cargo.lock
git add CHANGELOG.md
git add README.md
git add create_alfred_workflow.sh
git add src

commit_msg="Release version $version_tag"
[ -n "$msg" ] && commit_msg="$commit_msg

$msg"
git pull origin master
git commit -a -m "$commit_msg"
git tag "$version_tag"

# Using atomic push may prevent runner to be triggered twice on a tag push:
# git push --atomic origin master 1.2.3
if [ -n "$push_it" ]; then
    git push
    sleep 2
    git push --tags
fi
