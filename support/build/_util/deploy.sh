#!/usr/bin/env bash

# fail hard
set -o pipefail
# fail harder
set -eu

help=false

publish=false

# process flags
optstring=":-:h"
while getopts "$optstring" opt; do
	case $opt in
		h)
			help=true
			;;
		-)
			case "$OPTARG" in
				help)
					help=true
					;;
				publish)
					publish=true
					break
					;;
				*)
					OPTIND=1
					break
					;;
			esac
	esac
done
# clear processed "publish" argument
shift $((OPTIND-1))

if $help || [[ $# -lt 1 ]]; then
	cat >&2 <<-EOF
		Usage: $(basename "$0") [--publish] FORMULA-VERSION [--overwrite]
		  If --publish is given, mkrepo.sh will be invoked after a successful deploy to
		  re-generate the repo. CAUTION: this will cause all manifests in the bucket to
		  be included in the repo, including potentially currently unpublished ones.
		  All additional arguments, including --overwrite, are passed through to 'bob'.
	EOF
	exit 2
fi

if [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
	echo '$AWS_ACCESS_KEY_ID or $AWS_SECRET_ACCESS_KEY not set!' >&2
	exit 2
fi

# a helper (print_or_export_manifest_cmd) called in the script invoked by Bob will write to this if set
MANIFEST_CMD=$(mktemp -t "manifest.XXXXX")
export MANIFEST_CMD
trap 'rm -rf "$MANIFEST_CMD";' EXIT

# make sure we start cleanly
rm -rf /app/.heroku/php

# pass through args (so users can pass --overwrite etc)
# but modify any path by stripping $WORKSPACE_DIR from the front, if it's there
# so that one can also pass in the full path to the formula relative to the root, and not just relative to $WORKSPACE_DIR
# that allows for simpler mass build loops using wildcards without having to worry about the relative location of other references such as an --env-file, like:
# for f in support/build/php-{5,7}.* support/build/extensions/no-debug-non-zts-201*/{redis,blackfire,imagick}-*; do docker run --rm --tty --interactive --env-file=../dockerenv.heroku-22 heroku-php-builder-heroku-22 deploy.sh $f; done
args=()
for var in "$@"; do
	expanded="$(pwd)/$var"
	if [[ -f $expanded ]]; then
		var="${expanded#$WORKSPACE_DIR/}"
	fi
	args+=("$var")
done

bob deploy "${args[@]}"

# invoke manifest upload
echo ""
echo "Uploading manifest..."
. "$MANIFEST_CMD"

if $publish; then
	echo "Updating repository..."
	"$(dirname "$BASH_SOURCE")/mkrepo.sh" --upload
fi
