#!/bin/sh

set -eu

# Keep these sentinels split so release publishing only rewrites the configured
# values below; local or unpublished copies still need unreplaced values to compare.
relay_unconfigured_base_url="__RELAY_DOWNLOAD_BASE""_URL__"
relay_unconfigured_default_release_channel="__RELAY_DEFAULT_RELEASE_""CHANNEL__"
# The Node floor is the package's own engines.node. The installer used to gate at
# 20.6.0 while the app refused to start below 22.8.0, so a machine on 20.6-22.7
# installed cleanly and then could not run `relay` at all — the check passed and
# the product still did not work. One value, stated once.
relay_min_node_major=22
relay_min_node_minor=8
relay_min_node_patch=0
relay_min_node="${relay_min_node_major}.${relay_min_node_minor}.${relay_min_node_patch}"
relay_base_url="${RELAY_DOWNLOAD_BASE_URL:-https://relayevals.com/harness}"
relay_base_url="${relay_base_url%/}"
relay_default_release_channel="stable"
if [ "$relay_default_release_channel" = "$relay_unconfigured_default_release_channel" ]; then
	relay_default_release_channel=stable
fi
relay_release_channel="${RELAY_RELEASE_CHANNEL:-$relay_default_release_channel}"
relay_package="${RELAY_PACKAGE:-relay-worker}"
relay_cmd="${RELAY_CMD:-relay}"
relay_esc=$(printf '\033')
relay_original_path="${PATH:-}"
relay_reset="${relay_esc}[0m"
relay_bold="${relay_esc}[1m"
relay_italic="${relay_esc}[3m"
relay_hide_cursor="${relay_esc}[?25l"
relay_show_cursor="${relay_esc}[?25h"
relay_home_cursor="${relay_esc}[H"
relay_clear_screen="${relay_esc}[2J${relay_esc}[H"
relay_clear_line="${relay_esc}[K"
relay_sync_start="${relay_esc}[?2026h"
relay_sync_end="${relay_esc}[?2026l"
relay_color_text="${relay_esc}[38;2;244;244;245m"
relay_color_muted="${relay_esc}[38;2;161;161;170m"
relay_color_dim="${relay_esc}[38;2;113;113;122m"
relay_color_primary="${relay_esc}[38;2;127;91;213m"
relay_color_scan="${relay_esc}[38;2;14;165;233m"
relay_color_warning="${relay_esc}[38;2;245;158;11m"
readonly relay_unconfigured_base_url relay_unconfigured_default_release_channel relay_base_url relay_default_release_channel relay_release_channel relay_package relay_cmd relay_esc relay_original_path
readonly relay_reset relay_bold relay_italic relay_hide_cursor relay_show_cursor relay_home_cursor relay_clear_screen relay_clear_line
readonly relay_sync_start relay_sync_end
readonly relay_color_text relay_color_muted relay_color_dim relay_color_primary relay_color_scan relay_color_warning

relay_screen_enabled=0
relay_screen_frame=0
relay_screen_cols=80
relay_screen_rows=24
relay_screen_drawn=0
relay_screen_last_cols=0
relay_screen_last_rows=0
relay_screen_layout_ready=0
relay_screen_layout_show_logo=0
relay_screen_layout_lab_width=0
relay_screen_render_lab_width=0
relay_screen_compact=0
relay_download_dir=
relay_bootstrap_kernel_on_install=0
relay_system_npm_prefix=
relay_user_npm_prefix=
relay_retired_alias_removed=
relay_screen_title=
relay_screen_status=
relay_screen_detail=
relay_screen_question=
relay_animation_frame=0
# The one anonymous count sent at the end (D-72): the step the installer is on, so a failing exit names it; how it
# ended when that was not a failure exit; whether relay was here before; and the version, once it is known.
relay_count_step=INSTALL_NODE_MISSING
relay_count_outcome=
relay_count_finished=0
relay_count_signalled=0
relay_count_kind=NEW
relay_count_version=unknown

main() {
	if [ "$relay_base_url" = "$relay_unconfigured_base_url" ]; then
		printf 'error: installer download URL is not configured.\n' >&2
		printf 'Set RELAY_DOWNLOAD_BASE_URL or use the installer published by the release workflow.\n' >&2
		exit 1
	fi

	relay_install_traps
	relay_count_note_prior_install
	relay_init_screen
	if [ "$relay_screen_enabled" = 1 ]; then
		relay_screen "Installing Relay" "" "" ""
	else
		printf '\n\033[1m  Installing Relay\033[0m\n\033[2m  npm global install\033[0m\n\n'
	fi

	start_preflight_checks

	if finish_preflight_checks; then
		check_status=0
	else
		check_status=$?
	fi

	if [ "$check_status" -ne 0 ]; then
		if ! install_node_npm_interactive; then
			exit "$check_status"
		fi

		start_preflight_checks
		if finish_preflight_checks; then
			check_status=0
		else
			check_status=$?
		fi

		if [ "$check_status" -ne 0 ]; then
			exit "$check_status"
		fi
	fi

	relay_count_step=INSTALL_NPM_FAILED
	choose_npm_prefix

	relay_count_step=INSTALL_DOWNLOAD
	version="$(resolve_relay_version "$@")"
	relay_count_version="$version"
	tarball_name="$relay_package-$version.tgz"
	tarball_url="$relay_base_url/releases/v$version/$tarball_name"

	confirm_install "$version" "$tarball_url"
	confirm_kernel_runtime_setup

	download_dir=$(create_temp_dir)
	relay_download_dir="$download_dir"
	tarball_path="$download_dir/$tarball_name"

	download_relay_package "$version" "$tarball_url" "$tarball_path"
	relay_count_step=INSTALL_NPM_FAILED
	clear_stale_relay_alias
	clear_retired_gate_alias
	install_relay_package "$tarball_path"
	relay_count_step=INSTALL_BROKEN
	verify_relay_runs
	relay_count_step=INSTALL_NOT_ON_PATH
	rm -rf "$download_dir"
	relay_download_dir=

	if [ "${RELAY_NODE_INSTALLED_STANDALONE:-0}" = 1 ]; then
		relay_screen "Relay installed" "" "Checking your shell PATH." ""
		configure_relay_path "$RELAY_STANDALONE_NODE_BIN" "standalone Node.js" "Relay standalone Node.js"
	elif [ -n "$relay_user_npm_prefix" ]; then
		if [ "$relay_screen_enabled" != 1 ]; then
			print_user_npm_prefix_note
		fi
		relay_screen "Relay installed" "" "Checking your shell PATH." ""
		configure_relay_path "$relay_user_npm_prefix/bin" "Relay's npm folder" "Relay npm folder"
		if [ "$relay_screen_enabled" = 1 ]; then
			relay_restore_terminal
			printf '\n'
			print_user_npm_prefix_note
		fi
	elif command -v "$relay_cmd" >/dev/null 2>&1; then
		if relay_other=$(relay_shadowing_command); then
			print_relay_shadowed "$relay_other"
		else
			print_relay_welcome
		fi
	elif relay_npm_bin=$(relay_npm_bin_dir); then
		configure_relay_path "$relay_npm_bin" "npm's global bin folder" "Relay: npm global bin folder"
	else
		if [ "$relay_screen_enabled" = 1 ]; then
			relay_screen "Relay installed" "" "PATH update needed for $relay_cmd." ""
			relay_restore_terminal
		fi
		printf '\nThe %s command was installed, but it is not on your PATH yet.\n' "$relay_cmd"
		printf 'Add the bin folder inside the path printed by "npm prefix -g" to your shell PATH.\n'
		relay_count_outcome=INSTALL_NOT_ON_PATH
	fi
	print_retired_alias_note
	relay_count_finished=1
}

# npm installs -g packages into its prefix. When root owns that prefix, which is
# the case for Node from the nodejs.org installer on macOS, for distro or
# NodeSource Node on Linux, and for the Node this script installs with apt or
# apk, npm fails with EACCES and advises running as root. Find that out before
# npm runs and install into a folder this account owns instead. npm's own
# configuration is left alone: the folder is passed with --prefix to this one
# install, and `relay update` infers the same --prefix from where it runs.
choose_npm_prefix() {
	if [ "${EUID:-$(id -u)}" -eq 0 ]; then
		return 0
	fi
	npm_global_prefix=$(npm prefix -g 2>/dev/null) || return 0
	[ -n "$npm_global_prefix" ] || return 0
	if npm_prefix_is_writable "$npm_global_prefix"; then
		return 0
	fi

	if [ -z "${HOME:-}" ]; then
		relay_restore_terminal
		printf '\nerror: npm installs global packages into %s, which this account cannot write to,\n' "$npm_global_prefix" >&2
		printf 'and HOME is not set, so there is no folder of your own to install into instead.\n' >&2
		printf 'Set HOME, or point npm at a folder you own with NPM_CONFIG_PREFIX, then run this installer again.\n' >&2
		exit 1
	fi

	relay_system_npm_prefix="$npm_global_prefix"
	relay_user_npm_prefix="$HOME/.relay/npm-global"
	if [ "$relay_screen_enabled" != 1 ]; then
		printf 'npm installs global packages into %s, which this account cannot write to.\n' "$relay_system_npm_prefix"
		printf 'Relay will install into %s instead. It does not use sudo\n' "$(relay_display_path "$relay_user_npm_prefix")"
		printf 'and does not change npm'"'"'s settings.\n\n'
	fi
}

npm_prefix_is_writable() {
	npm_prefix_dir="$1"
	relay_dir_is_writable "$npm_prefix_dir/lib/node_modules" || return 1
	relay_dir_is_writable "$npm_prefix_dir/bin"
}

