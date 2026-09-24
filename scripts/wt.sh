#!/bin/sh

# Copyright (c) 2026 REDS Institute - HEIG-VD

# Manage one git worktree per IB_PLATFORM.
#
# The build.sh/deploy.sh/st.sh recipes keep ALL generated state (kernel
# source, u-boot source, bitbake TMPDIR/DL_DIR/sstate) inside the repo
# tree itself, not namespaced per machine — switching IB_PLATFORM in
# place without a full do_clean leaves stale .config/patched sources
# behind. A worktree per platform sidesteps that: each one gets its own
# copy of every git-ignored generated directory (linux/, u-boot/,
# build/tmp, ...), so platforms never share build state.
#
# Platform selection is not purely a bitbake env-var override: scripts/
# st.sh parses build/conf/local.conf itself and picks whichever
# IB_PLATFORM ?= "..." line is the first uncommented one, ignoring any
# exported IB_PLATFORM. So `add` flips that line directly in the new
# worktree's own (git-tracked, but left locally modified/uncommitted)
# local.conf — the same edit a human would make by hand.
#
# Usage:
#   wt.sh add <platform> [path]   Create a worktree for <platform>
#   wt.sh list                    List worktrees with their active platform
#   wt.sh rm <platform|path>      Remove a worktree

set -e

progname=$(basename "$0")

pr_usage()
{
	printf "Manage one git worktree per IB_PLATFORM\n\n"
	printf "Usage: %s add <platform> [path]\n" "$progname"
	printf "       %s list\n" "$progname"
	printf "       %s rm <platform|path>\n\n" "$progname"
	printf "    add <platform> [path]   Create a sibling worktree for <platform>, on a\n"
	printf "                            new branch wt/<platform>, and activate that\n"
	printf "                            platform in its own build/conf/local.conf.\n"
	printf "                            Defaults path to ../<reponame>-<platform>.\n"
	printf "    list                    List worktrees with their active IB_PLATFORM.\n"
	printf "    rm <platform|path>      Remove the matching worktree (refuses if it has\n"
	printf "                            unexpected local changes) and offer to delete\n"
	printf "                            its wt/<platform> branch.\n\n"
	printf "Examples:\n"
	printf "    %s add virt64\n" "$progname"
	printf "    %s list\n" "$progname"
	printf "    %s rm virt64\n" "$progname"
}

case "$1" in
	-h|--help|"")
		pr_usage
		exit 0
		;;
esac

# Resolve project root from this script's own location — NOT via
# common/setup_env.sh, which assumes you already want to build inside
# one resolved tree. wt.sh instead creates/removes sibling trees, so it
# must not trigger (or be confused by) the tree-switch prompt.
IB_ROOT=$(cd "$(dirname "$(command -v -- "$0")")/.." && pwd -P)
LOCAL_CONF="$IB_ROOT/build/conf/local.conf"

cmd=$1
shift

# Platforms this build supports, read from local.conf's own documented
# set of alternatives (build/conf/local.conf:7-11) rather than
# hardcoded, so this stays correct if that list changes.
valid_platforms()
{
	grep -E '^#?[[:space:]]*IB_PLATFORM[[:space:]]*\?=' "$LOCAL_CONF" \
		| sed -E 's/^#?[[:space:]]*IB_PLATFORM[[:space:]]*\?=[[:space:]]*"([^"]*)".*/\1/'
}

# Print the currently-active (uncommented) IB_PLATFORM in a given
# local.conf. Mirrors the line scanner in scripts/st.sh: the first
# uncommented `IB_PLATFORM ?= "..."` line wins.
active_platform()
{
	grep -E '^IB_PLATFORM[[:space:]]*\?=' "$1" | head -n1 \
		| sed -E 's/^IB_PLATFORM[[:space:]]*\?=[[:space:]]*"([^"]*)".*/\1/'
}

