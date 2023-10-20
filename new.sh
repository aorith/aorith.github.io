#!/usr/bin/env bash
cd "$(dirname -- "$0")" || exit 1

mkdir -p content
echo "Creating a new blog entry ..."
read -rp 'Entry (example: posts/my-first-post.md): ' entry
[[ -n "$entry" ]] || exit 1

hugo new content "$entry"
nvim "content/$entry"