# Whether npm could create or write to this folder: the folder itself when it
# exists, otherwise the nearest folder above it that does.
relay_dir_is_writable() {
	writable_target="$1"
	while [ ! -e "$writable_target" ]; do
		writable_parent=$(dirname "$writable_target")
		[ "$writable_parent" != "$writable_target" ] || return 1
		writable_target="$writable_parent"
	done
	[ -d "$writable_target" ] && [ -w "$writable_target" ]
}

relay_display_path() {
	case "$1" in
		"${HOME:-/nonexistent}"/*) printf '~/%s' "${1#"$HOME"/}" ;;
		*) printf '%s' "$1" ;;
	esac
}

print_user_npm_prefix_note() {
	printf 'Relay is installed in %s, a folder this account owns, because\n' "$(relay_display_path "$relay_user_npm_prefix")"
	printf 'npm'"'"'s global folder (%s) is not writable without sudo.\n' "$relay_system_npm_prefix"
	printf '"%s update" keeps updating this copy. npm'"'"'s settings were not changed.\n\n' "$relay_cmd"
}

# Where npm put the command: Relay's own folder when the installer chose it,
# otherwise npm's global bin folder. `npm bin -g` is gone since npm 9.
relay_npm_bin_dir() {
	if [ -n "$relay_user_npm_prefix" ]; then
		printf '%s/bin' "$relay_user_npm_prefix"
		return 0
	fi
	npm_bin_prefix=$(npm prefix -g 2>/dev/null) || return 1
	[ -n "$npm_bin_prefix" ] || return 1
	printf '%s/bin' "$npm_bin_prefix"
}

# The last thing a working install prints: a welcome, and what to do next. Only a
# model connection is needed, and running the command walks through it; the Relay
# account is optional, and `login` is the terminal's way to it. The two are named
# apart, because both are called signing in.
print_relay_welcome() {
	if [ "$relay_screen_enabled" = 1 ]; then
		relay_screen "Welcome to Relay" "" "Relay is installed. What to do next is below." ""
		relay_restore_terminal
	else
		printf '\nWelcome to Relay. It is installed.\n'
	fi
	print_retired_alias_note
	relay_welcome_width=$((${#relay_cmd} + 6))
	printf '\nNext\n'
	printf '  cd your-project\n'
	printf '  %-*s  %s\n' "$relay_welcome_width" "$relay_cmd" "connect a model and start coding"
	printf '\nOptional\n'
	printf '  %-*s  %s\n' "$relay_welcome_width" "$relay_cmd login" "sign this machine in to your Relay account"
	print_relay_claude_plan_reminder
}

# Relay 0.6.103 replaced its old Claude Pro/Max sign-in with the Claude plan
# route, which signs in through Anthropic's own Claude Code. A machine that still
# has the old sign-in stored (or whose first start has not said so yet) is told
# in one line how to keep its Claude plan. Only the shape of auth.json is read:
# whether the "anthropic" entry is a sign-in ("type": "oauth"), never a value.
relay_has_old_claude_sign_in() {
	relay_agent_dir="${RELAY_CODING_AGENT_DIR:-$HOME/.relay/agent}"
	relay_auth_file="$relay_agent_dir/auth.json"
	if [ -f "$relay_auth_file" ] &&
		tr -d ' \t\r\n' <"$relay_auth_file" 2>/dev/null | grep -q '"anthropic":{"type":"oauth"'; then
		return 0
	fi
	relay_removed_file="$relay_agent_dir/anthropic-sign-in-removed.json"
	[ -f "$relay_removed_file" ] &&
		tr -d ' \t\r\n' <"$relay_removed_file" 2>/dev/null | grep -q '"noticeShown":false'
}

print_relay_claude_plan_reminder() {
	relay_has_old_claude_sign_in || return 0
	printf '\nYour old Claude Pro/Max sign-in was replaced. Run `%s login claude` once to keep using your Claude plan, or start %s and it will ask.\n' "$relay_cmd" "$relay_cmd"
}

create_temp_dir() {
	if command -v mktemp >/dev/null 2>&1; then
		if tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/relay-install.XXXXXX" 2>/dev/null); then
			printf '%s' "$tmp_dir"
			return
		fi
	fi

	printf 'error: mktemp is required to create a secure temporary directory.\n' >&2
	exit 1
}

relay_install_traps() {
	trap 'relay_cleanup' EXIT
	trap 'relay_signal_cleanup 130' INT
	trap 'relay_signal_cleanup 143' TERM
}

relay_cleanup() {
	status=$?
	if [ -n "${relay_download_dir:-}" ] && [ -d "$relay_download_dir" ]; then
		rm -rf "$relay_download_dir"
	fi
	relay_restore_terminal
	relay_send_count "$status" || :
	return "$status"
}

relay_signal_cleanup() {
	relay_count_signalled="$1"
	relay_restore_terminal
	exit "$1"
}

# ── The anonymous count (D-72) ──────────────────────────────────────────────
# One count when the installer ends: relay.installed (NEW, or REINSTALL when relay was here before), or relay.blocked
# with the step that failed. It names the install by the sha256 of the id in <agent dir>/telemetry.json, which it
# creates in Relay's own shape when there is none, so the installed Relay reuses it; the id never leaves the machine.
# It carries the Relay version and the OS family, nothing else. DO_NOT_TRACK=1, RELAY_TELEMETRY=0, RELAY_OFFLINE=1 or
# telemetry turned off in Relay's settings send nothing; RELAY_COUNTS_URL replaces the address (empty sends nothing).
# It never changes the exit code or what is printed, except one line after a count was sent. Ctrl+C sends
# INSTALL_CANCELLED in the background, detached, and the installer exits at once without waiting or printing; a TERM
# sends nothing.

relay_count_flag_on() {
	case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
		1|true|yes|on) return 0 ;;
	esac
	return 1
}

relay_count_flag_off() {
	case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
		0|false|no|off) return 0 ;;
	esac
	return 1
}

relay_count_agent_dir() {
	if [ -n "${RELAY_CODING_AGENT_DIR:-}" ]; then
		case "$RELAY_CODING_AGENT_DIR" in
			"~") [ -n "${HOME:-}" ] || return 1; printf '%s' "$HOME" ;;
			"~/"*) [ -n "${HOME:-}" ] || return 1; printf '%s/%s' "$HOME" "${RELAY_CODING_AGENT_DIR#??}" ;;
			*) printf '%s' "$RELAY_CODING_AGENT_DIR" ;;
		esac
		return 0
	fi
	[ -n "${HOME:-}" ] || return 1
	printf '%s/.relay/agent' "$HOME"
}

relay_counts_url() {
	relay_count_url="${RELAY_COUNTS_URL-https://relayevals.com/api/t}"
	[ -n "$relay_count_url" ] || return 1
	printf '%s' "$relay_count_url"
}

# The same switches, in the same order, as Relay's own isTelemetryEnabled.
relay_counts_enabled() {
	relay_count_flag_on "${RELAY_OFFLINE:-${PI_OFFLINE:-}}" && return 1
	relay_count_flag_on "${DO_NOT_TRACK:-}" && return 1
	relay_count_flag_off "${RELAY_TELEMETRY:-}" && return 1
	relay_counts_url >/dev/null || return 1
	command -v curl >/dev/null 2>&1 || return 1
	relay_count_flag_on "${RELAY_TELEMETRY:-}" && return 0
	relay_count_dir=$(relay_count_agent_dir) || return 0
	if [ -f "$relay_count_dir/settings.json" ] &&
		tr -d ' \t\r\n' <"$relay_count_dir/settings.json" 2>/dev/null | grep -q '"telemetry":{[^}]*"enabled":false'; then
		return 1
	fi
	return 0
}

# Whether relay was installed here before: on PATH, or an install id already written.
relay_count_note_prior_install() {
	if command -v "$relay_cmd" >/dev/null 2>&1; then
		relay_count_kind=REINSTALL
	elif relay_count_dir=$(relay_count_agent_dir) && [ -f "$relay_count_dir/telemetry.json" ]; then
		relay_count_kind=REINSTALL
	fi
	return 0
}

relay_count_is_uuid() {
	printf '%s' "$1" | grep -Eiq '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
}

relay_count_new_uuid() {
	relay_count_uuid=
	if [ -r /proc/sys/kernel/random/uuid ]; then
		relay_count_uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null) || relay_count_uuid=
	fi
	if [ -z "$relay_count_uuid" ] && command -v uuidgen >/dev/null 2>&1; then
		relay_count_uuid=$(uuidgen 2>/dev/null) || relay_count_uuid=
	fi
	if [ -z "$relay_count_uuid" ] && [ -r /dev/urandom ] && command -v od >/dev/null 2>&1; then
		relay_count_hex=$(od -An -N16 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n')
		relay_count_uuid=$(printf '%s' "$relay_count_hex" |
			sed 's/^\(.\{8\}\)\(.\{4\}\).\(.\{3\}\).\(.\{3\}\)\(.\{12\}\)$/\1-\2-4\3-a\4-\5/')
	fi
	relay_count_uuid=$(printf '%s' "$relay_count_uuid" | tr '[:upper:]' '[:lower:]')
	relay_count_is_uuid "$relay_count_uuid" || return 1
	printf '%s' "$relay_count_uuid"
}

# The install id Relay keeps in <agent dir>/telemetry.json, created in Relay's shape (0600) when there is none.
relay_count_install_id() {
	relay_count_dir="$1"
	relay_count_file="$relay_count_dir/telemetry.json"
	if [ -L "$relay_count_file" ]; then
		return 1
	fi
	if [ -e "$relay_count_file" ]; then
		[ -f "$relay_count_file" ] || return 1
		relay_count_state=$(tr -d ' \t\r\n' <"$relay_count_file" 2>/dev/null) || relay_count_state=
		relay_count_existing=$(printf '%s' "$relay_count_state" |
			sed -n 's/.*"installationId":"\([0-9A-Fa-f-]*\)".*/\1/p')
		if printf '%s' "$relay_count_state" | grep -q '"version":1[,}]' && relay_count_is_uuid "$relay_count_existing"; then
			printf '%s' "$relay_count_existing"
			return 0
		fi
	fi
	relay_count_new=$(relay_count_new_uuid) || return 1
	mkdir -p "$relay_count_dir" 2>/dev/null || return 1
	relay_count_temp="$relay_count_file.$$.tmp"
	if ! (umask 077 && printf '{\n  "version": 1,\n  "installationId": "%s"\n}' "$relay_count_new" >"$relay_count_temp") 2>/dev/null; then
		rm -f "$relay_count_temp" 2>/dev/null
		return 1
	fi
	if ! mv -f "$relay_count_temp" "$relay_count_file" 2>/dev/null; then
		rm -f "$relay_count_temp" 2>/dev/null
		return 1
	fi
	printf '%s' "$relay_count_new"
}