case "$cmd" in
	add)
		platform=$1
		wtpath=$2

		if [ -z "$platform" ]; then
			printf "%s: add requires a platform\n" "$progname" >&2
			pr_usage >&2
			exit 1
		fi

		if ! valid_platforms | grep -qx "$platform"; then
			printf "%s: unknown platform '%s'\n" "$progname" "$platform" >&2
			printf "    known platforms: %s\n" "$(valid_platforms | tr '\n' ' ')" >&2
			exit 1
		fi

		if [ -z "$wtpath" ]; then
			reponame=$(basename "$IB_ROOT")
			parent=$(cd "$IB_ROOT/.." && pwd -P)
			wtpath="$parent/${reponame}-${platform}"
		fi

		# dbuild.sh only bind-mounts $IB_ROOT into the container, not its
		# parent — so from inside the container the default sibling path
		# lands in a directory Docker synthesized just to host the mount
		# point (usually root-owned), not the real host directory. `git
		# worktree add` would create the branch, then fail the checkout
		# with "Permission denied", leaving a broken worktree behind. Catch
		# it here, before touching git state at all.
		wtparent=$(dirname "$wtpath")
		if [ -d "$wtparent" ] && [ ! -w "$wtparent" ]; then
			printf "%s: '%s' is not writable — cannot create %s\n" \
				"$progname" "$wtparent" "$wtpath" >&2
			printf "    If you're inside the dbuild.sh container: only the project root\n" >&2
			printf "    is bind-mounted, so a sibling directory outside it isn't reachable\n" >&2
			printf "    from in there. Exit the container and run '%s add %s' from your\n" \
				"$progname" "$platform" >&2
			printf "    normal host shell instead.\n" >&2
			exit 1
		fi

		branch="wt/$platform"

		if git -C "$IB_ROOT" show-ref --verify --quiet "refs/heads/$branch"; then
			printf "%s: branch '%s' already exists — remove it or pick another platform\n" \
				"$progname" "$branch" >&2
			exit 1
		fi

		startpoint=$(git -C "$IB_ROOT" rev-parse --abbrev-ref HEAD)

		printf "[wt] creating worktree for %s at %s (branch %s from %s)\n" \
			"$platform" "$wtpath" "$branch" "$startpoint"

		git -C "$IB_ROOT" worktree add -b "$branch" "$wtpath" "$startpoint"

		# Activate <platform> in the new worktree's own local.conf: comment
		# out whichever IB_PLATFORM line is currently active, uncomment the
		# target one. Left as a local, uncommitted change in that worktree
		# only — never committed, mirrors what a human would do by hand
		# following local.conf's own inline comment block.
		new_conf="$wtpath/build/conf/local.conf"
		current=$(active_platform "$new_conf")

		if [ -n "$current" ] && [ "$current" != "$platform" ]; then
			sed -i \
				-e "s/^IB_PLATFORM ?= \"$current\"/# IB_PLATFORM ?= \"$current\"/" \
				-e "s/^# IB_PLATFORM ?= \"$platform\"/IB_PLATFORM ?= \"$platform\"/" \
				"$new_conf"
		fi

		printf "\n[wt] worktree ready. Next steps:\n"
		printf "    cd %s && . ./env.sh\n" "$wtpath"
		printf "    dbuild.sh --build        # first use only\n"
		printf "    dbuild.sh build.sh bsp-linux\n"
		;;

	list)
		git -C "$IB_ROOT" worktree list | while IFS= read -r wtline; do
			wtp=$(printf '%s\n' "$wtline" | awk '{print $1}')
			plat=""
			[ -f "$wtp/build/conf/local.conf" ] && plat=$(active_platform "$wtp/build/conf/local.conf")
			printf "%s  [%s]\n" "$wtline" "${plat:-?}"
		done
		;;

	rm)
		target=$1
		if [ -z "$target" ]; then
			printf "%s: rm requires a platform or path\n" "$progname" >&2
			exit 1
		fi

		# Resolve <platform|path> to a worktree path KNOWN TO GIT — not
		# gated on the directory still existing on disk. A worktree whose
		# checkout failed (e.g. Permission denied from inside the dbuild.sh
		# container, see `add` above) is registered but "prunable": git
		# still knows about it, the directory just isn't there.
		case "$target" in
			*/*) wtpath=$(cd "$target" 2>/dev/null && pwd -P) || wtpath="" ;;
			*)
				branch="wt/$target"
				wtpath=$(git -C "$IB_ROOT" worktree list --porcelain \
					| awk -v b="refs/heads/$branch" '
						/^worktree /{p=$2}
						$0=="branch "b{print p}')
				;;
		esac

		if [ -z "$wtpath" ]; then
			printf "%s: no worktree found for '%s'\n" "$progname" "$target" >&2
			exit 1
		fi

		# Branch owning this worktree, looked up from git's own records
		# (not `git -C "$wtpath" rev-parse`, which needs an accessible
		# directory — exactly what a broken worktree doesn't have).
		wtbranch=$(git -C "$IB_ROOT" worktree list --porcelain | awk -v p="$wtpath" '
			/^worktree /{cur=$2}
			cur==p && /^branch /{sub(/^branch refs\/heads\//,""); print; exit}')

		if [ -d "$wtpath" ]; then
			# Refuse if there are changes beyond the expected local.conf
			# platform-select line.
			dirty=$(git -C "$wtpath" status --porcelain -- . ':!build/conf/local.conf')
			if [ -n "$dirty" ]; then
				printf "%s: %s has uncommitted changes beyond local.conf — refusing to remove:\n" \
					"$progname" "$wtpath" >&2
				printf '%s\n' "$dirty" >&2
				printf "Remove manually with: git -C %s worktree remove --force %s\n" \
					"$IB_ROOT" "$wtpath" >&2
				exit 1
			fi
		else
			printf "[wt] %s no longer exists on disk (broken worktree) — cleaning up git's records\n" \
				"$wtpath"
		fi

		# --force: needed when the directory exists (the dirty-check above
		# already confirmed nothing but the expected local.conf line
		# differs from HEAD — git worktree remove has no way to know that
		# one file is expected, so it would otherwise refuse
		# unconditionally). Harmless, and required, when the directory is
		# already gone.
		git -C "$IB_ROOT" worktree remove --force "$wtpath"

		case "$wtbranch" in
			wt/*)
				printf "Delete now-unused branch '%s'? [y/N] " "$wtbranch"
				read -r ans
				case "$ans" in
					y|Y|yes|YES) git -C "$IB_ROOT" branch -d "$wtbranch" ;;
				esac
				;;
		esac
		;;

	*)
		printf "%s: unknown command '%s'\n" "$progname" "$cmd" >&2
		pr_usage >&2
		exit 1
		;;
esac
