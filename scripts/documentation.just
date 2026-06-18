downloads_dir := "$HOME/Downloads"
books_dir := "/mnt/secondary_ssd/shared/books/"

convert_web url name:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p "{{ books_dir }}"
    tmp="$(mktemp --suffix=.epub)"
    percollate epub -o "$tmp" url "{{ url }}" --title="{{ name }}"
    python3 "{{ justfile_directory() }}/utils/patch_epub.py" "$tmp" "{{ books_dir }}/{{ name }}.epub"
    rm -f "$tmp"

download_github url repo_name:
    #!/usr/bin/env bash
    set -euo pipefail
    raw="{{ url }}"
    if [[ "$raw" != http* ]]; then
        raw="https://github.com/$raw"
    fi
    owner=$(echo "$raw" | sed -E 's#https://github.com/([^/]+)/.*#\1#')
    if [ "$owner" = "$raw" ]; then
        echo "could not parse owner from: $raw" >&2
        exit 1
    fi
    if [[ "$raw" == *"/tree/"* ]]; then
        repo=$(echo "$raw" | sed -E 's#https://github.com/[^/]+/([^/]+)/tree/.*#\1#')
        branch=$(echo "$raw" | sed -E 's#.*tree/([^/]+)/.*#\1#')
        path=$(echo "$raw" | sed -E 's#.*tree/[^/]+/(.*)#\1#')
        tmp=$(mktemp -d)
        git clone --no-checkout --depth 1 --branch "$branch" "https://github.com/$owner/$repo.git" "$tmp"
    else
        repo=$(echo "$raw" | sed -E 's#https://github.com/[^/]+/([^/]+)/?$#\1#')
        path="."
        tmp=$(mktemp -d)
        git clone --no-checkout --depth 1 "https://github.com/$owner/$repo.git" "$tmp"
    fi
    cd "$tmp"
    git sparse-checkout init --cone
    if [ "$path" = "." ]; then
        git sparse-checkout disable
    elif git ls-tree --name-only HEAD static | grep -q .; then
        git sparse-checkout set "$path" static
    else
        git sparse-checkout set "$path"
    fi
    git checkout
    dest="{{ downloads_dir }}/{{ repo_name }}"
    rm -rf "$dest"
    mkdir -p "$dest"
    if [ "$path" = "." ]; then
        mkdir -p "$dest/docs"
        find "$tmp" -mindepth 1 -maxdepth 1 ! -name ".git" ! -name "static" -exec mv {} "$dest/docs" \;
    else
        mv "$tmp/$path" "$dest/docs"
    fi
    if [ -d "$tmp/static" ]; then
        mv "$tmp/static" "$dest/static"
    fi
    rm -rf "$tmp"
    echo "saved to $dest"

convert_github url repo_name: (download_github url repo_name)
    #!/usr/bin/env bash
    set -euo pipefail
    src="{{ downloads_dir }}/{{ repo_name }}"
    assets="$src/static"
    tmp=$(mktemp -d)
    i=0
    while IFS= read -r f; do
        i=$((i+1))
        awk 'BEGIN{fm=0} /^---$/{fm++; next} fm==1{next} {print}' "$f" \
            | sed -E "s#(!\[[^]]*\]\()/#\1${assets}/#g" \
            > "$tmp/$(printf '%04d' "$i").md"
    done < <(find "$src/docs" -name '*.md' | sort)
    out="{{ books_dir }}"
    out="${out%/}/{{ capitalize(repo_name) }}.epub"
    mkdir -p "{{ books_dir }}"
    pandoc "$tmp"/*.md -o "$out" --toc --split-level=1 --metadata title="{{ capitalize(repo_name) }}"
    rm -rf "$tmp"
    echo "wrote $out"