# Lowercase sha256 hex of the exact id, no newline: what Relay sends as the producer.
relay_count_sha256() {
	if command -v sha256sum >/dev/null 2>&1; then
		relay_count_digest=$(printf '%s' "$1" | sha256sum 2>/dev/null) || return 1
	elif command -v shasum >/dev/null 2>&1; then
		relay_count_digest=$(printf '%s' "$1" | shasum -a 256 2>/dev/null) || return 1
	else
		return 1
	fi
	relay_count_digest=${relay_count_digest%% *}
	printf '%s' "$relay_count_digest" | grep -Eq '^[0-9a-f]{64}$' || return 1
	printf '%s' "$relay_count_digest"
}

relay_count_platform() {
	case "$(uname -s 2>/dev/null)" in
		Darwin) printf 'darwin' ;;
		Linux) printf 'linux' ;;
		MINGW*|MSYS*|CYGWIN*) printf 'win32' ;;
		*) printf 'other' ;;
	esac
}

#   $1 the installer's exit status
relay_send_count() {
	relay_count_status="$1"
	relay_count_detached=0
	if [ "$relay_count_signalled" = 130 ]; then
		relay_count_name=relay.blocked
		relay_count_code=INSTALL_CANCELLED
		relay_count_detached=1
	elif [ "$relay_count_signalled" != 0 ]; then
		return 0
	elif [ "$relay_count_status" -ne 0 ]; then
		relay_count_name=relay.blocked
		relay_count_code="$relay_count_step"
	elif [ -n "$relay_count_outcome" ]; then
		relay_count_name=relay.blocked
		relay_count_code="$relay_count_outcome"
	elif [ "$relay_count_finished" = 1 ]; then
		relay_count_name=relay.installed
		relay_count_code="$relay_count_kind"
	else
		return 0
	fi
	relay_counts_enabled || return 0
	relay_count_target=$(relay_counts_url) || return 0
	relay_count_dir=$(relay_count_agent_dir) || return 0
	relay_count_id=$(relay_count_install_id "$relay_count_dir") || return 0
	relay_count_producer=$(relay_count_sha256 "$relay_count_id") || return 0
	case "$relay_count_version" in
		""|*[!0-9A-Za-z.+-]*) relay_count_version=unknown ;;
	esac
	[ "${#relay_count_version}" -le 32 ] || relay_count_version=unknown
	relay_count_body=$(printf '{"events":[{"producer":"%s","name":"%s","version":"%s","platform":"%s","code":"%s"}]}' \
		"$relay_count_producer" "$relay_count_name" "$relay_count_version" "$(relay_count_platform)" "$relay_count_code")
	if [ "$relay_count_detached" = 1 ]; then
		# Ctrl+C: the person is leaving, so nothing waits for this and nothing more is printed.
		(
			trap '' HUP INT TERM
			exec curl -fs -m 3 -o /dev/null -X POST -H 'content-type: application/json' --data "$relay_count_body" \
				"$relay_count_target"
		) </dev/null >/dev/null 2>&1 &
		return 0
	fi
	if curl -fs -m 3 -o /dev/null -X POST -H 'content-type: application/json' --data "$relay_count_body" \
		"$relay_count_target" >/dev/null 2>&1; then
		printf 'Sent one anonymous count: installed, or the step that failed. DO_NOT_TRACK=1 skips it.\n'
	fi
	return 0
}

relay_restore_terminal() {
	if [ "${relay_screen_enabled:-0}" = 1 ]; then
		if ( : <>/dev/tty ) 2>/dev/null; then
			printf '%s%s' "$relay_reset" "$relay_show_cursor" >/dev/tty
		else
			printf '%s%s' "$relay_reset" "$relay_show_cursor" >&2
		fi
	fi
}

relay_init_screen() {
	if [ "${RELAY_INSTALLER_PLAIN:-0}" = 1 ]; then
		return
	fi
	if [ ! -t 1 ]; then
		return
	fi
	if [ "${TERM:-}" = dumb ]; then
		return
	fi
	relay_screen_enabled=1
}

relay_read_terminal_size() {
	relay_screen_cols=80
	relay_screen_rows=24

	if size=$(stty size 2>/dev/null </dev/tty); then
		set -- $size
		if [ "${1:-}" ] && [ "${2:-}" ]; then
			case "$1" in *[!0-9]*|"") ;; *) relay_screen_rows="$1" ;; esac
			case "$2" in *[!0-9]*|"") ;; *) relay_screen_cols="$2" ;; esac
		fi
	fi

	if [ "$relay_screen_cols" -lt 1 ]; then
		relay_screen_cols=80
	fi
	if [ "$relay_screen_rows" -lt 1 ]; then
		relay_screen_rows=24
	fi
}

relay_screen() {
	if [ "$relay_screen_enabled" != 1 ]; then
		return
	fi

	relay_screen_title="${2:-$1}"
	if [ -z "$relay_screen_title" ]; then
		relay_screen_title="$1"
	fi
	relay_screen_status=
	relay_screen_detail="${3:-}"
	relay_screen_question="${4:-}"
	relay_screen_frame=$((relay_screen_frame + 1))
	relay_read_terminal_size
	relay_init_screen_layout
	relay_refresh_screen_layout_mode

	if [ "$relay_screen_drawn" = 0 ] ||
		[ "$relay_screen_cols" -ne "$relay_screen_last_cols" ] ||
		[ "$relay_screen_rows" -ne "$relay_screen_last_rows" ]; then
		relay_screen_prefix="${relay_reset}${relay_clear_screen}${relay_hide_cursor}"
		relay_screen_drawn=1
		relay_screen_last_cols="$relay_screen_cols"
		relay_screen_last_rows="$relay_screen_rows"
	else
		relay_screen_prefix="${relay_reset}${relay_home_cursor}${relay_hide_cursor}"
	fi
	relay_screen_frame_text=$(relay_render_screen)

	if ( : <>/dev/tty ) 2>/dev/null; then
		printf '%s%s%s%s' "$relay_sync_start" "$relay_screen_prefix" "$relay_screen_frame_text" "$relay_sync_end" >/dev/tty
	else
		printf '%s%s%s%s' "$relay_sync_start" "$relay_screen_prefix" "$relay_screen_frame_text" "$relay_sync_end" >&2
	fi
}

relay_init_screen_layout() {
	if [ "$relay_screen_layout_ready" = 1 ]; then
		return
	fi

	relay_screen_layout_ready=1
	relay_screen_layout_show_logo=0
	relay_screen_layout_lab_width=0
	relay_screen_render_lab_width=0
	if relay_terminal_size_supports_logo; then
		relay_screen_layout_show_logo=1
		relay_screen_layout_lab_width=$(relay_lab_width_for_cols "$relay_screen_cols")
	fi
}

relay_refresh_screen_layout_mode() {
	relay_screen_compact=0
	relay_screen_render_lab_width=0
	if [ "$relay_screen_layout_show_logo" != 1 ]; then
		return
	fi
	if [ "$relay_screen_rows" -lt 17 ]; then
		relay_screen_compact=1
		return
	fi

	max_safe_width=$((relay_screen_cols - 1))
	if [ "$max_safe_width" -lt 32 ]; then
		relay_screen_compact=1
		return
	fi

	relay_screen_render_lab_width="$relay_screen_layout_lab_width"
	if [ "$relay_screen_render_lab_width" -gt "$max_safe_width" ]; then
		relay_screen_render_lab_width="$max_safe_width"
	fi
}

relay_terminal_size_supports_logo() {
	[ "$relay_screen_rows" -ge 22 ] && [ "$relay_screen_cols" -ge 42 ]
}

relay_lab_width_for_cols() {
	cols="$1"
	width=$((cols - 6))
	if [ "$width" -gt 78 ]; then
		width=78
	fi
	if [ "$width" -lt 42 ]; then
		width=42
	fi
	max_safe_width=$((cols - 1))
	if [ "$max_safe_width" -lt 1 ]; then
		max_safe_width=1
	fi
	if [ "$width" -gt "$max_safe_width" ]; then
		width="$max_safe_width"
	fi
	if [ "$width" -lt 32 ]; then
		width=32
	fi
	printf '%s' "$width"
}

relay_render_screen() {
	content_height=$(relay_content_height)
	top=$(((relay_screen_rows - content_height) / 2))
	if [ "$top" -lt 0 ]; then
		top=0
	fi

	y=0
	while [ "$y" -lt "$relay_screen_rows" ]; do
		content_index=$((y - top))
		relay_content_line "$content_index"
		if [ "${relay_content_is_set:-0}" = 1 ]; then
			relay_print_centered_line "$relay_content_text" "$relay_content_width" "$relay_content_style"
		else
			relay_print_centered_line "" 0 ""
		fi
		y=$((y + 1))
	done
}

relay_content_height() {
	height=2
	if relay_show_logo; then
		height=$((height + 15))
	fi
	printf '%s' "$height"
}

relay_show_logo() {
	[ "$relay_screen_layout_show_logo" = 1 ] && [ "$relay_screen_compact" != 1 ] && [ "$relay_screen_render_lab_width" -ge 32 ]
}

relay_content_line() {
	index="$1"
	relay_content_is_set=0
	relay_content_text=
	relay_content_width=0
	relay_content_style=

	if relay_show_logo; then
		case "$index" in
			0|1|2|3|4|5|6|7|8|9|10|11|12|13) relay_set_lab_line "$index" ;;
			14) relay_set_blank_line ;;
		esac
		if [ "$relay_content_is_set" = 1 ]; then
			return
		fi
		index=$((index - 15))
	fi

	if [ "$index" -lt 0 ]; then
		return
	fi

	if [ "$index" -eq 0 ]; then
		if [ -n "$relay_screen_question" ]; then
			relay_set_text_line "$(relay_screen_primary_text)" "$relay_bold$relay_color_text"
		else
			relay_set_title_line "$relay_screen_title"
		fi
		return
	fi

	if [ "$index" -eq 1 ]; then
		if [ -n "$relay_screen_question" ]; then
			relay_set_text_line "Press Enter to continue; type n to cancel." "$relay_color_muted"
		elif [ -n "$relay_screen_detail" ]; then
			relay_set_text_line "$relay_screen_detail" "$relay_color_muted"
		else
			relay_set_blank_line
		fi
		return
	fi
}

relay_screen_primary_text() {
	if [ -z "$relay_screen_question" ]; then
		printf '%s' "$relay_screen_title"
		return
	fi

	case "$relay_screen_question" in
		*'[Y/n]'*) printf '%s [Y/n] >' "$relay_screen_title" ;;
		*) printf '%s %s' "$relay_screen_title" "$relay_screen_question" ;;
	esac
}

relay_set_lab_line() {
	lab_row="$1"
	relay_lab_width="$relay_screen_render_lab_width"

	logo_line=$(relay_logo_line "$lab_row")
	if [ -n "$logo_line" ]; then
		logo_start=$(((relay_lab_width - 32) / 2))
		logo_end=$((logo_start + 32))
		left=$(relay_lab_background_range "$lab_row" 0 "$logo_start")
		right=$(relay_lab_background_range "$lab_row" "$logo_end" "$relay_lab_width")
		trace="${left}${relay_color_text}${logo_line}${relay_reset}${right}"
	else
		trace=$(relay_lab_background_range "$lab_row" 0 "$relay_lab_width")
	fi

	relay_content_is_set=1
	relay_content_text="$trace"
	relay_content_width="$relay_lab_width"
	relay_content_style=
}

relay_logo_line() {
	# The Relay mark, rendered from apps/web/public/uploads/relay-logo.png by
	# scripts/render-logo.py's half-block encoding: two pixel rows per character.
	# Every line is padded to exactly 32 columns because the caller places the
	# particle field at a fixed offset either side of it, so a short line would
	# pull the right-hand edge of the frame inwards.
	case "$1" in
		4) printf '   ▄▄██████████████████████▄▄   ' ;;
		5) printf ' ▄██▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀██▄ ' ;;
		6) printf '▄██                          ▀█▄' ;;
		7) printf '▀██                          ▄█▀' ;;
		8) printf ' ▀██▄                      ▄██▀ ' ;;
		9) printf '   ▀▀████████  ▀▀  ████████▀▀   ' ;;
	esac
}

relay_lab_background_range() {
	lab_row="$1"
	range_start="$2"
	range_end="$3"
	active_style=
	line=
	x="$range_start"
	while [ "$x" -lt "$range_end" ]; do
		relay_lab_cell "$x" "$lab_row"
		if [ "$relay_lab_cell_style" != "$active_style" ]; then
			if [ -n "$active_style" ]; then
				line="${line}${relay_reset}"
			fi
			if [ -n "$relay_lab_cell_style" ]; then
				line="${line}${relay_lab_cell_style}"
			fi
			active_style="$relay_lab_cell_style"
		fi
		line="${line}${relay_lab_cell_char}"
		x=$((x + 1))
	done
	if [ -n "$active_style" ]; then
		line="${line}${relay_reset}"
	fi
	printf '%s' "$line"
}

relay_lab_cell() {
	# The background is four lanes with something travelling them.
	#
	# What was here before was a particle field with oscilloscope traces and scan
	# bars — the visual vocabulary every AI product reaches for. It said nothing
	# about Relay.
	#
	# A relay is a thing handed along a line. So: lanes, a packet running each one,
	# and the mark sitting across the middle of them. The lanes are not drawn inside
	# the mark's columns (the caller renders the background either side of it), so a
	# packet arrives at the carabiner, disappears into it, and comes out the far
	# side — the handoff, drawn rather than described.
	x="$1"
	y="$2"
	width="$relay_lab_width"
	frame="$relay_screen_frame"
	relay_lab_cell_char=" "
	relay_lab_cell_style=

	# Six lanes, symmetric about the mark: two thread it at rows 5 and 8, and two
	# run clear above and below. Every other row is left empty so the bus reads as
	# lines rather than as a texture.
	case "$y" in
		1) lane=0 ;;
		3) lane=1 ;;
		5) lane=2 ;;
		8) lane=3 ;;
		10) lane=4 ;;
		12) lane=5 ;;
		*) return ;;
	esac

	# The rail. Dotted and dim: a track the eye can follow without competing with
	# the mark, which is the only thing on this screen anyone needs to look at.
	if [ $(((x + lane) % 4)) -eq 0 ]; then
		relay_lab_cell_char="·"
		relay_lab_cell_style="$relay_color_dim"
	fi

	# The packet. Each lane carries its own phase and one of two speeds, so the
	# four never fall into step and march across as a block.
	# The two lanes that reach the mark run at the slowest step, so the eye can
	# follow a packet all the way to the clip. The outer four move faster and out
	# of phase, which is what keeps the six from marching as a block.
	if [ "$lane" -eq 2 ] || [ "$lane" -eq 3 ]; then
		speed=2
	else
		speed=$((3 + lane % 2))
	fi
	span=$((width + 28))
	head=$(((frame * speed + lane * 23) % span - 14))
	offset=$((x - head))

	case "$offset" in
		0)
			relay_lab_cell_char="▸"
			relay_lab_cell_style="$relay_color_primary"
			;;
		-1 | -2)
			relay_lab_cell_char="━"
			relay_lab_cell_style="$relay_color_primary"
			;;
		-3)
			relay_lab_cell_char="─"
			relay_lab_cell_style="$relay_color_scan"
			;;
		*)
			return
			;;
	esac

	# The clip. On the two lanes that reach the mark, the packet brightens in the
	# column where it meets it — the moment the carabiner takes the load.
	if [ "$lane" -eq 2 ] || [ "$lane" -eq 3 ]; then
		gate_left=$(((width - 32) / 2))
		gate_right=$((gate_left + 32))
		if [ "$offset" -eq 0 ] && [ "$x" -ge $((gate_left - 2)) ] && [ "$x" -le $((gate_right + 1)) ]; then
			relay_lab_cell_char="◆"
			relay_lab_cell_style="$relay_color_warning"
		fi
	fi
}

relay_set_blank_line() {
	relay_content_is_set=1
	relay_content_text=
	relay_content_width=0
	relay_content_style=
}

relay_set_text_line() {
	max_width=$((relay_screen_cols - 4))
	if [ "$max_width" -lt 1 ]; then
		max_width=1
	fi
	relay_content_text=$(relay_fit_ascii "$1" "$max_width")
	relay_content_width=${#relay_content_text}
	relay_content_style="$2"
	relay_content_is_set=1
}

relay_set_title_line() {
	max_width=$((relay_screen_cols - 4))
	if [ "$max_width" -lt 1 ]; then
		max_width=1
	fi
	relay_content_text=$(relay_fit_ascii "$1" "$max_width")
	relay_content_width=${#relay_content_text}
	case "$relay_content_text" in
		*"Relay"*)
			relay_content_text=$(relay_style_relay_title "$relay_content_text")
			relay_content_style=
			;;
		*)
			relay_content_style="$relay_bold$relay_color_primary"
			;;
	esac
	relay_content_is_set=1
}

relay_style_relay_title() {
	text="$1"
	styled=
	while :; do
		case "$text" in
			*"Relay"*)
				before=${text%%Relay*}
				rest=${text#*Relay}
				styled="${styled}${relay_bold}${relay_color_primary}${before}"
				styled="${styled}${relay_bold}${relay_color_primary}Relay${relay_reset}"
				text="$rest"
				;;
			*)
				styled="${styled}${relay_bold}${relay_color_primary}${text}${relay_reset}"
				printf '%s' "$styled"
				return
				;;
		esac
	done
}

relay_fit_ascii() {
	text="$1"
	max_width="$2"
	if [ "${#text}" -le "$max_width" ]; then
		printf '%s' "$text"
		return
	fi
	if [ "$max_width" -le 3 ]; then
		printf '%s' "$text" | cut -c 1-"$max_width"
		return
	fi
	cut_width=$((max_width - 3))
	printf '%s...' "$(printf '%s' "$text" | cut -c 1-"$cut_width")"
}

relay_print_centered_line() {
	text="$1"
	width="$2"
	style="$3"
	left=$(((relay_screen_cols - width) / 2))
	if [ "$left" -lt 0 ]; then
		left=0
	fi
	if [ -n "$style" ]; then
		printf '%*s%s%s%s%s\n' "$left" "" "$style" "$text" "$relay_reset" "$relay_clear_line"
	else
		printf '%*s%s%s\n' "$left" "" "$text" "$relay_clear_line"
	fi
}

relay_place_prompt_cursor() {
	max_width=$((relay_screen_cols - 4))
	if [ "$max_width" -lt 1 ]; then
		max_width=1
	fi
	prompt_text=$(relay_fit_ascii "$(relay_screen_primary_text)" "$max_width")
	prompt_width=${#prompt_text}
	content_height=$(relay_content_height)
	top=$(((relay_screen_rows - content_height) / 2))
	if [ "$top" -lt 0 ]; then
		top=0
	fi
	prompt_index=0
	if relay_show_logo; then
		prompt_index=$((prompt_index + 15))
	fi
	row=$((top + prompt_index + 1))
	col=$(((relay_screen_cols - prompt_width) / 2 + prompt_width + 2))
	if [ "$col" -lt 1 ]; then
		col=1
	fi
	if [ "$col" -gt "$relay_screen_cols" ]; then
		col="$relay_screen_cols"
	fi
	if ( : <>/dev/tty ) 2>/dev/null; then
		printf '%s%s%s[%s;%sH' "$relay_reset" "$relay_show_cursor" "$relay_esc" "$row" "$col" >/dev/tty
	else
		printf '%s%s%s[%s;%sH' "$relay_reset" "$relay_show_cursor" "$relay_esc" "$row" "$col" >&2
	fi
}

relay_pulse() {
	case $((relay_screen_frame % 4)) in
		0) printf '.' ;;
		1) printf '..' ;;
		2) printf '...' ;;
		*) printf '' ;;
	esac
}

relay_animation_detail_count() {
	details="$1"
	case "$details" in
		*'
'*) printf '%s\n' "$details" | wc -l | tr -d ' ' ;;
		*) printf '1' ;;
	esac
}

relay_animation_current_frame() {
	frame="${relay_animation_frame:-1}"
	case "$frame" in
		""|*[!0-9]*) frame=1 ;;
	esac
	if [ "$frame" -lt 1 ]; then
		frame=1
	fi
	printf '%s' "$frame"
}

relay_animation_step_index() {
	details="$1"
	detail_count=$(relay_animation_detail_count "$details")
	frame=$(relay_animation_current_frame)
	detail_index=$(((frame - 1) / 24 + 1))
	if [ "$detail_index" -gt "$detail_count" ]; then
		detail_index="$detail_count"
	fi
	printf '%s' "$detail_index"
}

relay_static_progress_title() {
	case "$1" in
		*...) printf '%s' "$1" ;;
		*) printf '%s...' "$1" ;;
	esac
}

relay_animation_status() {
	status="$1"
	details="$2"
	status_mode="$3"
	case "$status_mode" in
		static) relay_static_progress_title "$status" ;;
		*) printf '%s%s' "$status" "$(relay_pulse)" ;;
	esac
}

relay_animation_detail() {
	details="$1"
	case "$details" in
		*'
'*)
			detail_index=$(relay_animation_step_index "$details")
			printf '%s\n' "$details" | sed -n "${detail_index}p"
			;;
		*) printf '%s' "$details" ;;
	esac
}

relay_run_quiet_with_animation() {
	title="$1"
	status="$2"
	detail="$3"
	shift 3

	relay_run_quiet_with_animation_command "$title" "$status" "$detail" pulse "$@"
}

relay_run_quiet_with_animation_steps() {
	title="$1"
	status="$2"
	details="$3"
	shift 3

	relay_run_quiet_with_animation_command "$title" "$status" "$details" static "$@"
}

relay_run_quiet_with_animation_command() {
	title="$1"
	status="$2"
	details="$3"
	status_mode="$4"
	shift 4

	if [ "$relay_screen_enabled" != 1 ]; then
		printf '%s\n' "$status" >&2
		"$@"
		return
	fi

	output_dir=$(create_temp_dir)
	output_file="$output_dir/output"
	"$@" >"$output_file" 2>&1 &
	command_pid=$!
	relay_animation_frame=0

	while kill -0 "$command_pid" 2>/dev/null; do
		relay_animation_frame=$((relay_animation_frame + 1))
		status_display=$(relay_animation_status "$status" "$details" "$status_mode")
		relay_screen "$title" "$status_display" "$(relay_animation_detail "$details")" ""
		sleep 0.18
	done

	if wait "$command_pid"; then
		command_status=0
	else
		command_status=$?
	fi

	if [ "$command_status" -ne 0 ] && [ -s "$output_file" ]; then
		relay_restore_terminal
		printf '\n' >&2
		cat "$output_file" >&2
	fi
	rm -rf "$output_dir"
	return "$command_status"
}

relay_prompt_yes_no() {
	question="$1"
	detail="$2"
	input_prompt="$3"

	if ( : <>/dev/tty ) 2>/dev/null; then
		prompt_input=tty
		exec 3<>/dev/tty
	elif [ -t 0 ]; then
		prompt_input=stdin
	else
		return 2
	fi

	if [ "$relay_screen_enabled" = 1 ]; then
		relay_screen "$question" "" "$detail" "$input_prompt"
		relay_place_prompt_cursor "$input_prompt"
	else
		printf '%s\n' "$detail"
		if [ "$prompt_input" = tty ]; then
			printf '%s ' "$input_prompt" >&3
		else
			printf '%s ' "$input_prompt" >&2
		fi
	fi

	if [ "$prompt_input" = tty ]; then
		if ! IFS= read -r answer <&3; then
			answer=
		fi
		exec 3>&-
	else
		if ! IFS= read -r answer; then
			answer=
		fi
	fi

	case "$answer" in
		n|N|no|NO)
			return 1
			;;
	esac
	return 0
}

start_preflight_checks() {
	preflight_dir=$(create_temp_dir)
	preflight_file="$preflight_dir/preflight"
	run_preflight_checks >"$preflight_file" &
	preflight_pid=$!
}

finish_preflight_checks() {
	if [ "$relay_screen_enabled" = 1 ]; then
		while kill -0 "$preflight_pid" 2>/dev/null; do
			relay_screen "Checking Node.js and npm$(relay_pulse)" "" "" ""
			sleep 0.18
		done
	fi

	if wait "$preflight_pid"; then
		preflight_status=0
	else
		preflight_status=$?
	fi

	if [ "$relay_screen_enabled" = 1 ]; then
		if [ "$preflight_status" -ne 0 ]; then
			preflight_summary=$(sed -n '1p' "$preflight_file")
			relay_screen "Node.js $relay_min_node or newer is required" "" "$preflight_summary" ""
			sleep 0.4
		elif [ -s "$preflight_file" ]; then
			preflight_summary="Existing $relay_cmd command found on PATH."
			relay_screen "Environment ready" "" "$preflight_summary" ""
			sleep 0.4
		fi
	else
		cat "$preflight_file"
	fi
	rm -rf "$preflight_dir"
	return "$preflight_status"
}

run_preflight_checks() {
	status=0
	yellow="${relay_esc}[33m"
	reset="${relay_esc}[0m"

	if command -v node >/dev/null 2>&1; then
		node_version=$(node --version)
		if ! MIN_NODE="$relay_min_node" node -e 'const need = process.env.MIN_NODE.split(".").map(Number); const have = process.versions.node.split(".").map(Number); for (let i = 0; i < 3; i++) { if (have[i] !== need[i]) process.exit(have[i] > need[i] ? 0 : 1); } process.exit(0);' 2>/dev/null; then
			printf 'error: Relay requires Node.js %s or newer. Found %s.\n' "$relay_min_node" "$node_version"
			status=1
		fi
	else
		printf 'error: Node.js %s or newer is required to install Relay.\n' "$relay_min_node"
		status=1
	fi

	if ! command -v npm >/dev/null 2>&1; then
		printf 'error: npm is required to install Relay.\n'
		status=1
	fi

	if [ "$status" -ne 0 ]; then
		printf '\n'
	fi

	if relay_path=$(command -v "$relay_cmd" 2>/dev/null); then
		printf '%sExisting %s found at: %s%s\n' "$yellow" "$relay_cmd" "$relay_path" "$reset"
		printf '\n'
	fi

	return "$status"
}

resolve_relay_version() {
	if [ "${1:-}" ]; then
		case "$1" in
			stable|beta) release_channel="$1" ;;
			*)
				normalize_version "$1"
				return
				;;
		esac
	else
		release_channel="$relay_release_channel"
	fi

	if [ "${RELAY_VERSION:-}" ]; then
		normalize_version "$RELAY_VERSION"
		return
	fi

	if ! command -v curl >/dev/null 2>&1; then
		printf 'error: curl is required to resolve the latest Relay version.\n' >&2
		exit 1
	fi

	case "$release_channel" in
		stable|beta) ;;
		*)
			printf 'error: invalid Relay release channel: %s\n' "$release_channel" >&2
			exit 1
			;;
	esac

	channel_dir=$(create_temp_dir)
	channel_path="$channel_dir/$release_channel"
	if ! relay_run_quiet_with_animation \
		"Resolving latest release" \
		"Resolving latest release" \
		"Checking the $release_channel release channel." \
		curl -fsSL "$relay_base_url/$release_channel" -o "$channel_path"; then
		rm -rf "$channel_dir"
		printf 'error: could not resolve latest Relay version from %s/%s\n' "$relay_base_url" "$release_channel" >&2
		exit 1
	fi
	channel_version="$(tr -d '[:space:]' <"$channel_path")"
	rm -rf "$channel_dir"
	if [ -z "$channel_version" ]; then
		printf 'error: could not resolve latest Relay version from %s/%s\n' "$relay_base_url" "$release_channel" >&2
		exit 1
	fi
	normalize_version "$channel_version"
}

normalize_version() {
	version="${1#v}"
	case "$version" in
		"")
			printf 'error: empty Relay version.\n' >&2
			exit 1
			;;
		*[!0-9A-Za-z.-]*)
			printf 'error: invalid Relay version: %s\n' "$1" >&2
			exit 1
			;;
	esac
	printf '%s' "$version"
}

install_node_npm_interactive() {
	method=$(detect_node_install_method)
	case "$method" in
		homebrew) label="Homebrew" ;;
		apt) label="apt" ;;
		apk) label="apk" ;;
		standalone) label="standalone Node.js" ;;
		*)
			method=standalone
			label="standalone Node.js"
			;;
	esac

	if relay_prompt_yes_no \
		"Install Node.js and npm with $label?" \
		"Required before Relay can be installed." \
		"Install? [Y/n]"; then
		install_node_npm "$method" "$label"
		return
	else
		prompt_status=$?
	fi
	if [ "$prompt_status" -eq 2 ]; then
		printf 'No terminal detected; install Node.js %s or newer and npm, then run this installer again.\n' "$relay_min_node"
	else
		printf '\nInstall Node.js %s or newer and npm, then run this installer again.\n' "$relay_min_node"
	fi
	return 1
}

detect_node_install_method() {
	case "$(uname -s)" in
		Darwin)
			if command -v brew >/dev/null 2>&1; then
				printf 'homebrew'
			else
				printf 'standalone'
			fi
			;;
		Linux)
			if command -v apt-cache >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1 && apt_node_candidate_is_new_enough; then
				printf 'apt'
			elif command -v apk >/dev/null 2>&1 && apk_node_candidate_is_new_enough; then
				printf 'apk'
			else
				printf 'standalone'
			fi
			;;
		*)
			printf 'standalone'
			;;
	esac
}

apt_node_candidate_is_new_enough() {
	version=$(apt-cache policy nodejs 2>/dev/null | awk '/Candidate:/ { print $2; exit }')
	[ -n "$version" ] && [ "$version" != "(none)" ] && node_version_string_is_new_enough "$version"
}

apk_node_candidate_is_new_enough() {
	version=$(apk search -x nodejs 2>/dev/null | awk -F- '/^nodejs-/ { print $2; exit }')
	[ -n "$version" ] && node_version_string_is_new_enough "$version"
}

node_version_string_is_new_enough() {
	version="${1#v}"
	case "$version" in
		[0-9]*) ;;
		*) return 1 ;;
	esac
	version="${version%%[!0-9.]*}"
	version_ifs=${IFS- }
	IFS=.
	set -- $version
	IFS=$version_ifs
	major="${1:-}"
	minor="${2:-0}"
	patch="${3:-0}"
	case "$major" in ''|*[!0-9]*) return 1 ;; esac
	case "$minor" in ''|*[!0-9]*) minor=0 ;; esac
	case "$patch" in ''|*[!0-9]*) patch=0 ;; esac

	[ "$major" -gt "$relay_min_node_major" ] && return 0
	[ "$major" -lt "$relay_min_node_major" ] && return 1
	[ "$minor" -gt "$relay_min_node_minor" ] && return 0
	[ "$minor" -lt "$relay_min_node_minor" ] && return 1
	[ "$patch" -ge "$relay_min_node_patch" ] && return 0
	return 1
}

install_node_npm() {
	method="$1"
	label="$2"

	if [ "$relay_screen_enabled" != 1 ]; then
		printf '\nInstalling Node.js and npm with %s...\n\n' "$label"
		run_node_install_method "$method"
	else
		prepare_sudo_for_node_install "$method"
		node_install_details="Using $label.
Resolving Node.js packages.
Downloading Node.js runtime.
Installing npm.
Preparing Relay setup."
		relay_run_quiet_with_animation_steps \
			"Installing Node.js and npm" \
			"Installing Node.js and npm" \
			"$node_install_details" \
			run_node_install_method "$method"
	fi

	if [ "$method" = standalone ]; then
		load_standalone_node
		RELAY_NODE_INSTALLED_STANDALONE=1
	fi
	hash -r
	if [ "$relay_screen_enabled" = 1 ]; then
		relay_screen "Node.js and npm installed" "" "Continuing Relay setup." ""
	else
		printf '\nNode.js and npm are installed.\n\n'
	fi
}

node_install_needs_sudo() {
	if [ "${EUID:-$(id -u)}" -eq 0 ]; then
		return 1
	fi

	case "$1" in
		apt|apk)
			return 0
			;;
		standalone)
			[ "$(uname -s)" = Linux ] || return 1
			command -v xz >/dev/null 2>&1 && return 1
			command -v apt-get >/dev/null 2>&1 || command -v apk >/dev/null 2>&1
			;;
		*)
			return 1
			;;
	esac
}

prepare_sudo_for_node_install() {
	method="$1"
	if ! node_install_needs_sudo "$method"; then
		return 0
	fi

	relay_screen "Preparing Node.js install" "" "This may ask for your sudo password." ""
	relay_restore_terminal
	printf '\n'
	sudo -v
}

run_node_install_method() {
	case "$1" in
		homebrew) install_node_with_homebrew ;;
		apt) install_node_with_apt ;;
		apk) install_node_with_apk ;;
		standalone) install_node_standalone ;;
	esac
}

install_node_with_homebrew() {
	if brew list node >/dev/null 2>&1; then
		brew upgrade node
	else
		brew install node
	fi
}

install_node_with_apt() {
	print_sudo_note
	if [ "${EUID:-$(id -u)}" -eq 0 ]; then
		apt-get update
		apt-get install -y nodejs npm
	else
		sudo sh -c 'apt-get update && apt-get install -y nodejs npm'
	fi
}

install_node_with_apk() {
	print_sudo_note
	run_with_sudo apk add --update-cache nodejs npm
}

install_node_standalone() {
	node_platform=$(detect_node_binary_platform) || {
		printf 'Unsupported operating system for automatic Node.js install: %s\n' "$(uname -s)"
		return 1
	}
	node_arch=$(detect_node_binary_arch) || {
		printf 'Unsupported CPU architecture for automatic Node.js install: %s\n' "$(uname -m)"
		return 1
	}
	node_dist_base="https://nodejs.org/dist/latest-v22.x"
	node_base_dir=$(node_standalone_base_dir)
	node_tmp_dir=$(create_temp_dir)

	mkdir -p "$node_tmp_dir" "$node_base_dir"

	printf 'Resolving Node.js binary for %s-%s\n' "$node_platform" "$node_arch"
	curl -fsSL "$node_dist_base/SHASUMS256.txt" -o "$node_tmp_dir/SHASUMS256.txt"
	node_file=$(awk -v suffix="-$node_platform-$node_arch.tar.xz" '
		index($2, "node-v") == 1 && length($2) >= length(suffix) && substr($2, length($2) - length(suffix) + 1) == suffix { print $2; exit }
	' "$node_tmp_dir/SHASUMS256.txt")
	if [ -z "$node_file" ]; then
		printf 'No Node.js binary is available for %s-%s.\n' "$node_platform" "$node_arch"
		rm -rf "$node_tmp_dir"
		return 1
	fi
	case "$node_file" in
		*/*|*\\*|*..*)
			printf 'Unsafe Node.js archive name in checksum manifest: %s\n' "$node_file"
			rm -rf "$node_tmp_dir"
			return 1
			;;
		node-v*-"$node_platform"-"$node_arch".tar.xz) ;;
		*)
			printf 'Unexpected Node.js archive name in checksum manifest: %s\n' "$node_file"
			rm -rf "$node_tmp_dir"
			return 1
			;;
	esac

	printf 'Downloading Node.js %s\n' "${node_file%.tar.xz}"
	curl -fsSL "$node_dist_base/$node_file" -o "$node_tmp_dir/$node_file"
	verify_node_standalone_download "$node_tmp_dir" "$node_file"
	ensure_node_standalone_extract_tools "$node_platform"

	node_dir="$node_base_dir/${node_file%.tar.xz}"
	rm -rf "$node_dir"
	printf 'Extracting Node.js to %s\n' "$node_dir"
	tar -xf "$node_tmp_dir/$node_file" -C "$node_base_dir"
	rm -f "$node_base_dir/current"
	ln -s "$node_dir" "$node_base_dir/current"
	rm -rf "$node_tmp_dir"
	printf 'Node.js installed at %s\n' "$node_dir"
}

verify_node_standalone_download() {
	checksum_dir="$1"
	checksum_file_name="$2"
	awk -v file="$checksum_file_name" '$2 == file { print }' "$checksum_dir/SHASUMS256.txt" >"$checksum_dir/SHASUMS256.selected"

	if command -v sha256sum >/dev/null 2>&1; then
		printf 'Verifying Node.js download\n'
		(cd "$checksum_dir" && sha256sum -c SHASUMS256.selected)
	elif command -v shasum >/dev/null 2>&1; then
		printf 'Verifying Node.js download\n'
		(cd "$checksum_dir" && shasum -a 256 -c SHASUMS256.selected)
	else
		printf 'error: sha256sum or shasum is required to verify the Node.js download.\n'
		return 1
	fi
}

ensure_node_standalone_extract_tools() {
	extract_platform="$1"

	if [ "$extract_platform" = linux ] && ! command -v xz >/dev/null 2>&1; then
		printf 'Installing xz-utils for Node.js archive extraction\n'
		print_sudo_note
		if command -v apt-get >/dev/null 2>&1; then
			run_with_sudo apt-get update
			run_with_sudo apt-get install -y xz-utils
		elif command -v apk >/dev/null 2>&1; then
			run_with_sudo apk add --update-cache xz
		else
			printf 'xz is required to extract Node.js. Install xz and run this installer again.\n'
			return 1
		fi
	fi
}

load_standalone_node() {
	RELAY_STANDALONE_NODE_BIN="$(node_standalone_base_dir)/current/bin"
	PATH="$RELAY_STANDALONE_NODE_BIN:$PATH"
	export RELAY_STANDALONE_NODE_BIN PATH
}

node_standalone_base_dir() {
	if [ -n "${XDG_DATA_HOME:-}" ]; then
		printf '%s/relay-node' "$XDG_DATA_HOME"
	else
		printf '%s/.local/share/relay-node' "$HOME"
	fi
}

detect_node_binary_platform() {
	case "$(uname -s)" in
		Darwin) printf 'darwin' ;;
		Linux) printf 'linux' ;;
		*) return 1 ;;
	esac
}

detect_node_binary_arch() {
	case "$(uname -m)" in
		x86_64|amd64) printf 'x64' ;;
		arm64|aarch64) printf 'arm64' ;;
		armv7l) printf 'armv7l' ;;
		ppc64le) printf 'ppc64le' ;;
		s390x) printf 's390x' ;;
		*) return 1 ;;
	esac
}

print_sudo_note() {
	if [ "${EUID:-$(id -u)}" -ne 0 ]; then
		printf 'This may ask for your sudo password.\n\n'
	fi
}

run_with_sudo() {
	if [ "${EUID:-$(id -u)}" -eq 0 ]; then
		"$@"
	else
		sudo "$@"
	fi
}

# Put a bin folder this script installed into on the user's PATH: the standalone
# Node.js folder, Relay's own npm folder, or npm's global bin folder. Asks before
# it edits a shell profile; with no terminal to ask on, it prints the line to add.
#   $1 the bin folder, $2 what to call it, $3 the comment written above the line
configure_relay_path() {
	relay_path_bin="$1"
	relay_path_label="$2"
	relay_path_comment="$3"
	if original_relay_path=$(resolve_relay_with_original_path); then
		case "$original_relay_path" in
			"$relay_path_bin/"*)
				print_relay_welcome
				return 0
				;;
		esac
		if [ "$relay_screen_enabled" = 1 ]; then
			relay_screen "Relay installed" "" "PATH update needed for $relay_cmd." ""
		else
			printf '%s was installed in %s, but your shell is not using that install yet.\n' "$relay_cmd" "$relay_path_bin"
			printf 'Your shell currently resolves %s to: %s\n' "$relay_cmd" "$original_relay_path"
		fi
	else
		if [ "$relay_screen_enabled" = 1 ]; then
			relay_screen "Relay installed" "" "PATH update needed for $relay_cmd." ""
		else
			printf '%s was installed in %s, but your shell is not using that install yet.\n' "$relay_cmd" "$relay_path_bin"
		fi
	fi

	profile=$(detect_shell_profile) || {
		if [ "$relay_screen_enabled" = 1 ]; then
			relay_restore_terminal
			printf '\n'
		fi
		print_relay_path_manual_instructions
		return 0
	}

	if shell_profile_has_relay_path "$profile"; then
		if [ "$relay_screen_enabled" = 1 ]; then
			relay_screen "Relay installed" "" "Run: $(relay_source_profile_command "$profile")" ""
		else
			printf '%s already contains %s.\n' "$profile" "$relay_path_bin"
			printf 'Restart your shell or run: %s\n' "$(relay_source_profile_command "$profile")"
		fi
		return 0
	fi

	prompt_add_relay_path "$profile"
}

resolve_relay_with_original_path() {
	saved_path=$PATH
	PATH=$relay_original_path
	if command -v "$relay_cmd" 2>/dev/null; then
		status=0
	else
		status=$?
	fi
	PATH=$saved_path
	return "$status"
}

detect_shell_profile() {
	if [ -n "${RELAY_SHELL_PROFILE:-}" ]; then
		printf '%s' "$RELAY_SHELL_PROFILE"
		return 0
	fi
	if [ -z "${HOME:-}" ]; then
		return 1
	fi

	shell_name="${SHELL:-}"
	shell_name="${shell_name##*/}"
	case "$shell_name" in
		zsh)
			printf '%s/.zshrc' "${ZDOTDIR:-$HOME}"
			;;
		bash)
			printf '%s/.bashrc' "$HOME"
			;;
		*)
			if [ -f "$HOME/.zshrc" ]; then
				printf '%s/.zshrc' "$HOME"
			elif [ -f "$HOME/.bashrc" ]; then
				printf '%s/.bashrc' "$HOME"
			else
				printf '%s/.profile' "$HOME"
			fi
			;;
	esac
}

shell_profile_has_relay_path() {
	profile="$1"
	[ -f "$profile" ] && grep -F "$relay_path_bin" "$profile" >/dev/null 2>&1
}

prompt_add_relay_path() {
	profile="$1"
	path_line=$(relay_path_line)

	if ! relay_prompt_yes_no \
		"Add $relay_path_label to your PATH?" \
		"Updates $profile so future shells can run $relay_cmd." \
		"Update PATH? [Y/n]"; then
		if [ "$relay_screen_enabled" = 1 ]; then
			relay_restore_terminal
			printf '\n'
		fi
		print_relay_path_manual_instructions
		return 0
	fi

	mkdir -p "$(dirname "$profile")"
	{
		printf '\n# %s\n' "$relay_path_comment"
		printf '%s\n' "$path_line"
	} >>"$profile"
	if [ "$relay_screen_enabled" = 1 ]; then
		relay_screen "Relay installed" "" "Run: $(relay_source_profile_command "$profile")" ""
	else
		printf 'Added %s to %s.\n' "$relay_path_bin" "$profile"
		printf 'Restart your shell or run: %s\n' "$(relay_source_profile_command "$profile")"
	fi
}

print_relay_path_manual_instructions() {
	relay_count_outcome=INSTALL_NOT_ON_PATH
	printf 'Add this to your shell profile to use %s from new shells:\n\n' "$relay_cmd"
	printf '  %s\n' "$(relay_path_line)"
	printf '\nThen restart your shell and run: %s\n' "$relay_cmd"
}

relay_path_line() {
	printf 'export PATH="%s:$PATH"' "$relay_path_bin"
}

relay_shell_quote() {
	quoted=$(printf '%s' "$1" | sed "s/'/'\\\\''/g")
	printf "'%s'" "$quoted"
}

relay_source_profile_command() {
	printf '. %s && %s' "$(relay_shell_quote "$1")" "$relay_cmd"
}

download_relay_package() {
	version="$1"
	tarball_url="$2"
	tarball_path="$3"
	download_dir=$(dirname "$tarball_path")
	tarball_name=$(basename "$tarball_path")
	checksums_url="$relay_base_url/releases/v$version/SHA256SUMS"
	checksums_path="$download_dir/SHA256SUMS"

	if ! command -v curl >/dev/null 2>&1; then
		printf 'error: curl is required to download Relay.\n' >&2
		exit 1
	fi

	relay_run_quiet_with_animation \
		"Downloading checksums" \
		"Downloading release checksums" \
		"Relay v$version" \
		curl -fsSL "$checksums_url" -o "$checksums_path"

	relay_run_quiet_with_animation \
		"Downloading Relay" \
		"Downloading Relay v$version" \
		"Fetching the verified package." \
		curl -fsSL "$tarball_url" -o "$tarball_path"

	verify_relay_package_checksum "$checksums_path" "$tarball_path"
}

verify_relay_package_checksum() {
	relay_count_step=INSTALL_CHECKSUM
	checksums_path="$1"
	tarball_path="$2"
	checksum_dir=$(dirname "$tarball_path")
	tarball_name=$(basename "$tarball_path")
	selected_checksums_path="$checksum_dir/SHA256SUMS.selected"

	if ! awk -v file="$tarball_name" '$2 == file { print; found = 1; exit } END { if (!found) exit 1 }' \
		"$checksums_path" >"$selected_checksums_path"; then
		printf 'error: checksum for %s was not found in %s\n' "$tarball_name" "$checksums_path" >&2
		exit 1
	fi

	if command -v sha256sum >/dev/null 2>&1; then
		relay_run_quiet_with_animation \
			"Verifying download" \
			"Verifying Relay download" \
			"Checking SHA-256." \
			relay_run_checksum_check "$checksum_dir" "$(basename "$selected_checksums_path")" sha256sum
	elif command -v shasum >/dev/null 2>&1; then
		relay_run_quiet_with_animation \
			"Verifying download" \
			"Verifying Relay download" \
			"Checking SHA-256." \
			relay_run_checksum_check "$checksum_dir" "$(basename "$selected_checksums_path")" shasum
	else
		printf 'error: sha256sum or shasum is required to verify the Relay download.\n' >&2
		exit 1
	fi
}

relay_run_checksum_check() {
	checksum_dir="$1"
	selected_checksums_name="$2"
	checker="$3"
	case "$checker" in
		sha256sum)
			(cd "$checksum_dir" && sha256sum -c "$selected_checksums_name")
			;;
		shasum)
			(cd "$checksum_dir" && shasum -a 256 -c "$selected_checksums_name")
			;;
	esac
}

confirm_install() {
	version="$1"
	tarball_url="$2"

	install_question="Install Relay v$version globally with npm?"
	install_detail="Downloads the verified release and runs npm install -g."
	if [ -n "$relay_user_npm_prefix" ]; then
		install_question="Install Relay v$version for this user with npm?"
		install_detail="npm's global folder is not writable; installs into $(relay_display_path "$relay_user_npm_prefix")."
	fi

	if relay_prompt_yes_no \
		"$install_question" \
		"$install_detail" \
		"Install? [Y/n]"; then
		return 0
	else
		prompt_status=$?
	fi

	if [ "$prompt_status" -eq 2 ]; then
		printf 'This will download, verify, and install:\n\n  %s\n\n' "$tarball_url"
		printf 'No terminal detected; continuing without confirmation.\n'
		return 0
	fi

	relay_count_outcome=INSTALL_CANCELLED
	if [ "$relay_screen_enabled" = 1 ]; then
		relay_screen "Installation cancelled" "" "No changes were made." ""
		exit 0
	fi
	printf '\nInstallation cancelled.\n'
	exit 0
}

confirm_kernel_runtime_setup() {
	case "${RELAY_BOOTSTRAP_KERNEL_ON_INSTALL:-}" in
		1)
			relay_bootstrap_kernel_on_install=1
			return
			;;
		0)
			relay_bootstrap_kernel_on_install=0
			return
			;;
	esac

	if relay_prompt_yes_no \
		"Prepare Python runtime now?" \
		"Installs uv, Python 3.11, and the Relay runtime." \
		"Prepare? [Y/n]"; then
		relay_bootstrap_kernel_on_install=1
		return
	else
		prompt_status=$?
	fi

	if [ "$prompt_status" -eq 2 ]; then
		printf 'No terminal detected; preparing the Python runtime during install.\n'
		relay_bootstrap_kernel_on_install=1
		return
	fi

	relay_bootstrap_kernel_on_install=0
	if [ "$relay_screen_enabled" = 1 ]; then
		relay_screen "Python setup skipped" "" "The runtime can be prepared on first ipython use." ""
		sleep 0.4
	else
		printf '\nSkipping Python runtime setup.\n'
	fi
}

# Remove the `relay` symlink 0.6.81 and 0.6.82 created, so npm can take the name.
#
# Those releases made it themselves, beside the binary, because the command was
# `relay-worker` then. From 0.6.83 `relay` is declared in the package's own bin,
# and npm refuses to overwrite a file it did not create — so every install from
# those two releases is blocked on the way to any later one with:
#
#   npm error EEXIST: file already exists: <prefix>/bin/relay
#
# We put it there; we take it away. Only when it is a symlink pointing at
# relay-worker, which is the exact shape those installers left. A regular file,
# or a link into another program, is somebody else's and stays.
clear_stale_relay_alias() {
	relay_worker_path=$(command -v relay-worker 2>/dev/null) || return 0
	[ -n "$relay_worker_path" ] || return 0
	relay_alias="$(dirname "$relay_worker_path")/relay"
	[ -L "$relay_alias" ] || return 0
	relay_alias_target=$(readlink "$relay_alias" 2>/dev/null) || return 0
	case "$(basename "$relay_alias_target")" in
		relay-worker) ;;
		*) return 0 ;;
	esac
	rm -f "$relay_alias" 2>/dev/null || return 0
	printf '  Removed the relay alias from an earlier install so npm can replace it.\n'
}

# Remove the `relay` link the retired relayevals CLI left behind.
#
# Its installer (0.6.26 to 0.6.70) linked ~/.local/bin/relay to its own wrapper,
# <relay home>/bin/relayevals, and put ~/.local/bin first on PATH in the shell
# profile. The link outlived that CLI: after installing this Relay, typing
# `relay` still started relayevals 0.6.70, and this script welcomed the person
# anyway, because a `relay` was on PATH and it ran.
#
# We put it there; we take it away. Only a symlink named relay whose target is
# bin/relayevals, which is the exact shape that installer left. The relayevals
# command, its folders and the PATH line stay. The note is printed at the end,
# where screen mode cannot draw over it.
clear_retired_gate_alias() {
	[ "$relay_cmd" = relay ] || return 0
	relay_gate_first=$(command -v relay 2>/dev/null) || relay_gate_first=
	for relay_gate_link in "${HOME:+$HOME/.local/bin/relay}" "$relay_gate_first"; do
		[ -n "$relay_gate_link" ] && [ -L "$relay_gate_link" ] || continue
		relay_gate_target=$(readlink "$relay_gate_link" 2>/dev/null) || continue
		case "$relay_gate_target" in
			*/bin/relayevals) ;;
			*) continue ;;
		esac
		rm -f "$relay_gate_link" 2>/dev/null || continue
		[ -L "$relay_gate_link" ] && continue
		relay_retired_alias_removed="$relay_gate_link"
	done
	hash -r 2>/dev/null || true
}

# Said once, after the screen is gone: what was removed, and why this terminal
# may still start the old program (bash remembers where a command was found).
print_retired_alias_note() {
	[ -n "$relay_retired_alias_removed" ] || return 0
	printf '\nRemoved %s. It started the retired relayevals CLI instead of this install.\n' "$(relay_display_path "$relay_retired_alias_removed")"
	printf 'Open a new terminal window before you type %s.\n' "$relay_cmd"
	relay_retired_alias_removed=
}

# The `relay` a new shell would start, when it is not the copy npm just
# installed. Files are compared, not path strings, because one folder can be on
# PATH under two names.
relay_shadowing_command() {
	relay_first=$(resolve_relay_with_original_path) || return 1
	relay_installed_dir=$(relay_npm_bin_dir) || return 1
	[ -e "$relay_installed_dir/$relay_cmd" ] || return 1
	[ "$relay_first" -ef "$relay_installed_dir/$relay_cmd" ] && return 1
	printf '%s' "$relay_first"
}

# Another `relay` comes first on PATH. It is somebody else's, so it stays; say
# where each one is and what to change, instead of a welcome that would send the
# person to the wrong program.
print_relay_shadowed() {
	relay_count_outcome=INSTALL_NOT_ON_PATH
	relay_installed_at="$(relay_npm_bin_dir)/$relay_cmd"
	if [ "$relay_screen_enabled" = 1 ]; then
		relay_screen "Relay installed" "" "Another $relay_cmd comes first on your PATH." ""
		relay_restore_terminal
	fi
	print_retired_alias_note
	printf '\nRelay is installed at %s, but typing %s starts a different program:\n' "$relay_installed_at" "$relay_cmd"
	printf '  %s\n' "$1"
	printf '\nRemove that one, or put %s earlier in your PATH, then open a new terminal window.\n' "$(dirname "$relay_installed_at")"
	printf 'Until then, %s starts this install.\n' "$relay_installed_at"
}

# THE CHECK 0.6.86 DID NOT HAVE.
#
# That release installed cleanly — npm exited 0, this script painted "Relay
# installed", and the first command a user ran died with a module-resolution
# stack trace. Nothing in between looked at the thing it had just installed.
#
# The success gate below is `command -v relay`, which asks whether a file is on
# PATH. It was true. What was false was whether that file could run: npm had
# created empty directories for four dependencies and reported success anyway.
#
# So run the binary. `--version` is the cheapest command that loads the real
# entry point and therefore resolves the real dependency graph — the exact
# thing that was broken. A failure here prints npm's install as a bad install,
# with the interpreter's own message, instead of leaving it for the user's
# first real command.
#
# Deliberately NOT fatal when the command is simply not on PATH yet: that case
# is a shell-profile problem the caller already handles further down, and it is
# not a sign that the install is broken.
verify_relay_runs() {
	if [ -n "$relay_user_npm_prefix" ]; then
		# The installer chose this folder, so the command must be in it.
		relay_bin="$relay_user_npm_prefix/bin/$relay_cmd"
	elif relay_npm_bin=$(relay_npm_bin_dir) && [ -x "$relay_npm_bin/$relay_cmd" ]; then
		# Ask npm where it put the command and test THAT, not whichever relay
		# comes first on PATH. A clean container often has npm's global bin
		# outside PATH, and "not on PATH" must not mean "not checked". And a
		# machine with another relay first ran that one here: the retired
		# relayevals alias printed its own version and passed this check.
		relay_bin="$relay_npm_bin/$relay_cmd"
	else
		# `|| relay_bin=` matters: under `set -e` a bare failing assignment
		# ended the script here, silently, whenever relay was not on PATH.
		relay_bin=$(command -v "$relay_cmd" 2>/dev/null) || relay_bin=
	fi
	[ -n "$relay_bin" ] || return 0

	if smoke_output=$("$relay_bin" --version 2>&1); then
		return 0
	fi

	relay_restore_terminal
	printf '\n' >&2
	printf 'error: Relay installed but does not run.\n\n' >&2
	printf '%s\n\n' "$smoke_output" >&2
	printf 'The install completed without an error but produced a tree that cannot\n' >&2
	printf 'start. Please report this with the output above:\n' >&2
	printf '  https://relayevals.com/docs\n' >&2
	exit 1
}

install_relay_package() {
	tarball_path="$1"
	if [ "$relay_bootstrap_kernel_on_install" = 1 ]; then
		npm_install_details="Preparing global install.
Linking command binaries.
Installing runtime packages.
Preloading search tools.
Preparing Python kernel.
Finalizing npm install."
		relay_run_quiet_with_animation_steps \
			"Installing Relay" \
			"Installing Relay" \
			"$npm_install_details" \
			run_relay_npm_install "$tarball_path" RELAY_BOOTSTRAP_TOOLS_ON_INSTALL=1 RELAY_BOOTSTRAP_KERNEL_ON_INSTALL=1 RELAY_INSTALL_UV=1
	else
		npm_install_details="Preparing global install.
Linking command binaries.
Installing runtime packages.
Preloading search tools.
Finalizing npm install."
		relay_run_quiet_with_animation_steps \
			"Installing Relay" \
			"Installing Relay" \
			"$npm_install_details" \
			run_relay_npm_install "$tarball_path" RELAY_BOOTSTRAP_TOOLS_ON_INSTALL=1
	fi
}

#   $1 the tarball, then the environment assignments for npm's install scripts
run_relay_npm_install() {
	npm_tarball_path="$1"
	shift
	if [ -n "$relay_user_npm_prefix" ]; then
		env "$@" npm install -g --prefix "$relay_user_npm_prefix" --no-fund --no-audit --loglevel=error --progress=false "$npm_tarball_path"
	else
		env "$@" npm install -g --no-fund --no-audit --loglevel=error --progress=false "$npm_tarball_path"
	fi
}

main "$@"
