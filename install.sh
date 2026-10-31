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

# Relay's release keys (D-78). A release's SHA256SUMS.sig must hold signatures over its SHA256SUMS by this many of
# these people; verify_relay_release_signature checks them. With no key here, nothing is checked and nothing is said.
# BEGIN RELAY RELEASE TRUST: written by scripts/sync-release-trust.mjs from scripts/release-trust.json. Do not edit here.
relay_signature_namespace='release@relayevals.com'
relay_signatures_required=2
relay_require_signature_default=0
relay_release_signers=''
# END RELAY RELEASE TRUST
readonly relay_signature_namespace relay_signatures_required relay_require_signature_default relay_release_signers

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
relay_signature_note=
relay_screen_title=
relay_screen_status=
relay_screen_detail=
relay_screen_question=
relay_animation_frame=0
# The installer asks nothing (24 Oct 2026): one line per step with its time, ending with the version, the total time
# and what to type. The one question it cannot avoid, a sudo password to install Node.js, is asked once, only in a
# terminal. RELAY_INSTALL_INTERACTIVE=1 brings back the full-screen installer and its questions.
relay_interactive=0
case "$(printf '%s' "${RELAY_INSTALL_INTERACTIVE:-}" | tr '[:upper:]' '[:lower:]')" in
	1|true|yes|on) relay_interactive=1 ;;
esac
relay_install_started=$(date +%s)
relay_step_started=
relay_step_label=
relay_step_open=0
relay_step_tty=0
relay_finish_hint=
relay_uv_profile_note=
relay_node_install_attempted=0
relay_count_sent=0
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
	# npm's own notices (a newer npm, funding, audit) are npm's business, not the person's.
	npm_config_update_notifier=false
	npm_config_fund=false
	npm_config_audit=false
	export npm_config_update_notifier npm_config_fund npm_config_audit
	if [ "$relay_interactive" = 1 ]; then
		relay_main_screen "$@"
	else
		relay_main_inline "$@"
	fi
}

# RELAY_INSTALL_INTERACTIVE=1: the full-screen installer from before 24 Oct 2026, with its questions.
relay_main_screen() {
	if [ -t 1 ] && [ "${TERM:-}" != dumb ]; then
		relay_step_tty=1
	fi
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
	relay_step_start "Downloading Relay"
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
		relay_finish_hint="add that folder to your PATH, then run: $relay_cmd"
	fi
	print_retired_alias_note
	if [ -n "$relay_uv_profile_note" ]; then
		if [ "$relay_screen_enabled" = 1 ]; then
			printf '\n'
		fi
		printf '%s\n' "$relay_uv_profile_note"
	fi
	# The screen redraws over anything printed while it is up, so the signature's one line comes once it is down.
	if [ "$relay_screen_enabled" = 1 ] && [ -n "$relay_signature_note" ]; then
		printf '\n%s\n' "$relay_signature_note"
	fi
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
	if [ "$relay_screen_enabled" != 1 ] && ! relay_quiet; then
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
	if relay_quiet; then
		# The last line says it: "✓ Relay <version> installed · 41 s · run: relay".
		print_retired_alias_note
		print_relay_claude_plan_reminder
		if [ -z "$relay_finish_hint" ]; then
			relay_finish_hint="run: $relay_cmd"
		fi
		return 0
	fi
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
	if [ "$relay_count_sent" != 1 ]; then
		relay_send_count "$status" || :
	fi
	return "$status"
}

relay_signal_cleanup() {
	relay_count_signalled="$1"
	relay_restore_terminal
	exit "$1"
}

# ── The anonymous count, left for Relay (D-72; decision 6, 30 Oct 2026) ─────
# Nothing is sent during install. The one count the installer used to send itself, relay.installed (NEW, or REINSTALL
# when relay was here before) or relay.blocked with the step that stopped it, is written as one line to
# <agent dir>/install-counts.jsonl when the installer ends. Relay sends it with its own counts, and only after it has
# shown its one notice about them (`relay telemetry show` prints it while it waits). It carries the Relay version, the
# OS family and the code, nothing else, and no id: Relay names it with its own. DO_NOT_TRACK=1, RELAY_TELEMETRY=0,
# RELAY_OFFLINE=1, telemetry turned off in Relay's settings, or RELAY_COUNTS_URL set empty write nothing. Ctrl+C
# writes INSTALL_CANCELLED; a TERM writes nothing. Writing it never changes the exit code or what is printed.

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

# The same switches, in the same order, as Relay's own isTelemetryEnabled.
relay_counts_enabled() {
	relay_count_flag_on "${RELAY_OFFLINE:-${PI_OFFLINE:-}}" && return 1
	relay_count_flag_on "${DO_NOT_TRACK:-}" && return 1
	relay_count_flag_off "${RELAY_TELEMETRY:-}" && return 1
	if [ "${RELAY_COUNTS_URL+set}" = set ] && [ -z "$RELAY_COUNTS_URL" ]; then
		return 1
	fi
	relay_count_flag_on "${RELAY_TELEMETRY:-}" && return 0
	relay_count_dir=$(relay_count_agent_dir) || return 0
	if [ -f "$relay_count_dir/settings.json" ] &&
		tr -d ' \t\r\n' <"$relay_count_dir/settings.json" 2>/dev/null | grep -q '"telemetry":{[^}]*"enabled":false'; then
		return 1
	fi
	return 0
}

# Whether relay was installed here before: on PATH, or Relay's install id already written.
relay_count_note_prior_install() {
	if command -v "$relay_cmd" >/dev/null 2>&1; then
		relay_count_kind=REINSTALL
	elif relay_count_dir=$(relay_count_agent_dir) && [ -f "$relay_count_dir/telemetry.json" ]; then
		relay_count_kind=REINSTALL
	fi
	return 0
}

relay_count_platform() {
	case "$(uname -s 2>/dev/null)" in
		Darwin) printf 'darwin' ;;
		Linux) printf 'linux' ;;
		MINGW*|MSYS*|CYGWIN*) printf 'win32' ;;
		*) printf 'other' ;;
	esac
}

# The installer's one count, as Relay will send it: written to install-counts.jsonl (0600, the last 20 lines kept).
#   $1 the installer's exit status
relay_send_count() {
	relay_count_status="$1"
	if [ "$relay_count_signalled" = 130 ]; then
		relay_count_name=relay.blocked
		relay_count_code=INSTALL_CANCELLED
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
	relay_count_dir=$(relay_count_agent_dir) || return 0
	relay_count_file="$relay_count_dir/install-counts.jsonl"
	[ ! -L "$relay_count_file" ] || return 0
	case "$relay_count_version" in
		""|*[!0-9A-Za-z.+-]*) relay_count_version=unknown ;;
	esac
	[ "${#relay_count_version}" -le 32 ] || relay_count_version=unknown
	mkdir -p "$relay_count_dir" 2>/dev/null || return 0
	relay_count_line=$(printf '{"name":"%s","version":"%s","platform":"%s","code":"%s","at":%s000}' \
		"$relay_count_name" "$relay_count_version" "$(relay_count_platform)" "$relay_count_code" "$(date +%s)")
	relay_count_temp="$relay_count_file.$$.tmp"
	(
		umask 077
		{
			[ -f "$relay_count_file" ] && tail -n 19 "$relay_count_file"
			printf '%s\n' "$relay_count_line"
		} >"$relay_count_temp"
	) 2>/dev/null || {
		rm -f "$relay_count_temp" 2>/dev/null
		return 0
	}
	mv -f "$relay_count_temp" "$relay_count_file" 2>/dev/null || rm -f "$relay_count_temp" 2>/dev/null
	return 0
}

# Before the installer hands the terminal to relay (exec), the count is written: the EXIT trap will not run.
relay_count_flush_marker() {
	relay_count_finished=1
	relay_send_count 0 || :
}

# ── The inline installer (O01, O02, O10; 30 Oct 2026) ──────────────────────────
# Draws under the command, never clears the screen, and keeps at most 12 rows: a 25×5 capsule beside the header, then
# five steps (check this machine, download, verify, install, PATH), each pending ○, running (a spinner, and for the
# download a bar with %, MB/s and seconds left) or done ✓. The capsule's arrows move only while work runs, at 10 frames
# a second; under reduced motion the arrows stay still and the spinner is a static ●, while the numbers still count.
# When the work is done the block collapses to a summary, and in a terminal the installer asks "Set up now?" on
# /dev/tty, which works under curl | bash. Not a terminal, or CI: plain "relay-install:" lines, no colour, no prompts.
# A step that fails says what happened, whose it is and what to do next (O10), and the network steps try 3 times.
# Nothing is sent to Relay during install (decision 6): what the old count said is left for Relay to send later.

relay_live=0
relay_plain=0
relay_motion=full
relay_ci=0
relay_live_rows=0
relay_live_frame=0
relay_live_wide=1
relay_live_header=
relay_live_phase=
relay_live_done_line=
relay_c_bold=
relay_c_dim=
relay_c_ok=
relay_c_bad=
relay_c_accent=
relay_c_reset=
relay_st_1=pending
relay_st_2=pending
relay_st_3=pending
relay_st_4=pending
relay_st_5=pending
relay_sl_1=
relay_sl_2=
relay_sl_3=
relay_sl_4=
relay_sl_5=
relay_sm_1=
relay_sm_2=
relay_sm_3=
relay_sm_4=
relay_sm_5=
relay_os_line=
relay_shell_name=
relay_profile_display=
relay_install_bin_dir=
relay_installed_bin=
relay_digest=
relay_download_bytes=0
relay_signature_ok=0
relay_path_line_done=
relay_notes=
relay_try_note=
relay_fetch_detail=
relay_fetch_kind=
relay_fetch_code=
relay_script_url="${RELAY_INSTALL_SCRIPT_URL:-relayevals.com/install.sh}"
relay_retry_delay="${RELAY_INSTALL_RETRY_DELAY:-2}"
relay_timer_tool=
# How relay is installed (I2, decision 8): binary (the native build, no Node or npm), npm (the fallback, for one
# release), or auto: the native build when the release has one for this machine, else npm.
relay_install_method="${RELAY_INSTALL_METHOD:-auto}"
relay_binary_platform_name=
relay_method=npm
relay_binary_fallback_note=

# Whether this is a CI job: nobody is there to ask, and the PATH is the job's own business.
relay_is_ci() {
	case "$(printf '%s' "${CI:-}" | tr '[:upper:]' '[:lower:]')" in
		1|true|yes) return 0 ;;
	esac
	[ -n "${GITHUB_ACTIONS:-}" ] || [ -n "${BUILDKITE:-}" ] || [ -n "${GITLAB_CI:-}" ] || [ -n "${CIRCLECI:-}" ]
}

# Reduced motion: RELAY_MOTION=reduced (or off), else the Mac's own "Reduce motion" setting.
relay_reduced_motion() {
	case "$(printf '%s' "${RELAY_MOTION:-}" | tr '[:upper:]' '[:lower:]')" in
		reduced|off|none) return 0 ;;
		full) return 1 ;;
	esac
	[ "$(relay_os_name)" = Darwin ] || return 1
	[ "$(defaults read com.apple.universalaccess reduceMotion 2>/dev/null || :)" = 1 ]
}

relay_ui_init() {
	if relay_is_ci; then
		relay_ci=1
	fi
	if [ "$relay_ci" = 0 ] && [ -t 1 ] && [ "${TERM:-}" != dumb ] && [ "${RELAY_INSTALLER_PLAIN:-0}" != 1 ]; then
		relay_live=1
	else
		relay_plain=1
	fi
	if relay_reduced_motion; then
		relay_motion=reduced
	fi
	if [ "$relay_live" = 1 ] && [ -z "${NO_COLOR:-}" ]; then
		relay_c_bold="${relay_esc}[1m"
		relay_c_dim="${relay_esc}[2m"
		relay_c_ok="${relay_esc}[32m"
		relay_c_bad="${relay_esc}[31m"
		relay_c_accent="${relay_esc}[38;2;127;91;213m"
		relay_c_reset="${relay_esc}[0m"
	fi
	relay_shell_name="${SHELL:-sh}"
	relay_shell_name="${relay_shell_name##*/}"
	if relay_profile=$(detect_shell_profile 2>/dev/null); then
		relay_profile_display=$(relay_display_path "$relay_profile")
	else
		relay_profile_display="your shell profile"
	fi
	if [ "$relay_live" = 1 ]; then
		relay_read_terminal_size
		if [ "$relay_screen_cols" -lt 64 ]; then
			relay_live_wide=0
		fi
	fi
}

# A plain line, for CI and anything that is not a terminal.
relay_say() {
	printf 'relay-install: %s\n' "$1"
}

# Tenths of a second since some fixed point: perl's clock when there is one, else whole seconds.
relay_now_ds() {
	if [ -z "$relay_timer_tool" ]; then
		if command -v perl >/dev/null 2>&1 && perl -MTime::HiRes=time -e 'exit 0' 2>/dev/null; then
			relay_timer_tool=perl
		else
			relay_timer_tool=date
		fi
	fi
	if [ "$relay_timer_tool" = perl ]; then
		perl -MTime::HiRes=time -e 'printf "%d", time * 10'
	else
		printf '%d' "$(($(date +%s) * 10))"
	fi
}

# "4.2s" from tenths of a second.
relay_ds_text() {
	printf '%d.%ds' "$(($1 / 10))" "$(($1 % 10))"
}

# "18.4 MB" from bytes (decimal megabytes, as the release page says them).
relay_mb_text() {
	awk -v b="$1" 'BEGIN { printf "%.1f MB", b / 1000000 }'
}

relay_short_digest() {
	relay_sd_len=${#1}
	if [ "$relay_sd_len" -le 8 ]; then
		printf '%s' "$1"
		return 0
	fi
	printf '%s…%s' "$(printf '%s' "$1" | cut -c1-4)" "$(printf '%s' "$1" | cut -c"$((relay_sd_len - 3))"-)"
}

# ── The capsule (O01) ──
# 25 columns by 5 rows. The middle row carries arrows that slide right while work runs; reduced motion holds one ●.
relay_capsule_row() {
	case "$1" in
		1) printf '   ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄    ' ;;
		2) printf ' ▄▀                  ▀▄  ' ;;
		3) printf '█%s█ ' "$(relay_capsule_middle)" ;;
		4) printf ' ▀▄                  ▄▀  ' ;;
		5) printf '   ▀▀▀▀▀▀▀ ▀▀ ▀▀▀▀▀▀▀    ' ;;
	esac
}

# The 22 cells inside the capsule: "→" every fourth cell, shifted by the frame; still when nothing runs.
relay_capsule_middle() {
	if [ "$relay_motion" = reduced ] || [ -n "$relay_live_done_line" ]; then
		printf '          ●           '
		return
	fi
	relay_cm_shift=$((relay_live_frame % 4))
	relay_cm_out=
	relay_cm_i=0
	while [ "$relay_cm_i" -lt 22 ]; do
		if [ "$relay_cm_i" -ge 1 ] && [ "$relay_cm_i" -le 20 ] && [ $(((relay_cm_i + 4 - relay_cm_shift) % 4)) = 0 ]; then
			relay_cm_out="${relay_cm_out}→"
		else
			relay_cm_out="${relay_cm_out} "
		fi
		relay_cm_i=$((relay_cm_i + 1))
	done
	printf '%s' "$relay_cm_out"
}

relay_spinner() {
	if [ "$relay_motion" = reduced ]; then
		printf '●'
		return
	fi
	case $((relay_live_frame % 10)) in
		0) printf '⠋' ;; 1) printf '⠙' ;; 2) printf '⠹' ;; 3) printf '⠸' ;; 4) printf '⠼' ;;
		5) printf '⠴' ;; 6) printf '⠦' ;; 7) printf '⠧' ;; 8) printf '⠇' ;; *) printf '⠏' ;;
	esac
}

# One step's line: "  ○ label" pending, "  ⠹ label meta" running, "  ✓ label" done, "  ✗ label stopped" failed.
relay_step_line() {
	eval "relay_sx_state=\$relay_st_$1 relay_sx_label=\$relay_sl_$1 relay_sx_meta=\$relay_sm_$1"
	case "$relay_sx_state" in
		pending) printf '  %s○ %s%s' "$relay_c_dim" "$relay_sx_label" "$relay_c_reset" ;;
		running) printf '  %s%s%s %s%s' "$relay_c_accent" "$(relay_spinner)" "$relay_c_reset" "$relay_sx_label" "$relay_sx_meta" ;;
		done) printf '  %s✓%s %s' "$relay_c_ok" "$relay_c_reset" "$relay_sx_label" ;;
		failed) printf '  %s✗%s %s %sstopped%s%s' "$relay_c_bad" "$relay_c_reset" "$relay_sx_label" "$relay_c_bad" "$relay_c_reset" "$relay_sx_meta" ;;
	esac
}

relay_header_title() {
	if [ -n "${relay_count_version:-}" ] && [ "$relay_count_version" != unknown ]; then
		printf 'Relay %s · installer' "$relay_count_version"
	else
		printf 'Relay · installer'
	fi
}

# The header's third row: "one native binary · no sudo · nothing sent" when the native build is going in and the
# terminal has room for it (O01), "no sudo · nothing sent" otherwise.
relay_header_promise() {
	if [ "$relay_method" = binary ] && [ "$relay_screen_cols" -ge 72 ]; then
		printf 'one native binary · no sudo · nothing sent'
	else
		printf 'no sudo · nothing sent'
	fi
}

# The block's lines, one per row, into relay_frame_text.
relay_compose_frame() {
	relay_frame_text=
	if [ "$relay_live_wide" = 1 ]; then
		for relay_cf_row in 1 2 3 4 5; do
			case "$relay_cf_row" in
				1) relay_cf_side="${relay_c_bold}$(relay_header_title)${relay_c_reset}" ;;
				2) relay_cf_side="${relay_c_dim}${relay_live_phase}${relay_c_reset}" ;;
				3) relay_cf_side="${relay_c_dim}$(relay_header_promise)${relay_c_reset}" ;;
				*) relay_cf_side= ;;
			esac
			relay_frame_text="${relay_frame_text}  ${relay_c_accent}$(relay_capsule_row "$relay_cf_row")${relay_c_reset}  ${relay_cf_side}
"
		done
		relay_frame_text="${relay_frame_text}
"
	else
		# Narrow: the header in one row, the phase as its step number.
		relay_frame_text="  ${relay_c_bold}$(relay_header_title | sed 's/ · installer$//')${relay_c_reset} ${relay_c_dim}· $(printf '%s' "$relay_live_phase" | sed 's/ · .*//')${relay_c_reset}
"
	fi
	for relay_cf_step in 1 2 3 4 5; do
		relay_frame_text="${relay_frame_text}$(relay_step_line "$relay_cf_step")
"
	done
}

# Draws the block in place: back up over the last frame and write each row over it. Autowrap is off while the block is
# up, so a row wider than the terminal is cut at its edge instead of pushing the rows below it down.
relay_live_draw() {
	[ "$relay_live" = 1 ] || return 0
	relay_compose_frame
	relay_ld_rows=$(printf '%s' "$relay_frame_text" | awk 'END { print NR }')
	{
		printf '%s%s' "$relay_sync_start" "$relay_esc[?7l"
		if [ "$relay_live_rows" -gt 0 ]; then
			printf '\r%s[%dA' "$relay_esc" "$relay_live_rows"
		fi
		printf '%s' "$relay_frame_text" | while IFS= read -r relay_ld_line; do
			printf '\r%s[K%s\n' "$relay_esc" "$relay_ld_line"
		done
		printf '%s' "$relay_sync_end"
	} >&1
	relay_live_rows="$relay_ld_rows"
}

# Takes the block away, leaving the cursor where it began, with autowrap and the cursor back.
relay_live_clear() {
	[ "$relay_live" = 1 ] || return 0
	if [ "$relay_live_rows" -gt 0 ]; then
		printf '\r%s[%dA%s[J' "$relay_esc" "$relay_live_rows" "$relay_esc"
	fi
	printf '%s[?7h%s' "$relay_esc" "$relay_show_cursor"
	relay_live_rows=0
}

relay_live_start() {
	if [ "$relay_live" = 1 ]; then
		printf '%s\n' "$relay_hide_cursor"
		relay_live_draw
	else
		if [ "$relay_ci" = 1 ]; then
			relay_say "not a terminal (CI=true): plain lines, no colour, no prompts"
		else
			relay_say "not a terminal: plain lines, no colour, no prompts"
		fi
		relay_say "if a step fails it exits 1 and says why"
	fi
}

#   $1 step  $2 state  $3 label  [$4 meta]
relay_step_set() {
	eval "relay_st_$1=\$2 relay_sl_$1=\$3 relay_sm_$1=\${4:-}"
	case "$2" in
		running)
			case "$1" in
				1) relay_live_phase="step 1 of 5 · checking this machine" ;;
				2) relay_live_phase="step 2 of 5 · downloading" ;;
				3) relay_live_phase="step 3 of 5 · verifying" ;;
				4) relay_live_phase="step 4 of 5 · installing" ;;
				5) relay_live_phase="step 5 of 5 · adding to PATH" ;;
			esac
			;;
	esac
	relay_live_draw
}

# Animates the block while a background job runs (10 frames a second); nothing in plain mode.
relay_live_spin() {
	[ "$relay_live" = 1 ] || return 0
	while kill -0 "$1" 2>/dev/null; do
		relay_live_frame=$((relay_live_frame + 1))
		relay_live_draw
		sleep 0.1
	done
}

# Animates the block while a background job runs, then returns its exit status.
relay_live_wait() {
	relay_lw_pid="$1"
	relay_live_spin "$relay_lw_pid"
	if wait "$relay_lw_pid"; then
		return 0
	else
		return $?
	fi
}

# ── Failures (O10): what happened, whose it is, what to do next ──
# The block keeps the steps that finished and the one that stopped, then the explanation below it, then exit 1.
#   $1 the step that stopped  $2 a note after "stopped" (may be empty)  then the explanation's lines
relay_stop() {
	relay_stop_step="$1"
	relay_stop_note="$2"
	shift 2
	relay_step_break
	if [ "$relay_live" = 1 ]; then
		eval "relay_st_$relay_stop_step=failed relay_sm_$relay_stop_step=\${relay_stop_note:+ · \$relay_stop_note}"
		relay_live_clear
		for relay_ss_step in 1 2 3 4 5; do
			eval "relay_ss_state=\$relay_st_$relay_ss_step"
			case "$relay_ss_state" in
				done|failed) printf '%s\n' "$(relay_step_line "$relay_ss_step")" ;;
			esac
		done
		printf '\n'
		relay_ss_first=1
		for relay_ss_line in "$@"; do
			if [ "$relay_ss_first" = 1 ]; then
				printf '%s%s%s\n' "$relay_c_bad" "$relay_ss_line" "$relay_c_reset"
				relay_ss_first=0
			else
				printf '%s\n' "$relay_ss_line"
			fi
		done
	else
		eval "relay_ss_label=\$relay_sl_$relay_stop_step"
		relay_say "✗ $relay_ss_label stopped${relay_stop_note:+ · $relay_stop_note}"
		for relay_ss_line in "$@"; do
			relay_say "$relay_ss_line"
		done
	fi
	exit 1
}

relay_untouched() {
	printf '%s untouched' "$relay_profile_display"
}

relay_fail_unsupported() {
	relay_step_set 1 running "$relay_os_line"
	relay_stop 1 "" "✗ stopped · $1" \
		"  nothing was downloaded or installed · $(relay_untouched)" \
		"" \
		"  supported  macOS 13+ (Apple silicon or Intel)" \
		"             Linux x86_64 or arm64 · Windows through WSL 2" \
		"             not supported: 32-bit systems, macOS 12 and older" \
		"" \
		"  next: $2" \
		"        or run relay on a supported machine · relayevals.com/docs/systems"
}

relay_fail_tool() {
	relay_stop "$1" "" "✗ stopped · this machine has no $2, which the installer needs" \
		"  cause: a tool missing on this machine, not Relay" \
		"  nothing was installed · $(relay_untouched)" \
		"  next: install $2, then run the same command again"
}

#   $1 step  $2 what was being fetched  $3 the address
relay_fail_fetch() {
	relay_ff_host=$(printf '%s' "$3" | sed -n 's#^[a-z]*://\([^/]*\).*#\1#p')
	[ -n "$relay_ff_host" ] || relay_ff_host="$3"
	case "$relay_fetch_kind" in
		network)
			relay_stop "$1" "$relay_try_note" "✗ couldn't reach $relay_ff_host · $relay_fetch_detail" \
				"  cause: your network or a proxy, not Relay" \
				"  nothing was installed · $([ "$1" = 2 ] && printf 'nothing was downloaded' || printf 'the download was deleted') · $(relay_untouched)" \
				"" \
				"  if you're behind a proxy, set HTTPS_PROXY and run it again:" \
				"    export HTTPS_PROXY=http://proxy.yourcompany.com:8080" \
				"  no proxy? check your connection · service status: status.relayevals.com" \
				"  next: run the same command again once you're online"
			;;
		missing)
			relay_stop "$1" "" "✗ stopped · $2 isn't at $3 ($relay_fetch_detail)" \
				"  cause: Relay's release server, not your machine" \
				"  nothing was installed · $(relay_untouched)" \
				"  next: run the same command again in a few minutes · service status: status.relayevals.com" \
				"        to install a version you name: RELAY_VERSION=<version>"
			;;
		*)
			relay_stop "$1" "$relay_try_note" "✗ stopped · $relay_ff_host answered with an error ($relay_fetch_detail)" \
				"  cause: Relay's release server, not your machine" \
				"  nothing was installed · $(relay_untouched)" \
				"  next: run the same command again in a few minutes · service status: status.relayevals.com"
			;;
	esac
}

#   $1 expected digest  $2 the digest of what arrived  $3 the SHA256SUMS address
relay_fail_checksum() {
	relay_stop 3 "" "✗ stopped · the download didn't match its checksum" \
		"    expected  sha256 $(relay_short_digest "$1")   published at $3" \
		"    got       sha256 $(relay_short_digest "$2")" \
		"  nothing was installed · the download was deleted · $(relay_untouched)" \
		"  usually a cut-off download, or a proxy that rewrites files" \
		"  next: run the same command again" \
		"        fails twice? don't install it another way · report it:" \
		"        relayevals.com/security"
}

# ── Fetching, with 3 tries for the network ──
# curl with a 10 s connection timeout; a stalled download (under 1 KB/s for 15 s) counts as a network failure.
# Leaves relay_fetch_kind (network, missing, http) and relay_fetch_detail when every try failed.
#   $1 address  $2 file  [$3 "progress": draw the download's bar on step 2]
relay_fetch() {
	relay_fetch_url="$1"
	relay_fetch_out="$2"
	relay_fetch_progress="${3:-}"
	relay_fetch_try=1
	relay_try_note=
	while :; do
		rm -f "$relay_fetch_out" "$relay_fetch_out.headers"
		relay_fetch_started=$(relay_now_ds)
		curl -fsSL --connect-timeout 10 --speed-limit 1024 --speed-time 15 -D "$relay_fetch_out.headers" \
			-o "$relay_fetch_out" -w '%{http_code}' "$relay_fetch_url" >"$relay_fetch_out.code" 2>/dev/null &
		relay_fetch_pid=$!
		if [ "$relay_fetch_progress" = progress ] && [ "$relay_live" = 1 ]; then
			while kill -0 "$relay_fetch_pid" 2>/dev/null; do
				relay_live_frame=$((relay_live_frame + 1))
				relay_download_meta "$relay_fetch_started"
				relay_live_draw
				sleep 0.1
			done
		else
			relay_live_spin "$relay_fetch_pid"
		fi
		if wait "$relay_fetch_pid"; then
			relay_fetch_status=0
		else
			relay_fetch_status=$?
		fi
		relay_fetch_code=$(cat "$relay_fetch_out.code" 2>/dev/null || :)
		if [ "$relay_fetch_status" = 0 ]; then
			relay_fetch_elapsed=$(($(relay_now_ds) - relay_fetch_started))
			rm -f "$relay_fetch_out.code"
			return 0
		fi
		case "$relay_fetch_status" in
			5|6|7|28|35|52|55|56|16|18|92)
				relay_fetch_kind=network
				case "$relay_fetch_status" in
					6) relay_fetch_detail="its name didn't resolve" ;;
					7) relay_fetch_detail="connection refused" ;;
					28) relay_fetch_detail="connection timed out" ;;
					*) relay_fetch_detail="the connection dropped (curl $relay_fetch_status)" ;;
				esac
				;;
			22)
				case "$relay_fetch_code" in
					404|410) relay_fetch_kind=missing ;;
					*) relay_fetch_kind=http ;;
				esac
				relay_fetch_detail="HTTP $relay_fetch_code"
				;;
			37)
				relay_fetch_kind=missing
				relay_fetch_detail="not found"
				;;
			*)
				relay_fetch_kind=http
				relay_fetch_detail="curl $relay_fetch_status"
				;;
		esac
		rm -f "$relay_fetch_out" "$relay_fetch_out.code"
		# A missing file is missing on the next try too.
		if [ "$relay_fetch_kind" = missing ] || [ "$relay_fetch_try" -ge 3 ]; then
			if [ "$relay_fetch_try" -gt 1 ]; then
				relay_try_note="$relay_fetch_try tries"
				[ "$relay_fetch_status" = 28 ] && relay_try_note="$relay_try_note, 10s each"
			fi
			return 1
		fi
		relay_fetch_try=$((relay_fetch_try + 1))
		if [ "$relay_fetch_progress" = progress ]; then
			eval "relay_sm_2=' · try $relay_fetch_try of 3'"
		fi
		relay_live_draw
		sleep "$relay_retry_delay"
	done
}

# The download's bar: "▓▓▓▓▓▓▓▓░░░░ 62% · 6.1 MB/s · ~1s", from the bytes on disk and the length the server sent.
relay_download_meta() {
	relay_dm_got=0
	if [ -f "$relay_fetch_out" ]; then
		relay_dm_got=$(wc -c 2>/dev/null <"$relay_fetch_out" || printf '0')
	fi
	relay_dm_got=$((relay_dm_got + 0))
	relay_dm_total=$(cat "$relay_fetch_out.headers" 2>/dev/null | tr -d '\r' |
		awk 'tolower($1) == "content-length:" { n = $2 } END { print n + 0 }')
	relay_dm_ds=$(($(relay_now_ds) - $1))
	relay_sm_2=$(awk -v got="$relay_dm_got" -v total="$relay_dm_total" -v ds="$relay_dm_ds" -v narrow="$((1 - relay_live_wide))" 'BEGIN {
		if (total <= 0) { printf " · connecting…"; exit }
		pct = int(got * 100 / total); if (pct > 100) pct = 100
		filled = int(pct * 12 / 100); bar = ""
		for (i = 0; i < 12; i++) bar = bar (i < filled ? "▓" : "░")
		secs = ds / 10; if (secs <= 0) secs = 0.1
		rate = got / secs
		left = rate > 0 ? (total - got) / rate : 0
		if (left < 1) left = 1
		if (narrow) printf " · %d%% · ~%ds", pct, left + 0.5
		else printf " · %.1f MB %s %d%% · %.1f MB/s · ~%ds", total / 1000000, bar, pct, rate / 1000000, left + 0.5
	}')
}

# ── Step 1: this machine (O10 3: the gate) ──
relay_os_name() { uname -s 2>/dev/null || printf 'unknown'; }
relay_os_arch() { uname -m 2>/dev/null || printf 'unknown'; }
relay_macos_version() { sw_vers -productVersion 2>/dev/null || printf '0'; }

# Sets relay_os_line ("Found macOS 15 · Apple silicon · zsh"), or stops with what is supported.
relay_check_machine() {
	relay_cm_os=$(relay_os_name)
	relay_cm_arch=$(relay_os_arch)
	case "$relay_cm_os" in
		Darwin)
			relay_cm_ver=$(relay_macos_version)
			relay_cm_major=${relay_cm_ver%%.*}
			case "$relay_cm_major" in ''|*[!0-9]*) relay_cm_major=0 ;; esac
			case "$relay_cm_arch" in
				arm64) relay_cm_chip="Apple silicon" ;;
				x86_64) relay_cm_chip=Intel ;;
				*) relay_cm_chip="$relay_cm_arch" ;;
			esac
			relay_os_line="Found macOS $relay_cm_major · $relay_cm_chip · $relay_shell_name"
			if [ "$relay_cm_major" -lt 13 ]; then
				relay_os_line="Found macOS $relay_cm_ver · $relay_cm_chip · $relay_shell_name"
				relay_fail_unsupported "relay needs macOS 13 or later · this Mac has $relay_cm_ver" \
					"update macOS · System Settings → General → Software Update"
			fi
			case "$relay_cm_arch" in
				arm64|x86_64) ;;
				*) relay_fail_unsupported "relay needs a 64-bit Mac · this one is $relay_cm_arch" "run relay on a 64-bit Mac" ;;
			esac
			;;
		Linux)
			relay_os_line="Found Linux $relay_cm_arch · $relay_shell_name"
			case "$relay_cm_arch" in
				x86_64|amd64|aarch64|arm64) ;;
				*) relay_fail_unsupported "relay needs Linux on x86_64 or arm64 · this machine is $relay_cm_arch" \
					"run relay on a 64-bit machine" ;;
			esac
			;;
		MINGW*|MSYS*|CYGWIN*)
			relay_os_line="Found Windows ($relay_cm_os) · $relay_shell_name"
			relay_fail_unsupported "relay runs on Windows only through WSL 2" \
				"install WSL 2 (wsl --install), then run this command inside it"
			;;
		*)
			relay_os_line="Found $relay_cm_os $relay_cm_arch · $relay_shell_name"
			relay_fail_unsupported "relay doesn't support $relay_cm_os" "run relay on macOS, Linux or WSL 2"
			;;
	esac
}

# Whether node and npm are here and new enough (the package's own engines.node).
relay_node_ready() {
	command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1 || return 1
	node_version_string_is_new_enough "$(node --version 2>/dev/null)"
}

relay_node_version() {
	node --version 2>/dev/null | sed 's/^v//'
}

# Node is missing or too old: install it the way this machine does (O01 step 1), asking for sudo once, before the
# block is drawn, only when that needs it and there is a terminal to ask on.
relay_install_node_inline() {
	relay_in_method=$(detect_node_install_method)
	case "$relay_in_method" in
		homebrew) relay_in_label="Homebrew" ;;
		apt) relay_in_label="apt" ;;
		apk) relay_in_label="apk" ;;
		*) relay_in_method=standalone; relay_in_label="standalone Node.js" ;;
	esac
	relay_node_install_attempted=1
	if node_install_needs_sudo "$relay_in_method"; then
		if [ "$relay_live" != 1 ] || ! ( : <>/dev/tty ) 2>/dev/null; then
			relay_count_step=INSTALL_NODE_MISSING
			relay_stop 1 "" "✗ stopped · relay needs Node.js $relay_min_node or newer, and installing it with $relay_in_label needs sudo" \
				"  cause: Node.js is missing on this machine, and there is no terminal to ask for your password" \
				"  nothing was installed · $(relay_untouched)" \
				"  next: install Node.js $relay_min_node or newer, then run the same command again"
		fi
		relay_live_clear
		printf 'Relay needs Node.js %s or newer. Installing it with %s needs your password (sudo); nothing else will ask.\n' \
			"$relay_min_node" "$relay_in_label"
		sudo -v </dev/tty
		relay_live_start
	fi
	relay_step_set 1 running "Installing Node.js with $relay_in_label"
	relay_in_dir=$(create_temp_dir)
	run_node_install_method "$relay_in_method" >"$relay_in_dir/output" 2>&1 </dev/null &
	if relay_live_wait $!; then
		:
	else
		relay_in_status=$?
		relay_count_step=INSTALL_NODE_MISSING
		relay_in_tail=$(tail -n 6 "$relay_in_dir/output" 2>/dev/null | sed 's/^/    /')
		rm -rf "$relay_in_dir"
		relay_stop 1 "" "✗ stopped · installing Node.js with $relay_in_label failed (exit $relay_in_status)" \
			"  cause: $relay_in_label on this machine, not Relay" \
			"$relay_in_tail" \
			"  nothing else was installed · $(relay_untouched)" \
			"  next: install Node.js $relay_min_node or newer yourself, then run the same command again"
	fi
	rm -rf "$relay_in_dir"
	if [ "$relay_in_method" = standalone ]; then
		load_standalone_node
		RELAY_NODE_INSTALLED_STANDALONE=1
	fi
	hash -r 2>/dev/null || :
	if ! relay_node_ready; then
		relay_count_step=INSTALL_NODE_MISSING
		relay_stop 1 "" "✗ stopped · Node.js was installed with $relay_in_label, but this shell still can't run Node.js $relay_min_node or newer" \
			"  cause: the Node.js on this machine, not Relay" \
			"  nothing else was installed · $(relay_untouched)" \
			"  next: open a new terminal and run the same command again"
	fi
	relay_os_line="$relay_os_line · Node.js $(relay_node_version) (installed with $relay_in_label)"
}

relay_sha256_file() {
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$1" 2>/dev/null | awk '{ print $1 }'
	elif command -v shasum >/dev/null 2>&1; then
		shasum -a 256 "$1" 2>/dev/null | awk '{ print $1 }'
	else
		return 1
	fi
}

# The PATH, as O01's fifth step: a line in the profile in a terminal; in CI the job is told the line to add.
relay_path_step() {
	relay_ps_bin="$1"
	relay_installed_bin="$relay_ps_bin/$relay_cmd"
	relay_path_bin="$relay_ps_bin"
	relay_path_comment="${2:-Relay}"
	if original_relay_path=$(resolve_relay_with_original_path) && [ "$original_relay_path" -ef "$relay_installed_bin" ]; then
		relay_step_set 5 done "PATH already finds $relay_cmd · nothing changed"
		[ "$relay_plain" = 1 ] && relay_say "PATH already finds $relay_cmd · nothing changed"
		relay_path_line_done="PATH already finds $relay_cmd · uninstall: $relay_cmd uninstall"
		return 0
	fi
	relay_step_set 5 running "Add $(relay_display_path "$relay_ps_bin") to PATH in $relay_profile_display"
	if [ "$relay_live" != 1 ]; then
		# Not a terminal (CI, a log file): the PATH is the job's own business, so the line is printed, not written.
		relay_say "PATH not changed (non-interactive) · add it yourself:"
		if [ -n "${GITHUB_PATH:-}" ]; then
			relay_say "  echo \"$relay_ps_bin\" >> \"\$GITHUB_PATH\""
		else
			relay_say "  $(relay_path_line)"
		fi
		relay_path_line_done="PATH not changed"
		return 0
	fi
	if ! profile=$(detect_shell_profile); then
		relay_count_outcome=INSTALL_NOT_ON_PATH
		relay_step_set 5 done "PATH not changed · no shell profile to add it to"
		relay_notes="${relay_notes}Add this to your shell profile to use $relay_cmd from new shells:
  $(relay_path_line)
"
		relay_path_line_done="PATH not changed · add the line below · uninstall: $relay_cmd uninstall"
		return 0
	fi
	if shell_profile_has_relay_path "$profile"; then
		relay_step_set 5 done "PATH line already in $relay_profile_display"
		relay_path_line_done="PATH line already in $relay_profile_display · uninstall: $relay_cmd uninstall"
		return 0
	fi
	mkdir -p "$(dirname "$profile")"
	{
		printf '\n# %s\n' "$relay_path_comment"
		printf '%s\n' "$(relay_path_line)"
	} >>"$profile"
	relay_step_set 5 done "Added $(relay_display_path "$relay_ps_bin") to PATH in $relay_profile_display"
	relay_path_line_done="PATH added to $relay_profile_display (1 line) · uninstall: $relay_cmd uninstall"
}

# The summary the block collapses to (O01's last frame, O02's top).
relay_summary() {
	relay_su_elapsed=$(relay_ds_text $(($(relay_now_ds) - relay_install_started_ds)))
	relay_su_sig=
	if [ "$relay_signature_ok" = 1 ]; then
		relay_su_sig=" · signed by Relay ✓"
	fi
	relay_su_where=$(relay_display_path "$relay_installed_bin")
	if [ "$relay_live" = 1 ]; then
		relay_live_done_line=1
		relay_live_clear
		printf '  %s· · · · · · · · · · · · · →%s  Relay %s\n\n' "$relay_c_dim" "$relay_c_reset" "$version"
		printf '  %s✓%s %srelay %s installed in %s%s\n' "$relay_c_ok" "$relay_c_reset" "$relay_c_bold" "$version" "$relay_su_elapsed" "$relay_c_reset"
		printf '    %s · sha256 %s ✓%s · no sudo\n' "$relay_su_where" "$(relay_short_digest "$relay_digest")" "$relay_su_sig"
		printf '    %s\n' "$relay_path_line_done"
		if [ -n "$relay_signature_note" ]; then
			printf '    %s\n' "$relay_signature_note"
		fi
		if relay_on_current_path; then
			printf '    new terminals will find %s; this one is ready too\n' "$relay_cmd"
		else
			printf '    new terminals will find %s\n' "$relay_cmd"
		fi
		printf '  %sread what this script does: %s · nothing is sent to Relay during install%s\n' "$relay_c_dim" "$relay_script_url" "$relay_c_reset"
		if [ -n "$relay_notes" ]; then
			printf '\n%s' "$relay_notes"
		fi
		return 0
	fi
	if [ -n "$relay_signature_note" ]; then
		relay_say "$relay_signature_note"
	fi
	if [ -n "$relay_notes" ]; then
		printf '%s' "$relay_notes" | while IFS= read -r relay_su_line; do
			relay_say "$relay_su_line"
		done
	fi
	relay_say "telemetry off (no one to ask here) · nothing was sent"
	relay_say "done in $relay_su_elapsed · exit 0"
	relay_say "next: $relay_su_where --version"
}

# Whether the shell that ran this script would start this install by name.
relay_on_current_path() {
	relay_cp_found=$(resolve_relay_with_original_path) || return 1
	[ "$relay_cp_found" -ef "$relay_installed_bin" ]
}

# ── O02: "Set up now?", read from /dev/tty so it works under curl | bash ──
# One key: 1 or enter on the first row sets up now, in this terminal; 2, s or esc leaves it for later. ↑↓ move.
# RELAY_INSTALL_SETUP=now or later answers it without asking; CI and a terminal-less run never ask.
relay_ask_setup() {
	relay_as_tty="${RELAY_INSTALLER_TTY:-/dev/tty}"
	case "$(printf '%s' "${RELAY_INSTALL_SETUP:-}" | tr '[:upper:]' '[:lower:]')" in
		now) relay_setup_answer=now; return 0 ;;
		later|no|0) relay_setup_answer=later; return 0 ;;
	esac
	relay_setup_answer=later
	[ "$relay_live" = 1 ] || return 0
	( : <>"$relay_as_tty" ) 2>/dev/null || return 0
	relay_as_sel=1
	relay_as_drawn=0
	relay_as_saved=$(stty -g <"$relay_as_tty" 2>/dev/null || :)
	stty -icanon -echo min 1 time 0 <"$relay_as_tty" 2>/dev/null || :
	printf '%s' "$relay_hide_cursor"
	while :; do
		relay_as_draw
		relay_as_key=$(dd bs=1 count=1 <"$relay_as_tty" 2>/dev/null || :)
		case "$relay_as_key" in
			"$relay_esc")
				stty min 0 time 1 <"$relay_as_tty" 2>/dev/null || :
				relay_as_rest=$(dd bs=1 count=2 <"$relay_as_tty" 2>/dev/null || :)
				stty min 1 time 0 <"$relay_as_tty" 2>/dev/null || :
				case "$relay_as_rest" in
					"[A") relay_as_sel=1 ;;
					"[B") relay_as_sel=2 ;;
					# Esc on its own (or a key this question has no use for): later.
					*) relay_setup_answer=later; break ;;
				esac
				;;
			1) relay_setup_answer=now; break ;;
			2|s|S|q) relay_setup_answer=later; break ;;
			k) relay_as_sel=1 ;;
			j) relay_as_sel=2 ;;
			""|"$(printf '\r')"|"$(printf '\n')")
				if [ "$relay_as_sel" = 1 ]; then relay_setup_answer=now; else relay_setup_answer=later; fi
				break
				;;
			"$(printf '\003')") relay_setup_answer=later; break ;;
		esac
	done
	if [ -n "$relay_as_saved" ]; then
		stty "$relay_as_saved" <"$relay_as_tty" 2>/dev/null || :
	fi
	relay_as_draw final
	printf '%s' "$relay_show_cursor"
}

relay_as_draw() {
	if [ "$relay_as_drawn" -gt 0 ]; then
		printf '\r%s[%dA%s[J' "$relay_esc" "$relay_as_drawn" "$relay_esc"
	fi
	if [ "${1:-}" = final ]; then
		if [ "$relay_setup_answer" = now ]; then
			printf '\n%s?%s Set up now? About 2 minutes: sign in, connect claude and codex, pick a repo.  %s✓ 1. Set up now%s\n' \
				"$relay_c_accent" "$relay_c_reset" "$relay_c_ok" "$relay_c_reset"
		else
			printf '\n%s?%s Set up now?  %s2. Later%s · run %s any time; it starts setup then\n' \
				"$relay_c_accent" "$relay_c_reset" "$relay_c_dim" "$relay_c_reset" "$relay_cmd"
		fi
		relay_as_drawn=0
		return 0
	fi
	if [ "$relay_as_sel" = 1 ]; then
		relay_as_r1="${relay_c_accent}❯ 1. Set up now${relay_c_reset}                  continues right here · step 1 of 4 · about 2 min"
		relay_as_r2="  2. Later — run $relay_cmd any time   ${relay_c_dim}nothing else changes; $relay_cmd starts setup when you run it${relay_c_reset}"
	else
		relay_as_r1="  1. Set up now                  ${relay_c_dim}continues right here · step 1 of 4 · about 2 min${relay_c_reset}"
		relay_as_r2="${relay_c_accent}❯ 2. Later — run $relay_cmd any time${relay_c_reset}   nothing else changes; $relay_cmd starts setup when you run it"
	fi
	printf '\n%s?%s Set up now? About 2 minutes: sign in, connect claude and codex, pick a repo.\n\n%s\n%s\n\n%s\n' \
		"$relay_c_accent" "$relay_c_reset" "$relay_as_r1" "$relay_as_r2" \
		"${relay_c_dim}enter continue · esc later · s skip · ctrl+c quit (nothing half-done is kept)${relay_c_reset}"
	relay_as_drawn=7
}

# Hands this terminal to relay's first run: the installed command, its input from /dev/tty.
relay_start_setup() {
	[ "$relay_setup_answer" = now ] || {
		if [ "$relay_live" = 1 ]; then
			printf '\nRun %s any time; it starts setup then.\n' "$(relay_on_current_path && printf '%s' "$relay_cmd" || relay_display_path "$relay_installed_bin")"
		fi
		return 0
	}
	PATH="$(dirname "$relay_installed_bin"):$PATH"
	export PATH
	relay_count_flush_marker
	relay_count_sent=1
	trap - EXIT INT TERM
	printf '\n'
	exec "$relay_installed_bin" <"${RELAY_INSTALLER_TTY:-/dev/tty}"
}

# ── The native binary (I2, decision 8) ──
# One compiled relay per platform, with no Node or npm: relay-<version>-<platform>.tar.gz, beside the npm tarball and
# listed in the same SHA256SUMS, so its checksum and signature are checked exactly as the tarball's are. It unpacks
# into ~/.relay/versions/<version>/ (the binary and the few files it reads beside itself) and ~/.relay/bin/relay is a
# link to it, so an update swaps one link and never writes over the copy that is running. A release with no native
# build for this machine, a musl Linux, or RELAY_INSTALL_METHOD=npm installs with npm, as before.

# Whether this is a musl Linux (Alpine and the like), which the native builds do not cover.
relay_is_musl() {
	for relay_im_loader in /lib/ld-musl-*; do
		[ -e "$relay_im_loader" ] && return 0
	done
	command -v ldd >/dev/null 2>&1 && ldd --version 2>&1 | grep -qi musl
}

# The native build this machine runs: darwin-arm64, darwin-x64, linux-x64 or linux-arm64. Fails when there is none.
relay_binary_platform() {
	case "$(relay_os_name)" in
		Darwin) relay_bp_os=darwin ;;
		Linux)
			relay_is_musl && return 1
			relay_bp_os=linux
			;;
		*) return 1 ;;
	esac
	case "$(relay_os_arch)" in
		arm64|aarch64) relay_bp_arch=arm64 ;;
		x86_64|amd64) relay_bp_arch=x64 ;;
		*) return 1 ;;
	esac
	printf '%s-%s' "$relay_bp_os" "$relay_bp_arch"
}

# The archive's name for a version on this platform.
relay_binary_file() {
	printf 'relay-%s-%s.tar.gz' "$1" "$relay_binary_platform_name"
}

# Whether the release's SHA256SUMS lists a file.   $1 SHA256SUMS  $2 file
relay_sums_list() {
	awk -v file="$2" '$2 == file || $2 == "*" file { found = 1 } END { exit found ? 0 : 1 }' "$1"
}

# Where the native build lives: ~/.relay, with bin/ (what PATH finds) and versions/ (each version's files).
relay_binary_root() {
	printf '%s/.relay' "${HOME:?}"
}

# Unpacks a verified archive into ~/.relay/versions/<version>, checks the binary there starts, then points
# ~/.relay/bin/relay at it. Keeps the version it replaced (to go back to) and removes older ones. On any failure it
# says why on stdout and leaves the link as it was.
#   $1 the verified archive  $2 version
relay_install_binary() {
	relay_ib_version="${2:?}"
	relay_ib_root=$(relay_binary_root)
	relay_ib_versions="${relay_ib_root:?}/versions"
	relay_ib_bin="$relay_ib_root/bin"
	relay_ib_stage="$relay_ib_versions/.partial-$relay_ib_version-$$"
	mkdir -p "$relay_ib_versions" "$relay_ib_bin" || { printf 'could not create %s\n' "$relay_ib_root"; return 1; }
	rm -rf "${relay_ib_stage:?}"
	mkdir "$relay_ib_stage" || { printf 'could not create %s\n' "$relay_ib_stage"; return 1; }
	if ! tar -xzf "$1" -C "$relay_ib_stage" 2>&1; then
		rm -rf "${relay_ib_stage:?}"
		printf 'the archive did not unpack\n'
		return 1
	fi
	# The archive holds one folder, relay/, with the binary of the same name inside it.
	if [ ! -f "$relay_ib_stage/relay/$relay_cmd" ] || [ -L "$relay_ib_stage/relay/$relay_cmd" ]; then
		rm -rf "${relay_ib_stage:?}"
		printf 'the archive has no %s binary in it\n' "$relay_cmd"
		return 1
	fi
	chmod 755 "$relay_ib_stage/relay/$relay_cmd"
	if ! relay_ib_smoke=$("$relay_ib_stage/relay/$relay_cmd" --version 2>&1 </dev/null); then
		rm -rf "${relay_ib_stage:?}"
		printf '%s\n' "$relay_ib_smoke" | tail -n 6
		return 1
	fi
	relay_ib_previous=
	if [ -L "$relay_ib_bin/$relay_cmd" ]; then
		relay_ib_previous=$(readlink "$relay_ib_bin/$relay_cmd" 2>/dev/null || :)
		relay_ib_previous=$(basename "$(dirname "$relay_ib_previous")")
	fi
	rm -rf "${relay_ib_versions:?}/${relay_ib_version:?}"
	if ! mv "$relay_ib_stage/relay" "$relay_ib_versions/$relay_ib_version"; then
		printf 'could not move relay into %s\n' "$relay_ib_versions/$relay_ib_version"
		return 1
	fi
	rm -rf "${relay_ib_stage:?}"
	# A new link beside the old one, then one rename: a shell that starts relay mid-install finds one or the other.
	rm -f "$relay_ib_bin/.$relay_cmd.$$"
	if ! { ln -s "../versions/$relay_ib_version/$relay_cmd" "$relay_ib_bin/.$relay_cmd.$$" &&
		mv -f "$relay_ib_bin/.$relay_cmd.$$" "$relay_ib_bin/$relay_cmd"; }; then
		rm -f "$relay_ib_bin/.$relay_cmd.$$"
		printf 'could not point %s at %s\n' "$relay_ib_bin/$relay_cmd" "$relay_ib_versions/$relay_ib_version"
		return 1
	fi
	for relay_ib_old in "$relay_ib_versions"/*; do
		[ -d "$relay_ib_old" ] || continue
		relay_ib_name=$(basename "$relay_ib_old")
		if [ "$relay_ib_name" = "$relay_ib_version" ] || [ "$relay_ib_name" = "$relay_ib_previous" ]; then
			continue
		fi
		rm -rf "${relay_ib_old:?}"
	done
	return 0
}

# Release signatures without Node (D-78, I2): the native build goes onto machines with no Node, so its SHA256SUMS.sig
# is checked with OpenSSH's own ssh-keygen, under the rules of scripts/lib/release-signature.mjs and with its reasons:
# every signature in the file is tried, each person counts once, a key that is not pinned or a signature for another
# namespace does not count, and at least <required> different people must have signed. Prints "verified
# <principal>,<principal>" or "failed <reason>", as that program does.
#   $1 file  $2 signature file  $3 allowed signers file  $4 namespace  $5 required
relay_verify_signature_ssh() {
	relay_vs_dir="$(dirname "$3")/sig-blocks"
	relay_vs_unreadable="the signature file is not a list of SSH signatures"
	if ! command -v ssh-keygen >/dev/null 2>&1; then
		printf 'failed the signature could not be checked (this machine has no ssh-keygen)\n'
		return 1
	fi
	rm -rf "${relay_vs_dir:?}"
	mkdir -p "$relay_vs_dir"
	if [ "$(wc -c <"$2")" -gt 65536 ]; then
		printf 'failed %s\n' "$relay_vs_unreadable"
		return 1
	fi
	# One file per armored signature; anything outside a BEGIN/END pair except blank lines is unreadable.
	if ! awk -v dir="$relay_vs_dir" '
		/^[ \t\r]*$/ && !inside { next }
		/^-----BEGIN SSH SIGNATURE-----[ \t\r]*$/ && !inside { n++; inside = 1; file = dir "/" n; print "-----BEGIN SSH SIGNATURE-----" > file; next }
		/^-----END SSH SIGNATURE-----[ \t\r]*$/ && inside { print "-----END SSH SIGNATURE-----" > file; close(file); inside = 0; next }
		inside { sub(/[ \t\r]+$/, ""); if ($0 !~ /^[A-Za-z0-9+\/=]+$/) bad = 1; print > file; next }
		{ bad = 1 }
		END { if (bad || inside || n == 0 || n > 16) exit 1; print n }
	' "$2" >"$relay_vs_dir/count"; then
		printf 'failed %s\n' "$relay_vs_unreadable"
		return 1
	fi
	relay_vs_principals=
	relay_vs_count=0
	relay_vs_reasons=
	relay_vs_i=1
	relay_vs_n=$(cat "$relay_vs_dir/count")
	while [ "$relay_vs_i" -le "$relay_vs_n" ]; do
		relay_vs_block="$relay_vs_dir/$relay_vs_i"
		relay_vs_i=$((relay_vs_i + 1))
		if ! relay_vs_who=$(ssh-keygen -Y find-principals -s "$relay_vs_block" -f "$3" </dev/null 2>"$relay_vs_dir/err"); then
			if grep -qi "parse" "$relay_vs_dir/err"; then
				relay_vs_reasons="$relay_vs_reasons unreadable"
			else
				relay_vs_reasons="$relay_vs_reasons unknownKey"
			fi
			continue
		fi
		relay_vs_who=$(printf '%s\n' "$relay_vs_who" | sed -n '1p')
		if ssh-keygen -Y verify -f "$3" -I "$relay_vs_who" -n "$4" -s "$relay_vs_block" <"$1" >/dev/null 2>"$relay_vs_dir/err"; then
			case ",$relay_vs_principals," in
				*",$relay_vs_who,"*) ;;
				*)
					relay_vs_principals="${relay_vs_principals:+$relay_vs_principals,}$relay_vs_who"
					relay_vs_count=$((relay_vs_count + 1))
					;;
			esac
		elif grep -qi "namespace" "$relay_vs_dir/err"; then
			relay_vs_reasons="$relay_vs_reasons namespace"
		elif grep -qi "presence" "$relay_vs_dir/err"; then
			relay_vs_reasons="$relay_vs_reasons touch"
		else
			relay_vs_reasons="$relay_vs_reasons mismatch"
		fi
	done
	rm -rf "${relay_vs_dir:?}"
	if [ "$relay_vs_count" -ge "$5" ]; then
		printf 'verified %s\n' "$relay_vs_principals"
		return 0
	fi
	# The worst reason, in the order release-signature.mjs uses; else how many signed.
	for relay_vs_worst in mismatch touch namespace unknownKey unreadable; do
		case " $relay_vs_reasons " in
			*" $relay_vs_worst "*)
				case "$relay_vs_worst" in
					mismatch) printf 'failed the signature does not match the file\n' ;;
					touch) printf 'failed the hardware key that signed it was not touched\n' ;;
					namespace) printf 'failed it is signed for something other than a Relay release\n' ;;
					unknownKey) printf "failed it is signed by a key that is not one of Relay's release keys\\n" ;;
					unreadable) printf 'failed %s\n' "$relay_vs_unreadable" ;;
				esac
				return 1
				;;
		esac
	done
	printf 'failed it is signed by %s of the %s people who must sign (%s)\n' "$relay_vs_count" "$5" \
		"$(printf '%s' "${relay_vs_principals:-nobody}" | sed 's/,/, /g')"
	return 1
}

# Whether Node can run the signature checker install.sh carries (the npm path always can).
relay_node_can_verify() {
	command -v node >/dev/null 2>&1 && node -e 'process.exit(0)' >/dev/null 2>&1
}

# Step 4 for the native build: unpack, check it starts, point ~/.relay/bin/relay at it.
relay_binary_step() {
	relay_count_step=INSTALL_BROKEN
	relay_bs_root=$(relay_binary_root)
	relay_step_set 4 running "Installing to $(relay_display_path "$relay_bs_root/bin") (no sudo)"
	relay_bs_log="$relay_dl_dir/binary.log"
	relay_install_binary "$tarball_path" "$version" >"$relay_bs_log" 2>&1 </dev/null &
	if relay_live_wait $!; then
		:
	else
		relay_bs_tail=$(tail -n 6 "$relay_bs_log" 2>/dev/null | sed 's/^/    /')
		relay_stop 4 "" "✗ stopped · relay $version was downloaded and verified, but didn't install" \
			"  cause: Relay's build for $relay_binary_platform_name, not your machine (it passed its checksum)" \
			"$relay_bs_tail" \
			"  nothing else changed: a relay you had before still starts · $(relay_untouched)" \
			"  next: report it with the lines above: relayevals.com/docs" \
			"        or install with npm instead: RELAY_INSTALL_METHOD=npm"
	fi
	relay_installed_bin="$relay_bs_root/bin/$relay_cmd"
	relay_install_bin_dir="$relay_bs_root/bin"
	relay_path_comment="Relay native binary"
	relay_step_set 4 done "Installed $(relay_display_path "$relay_installed_bin") (no sudo)"
	[ "$relay_plain" = 1 ] && relay_say "installed $relay_installed_bin (no sudo)"
	return 0
}

# The whole inline install: five steps, the summary, then "Set up now?".
relay_main_inline() {
	relay_install_started_ds=$(relay_now_ds)
	relay_ui_init
	command -v curl >/dev/null 2>&1 || { relay_live=0; relay_plain=1; relay_fail_tool 2 curl; }
	command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 || {
		relay_sl_3="Verify checksum"
		relay_fail_tool 3 "sha256sum or shasum"
	}

	relay_count_step=INSTALL_NODE_MISSING
	relay_sl_1="Check this machine"
	relay_sl_2="Download relay"
	relay_sl_3="Verify checksum"
	if [ -n "$relay_release_signers" ] || relay_signature_required; then
		relay_sl_3="Verify checksum and signature"
	fi
	relay_sl_4="Install relay (no sudo)"
	relay_sl_5="Add relay to PATH in $relay_profile_display"
	relay_check_machine
	relay_choose_method
	relay_live_start
	relay_step_set 1 running "Checking this machine"
	# The native build needs no Node; npm does, so Node is checked (and installed) only for npm.
	if [ "$relay_method" = npm ]; then
		relay_node_step
	fi
	relay_step_set 1 done "$relay_os_line"
	[ "$relay_plain" = 1 ] && relay_say "$(printf '%s' "$relay_os_line" | sed 's/^Found/found/')"

	# Step 2: which version, then the package, with the bar.
	relay_count_step=INSTALL_DOWNLOAD
	relay_step_set 2 running "Finding the latest relay"
	relay_dl_dir=$(create_temp_dir)
	relay_download_dir="$relay_dl_dir"
	if [ -n "${1:-}" ] && [ "$1" != stable ] && [ "$1" != beta ]; then
		version=$(normalize_version "$1")
	elif [ -n "${RELAY_VERSION:-}" ]; then
		version=$(normalize_version "$RELAY_VERSION")
	else
		relay_channel="${1:-$relay_release_channel}"
		case "$relay_channel" in
			stable|beta) ;;
			*) relay_stop 2 "" "✗ stopped · there is no release channel called $relay_channel" \
				"  cause: RELAY_RELEASE_CHANNEL on this machine" "  next: use stable or beta" ;;
		esac
		relay_fetch "$relay_base_url/$relay_channel" "$relay_dl_dir/channel" ||
			relay_fail_fetch 2 "the $relay_channel release" "$relay_base_url/$relay_channel"
		version=$(normalize_version "$(tr -d '[:space:]' <"$relay_dl_dir/channel")")
	fi
	relay_count_version="$version"
	checksums_url="$relay_base_url/releases/v$version/SHA256SUMS"
	relay_step_set 2 running "Downloading relay $version"
	relay_fetch "$checksums_url" "$relay_dl_dir/SHA256SUMS" ||
		relay_fail_fetch 2 "relay $version's checksums" "$checksums_url"
	# The native build when this release lists one for this machine; npm otherwise (the fallback, for one release).
	tarball_name="$relay_package-$version.tgz"
	if [ "$relay_method" = binary ]; then
		if relay_sums_list "$relay_dl_dir/SHA256SUMS" "$(relay_binary_file "$version")"; then
			tarball_name=$(relay_binary_file "$version")
		else
			relay_binary_fallback "$version"
		fi
	fi
	tarball_url="$relay_base_url/releases/v$version/$tarball_name"
	tarball_path="$relay_dl_dir/$tarball_name"
	signature_path="$relay_dl_dir/SHA256SUMS.sig"
	if [ -n "$relay_release_signers" ] || relay_signature_required; then
		curl -fsSL --connect-timeout 10 "$checksums_url.sig" -o "$signature_path" 2>/dev/null || rm -f "$signature_path"
	fi
	[ "$relay_plain" = 1 ] && relay_say "downloading relay $version"
	relay_fetch "$tarball_url" "$tarball_path" progress || relay_fail_fetch 2 "relay $version" "$tarball_url"
	relay_download_bytes=$(wc -c <"$tarball_path")
	relay_download_bytes=$((relay_download_bytes + 0))
	relay_step_set 2 done "Downloaded relay $version · $(relay_mb_text "$relay_download_bytes") in $(relay_ds_text "$relay_fetch_elapsed")"
	[ "$relay_plain" = 1 ] && relay_say "downloaded $(relay_mb_text "$relay_download_bytes") in $(relay_ds_text "$relay_fetch_elapsed")"

	# Step 3: the checksum (and the signature, once Relay's release keys are pinned).
	relay_count_step=INSTALL_CHECKSUM
	relay_step_set 3 running "$relay_sl_3"
	relay_expected=$(awk -v file="$tarball_name" '$2 == file || $2 == "*" file { print $1; exit }' "$relay_dl_dir/SHA256SUMS")
	if [ -z "$relay_expected" ]; then
		relay_stop 3 "" "✗ stopped · relay $version's checksums don't list $tarball_name" \
			"  cause: Relay's release, not your machine" \
			"  nothing was installed · the download was deleted · $(relay_untouched)" \
			"  next: run the same command again in a few minutes · report it: relayevals.com/security"
	fi
	relay_digest=$(relay_sha256_file "$tarball_path" || :)
	if [ "$relay_digest" != "$relay_expected" ]; then
		rm -f "$tarball_path"
		relay_fail_checksum "$relay_expected" "${relay_digest:-none}" "$(printf '%s' "$checksums_url" | sed 's#^[a-z]*://##')"
	fi
	verify_relay_release_signature "$version" "$relay_dl_dir/SHA256SUMS" "$signature_path"
	relay_step_set 3 done "Verified sha256 $(relay_short_digest "$relay_digest") ✓$([ "$relay_signature_ok" = 1 ] && printf ' · signed by Relay ✓')"
	[ "$relay_plain" = 1 ] && relay_say "sha256 $(relay_short_digest "$relay_digest") ok$([ "$relay_signature_ok" = 1 ] && printf ' · signature ok')"

	# Step 4: the native build goes into ~/.relay/bin; or npm installs the verified package (into a folder this account
	# owns), then relay must start.
	if [ "$relay_method" = binary ]; then
		relay_binary_step
	else
		relay_npm_step
	fi
	rm -rf "$relay_dl_dir"
	relay_download_dir=

	# Step 5: PATH. Another relay first on PATH stays, and is named.
	relay_count_step=INSTALL_NOT_ON_PATH
	relay_path_step "$relay_install_bin_dir" "$relay_path_comment"
	if relay_other=$(relay_shadowing_command_inline); then
		relay_count_outcome=INSTALL_NOT_ON_PATH
		relay_notes="${relay_notes}$(relay_shadow_note "$relay_other")
"
	fi
	if [ -n "$relay_binary_fallback_note" ]; then
		relay_notes="${relay_notes}${relay_binary_fallback_note}
"
	fi
	if [ -n "$relay_retired_alias_removed" ]; then
		relay_notes="${relay_notes}Removed $(relay_display_path "$relay_retired_alias_removed"). It started the retired relayevals CLI instead of this install; open a new terminal before you type $relay_cmd.
"
		relay_retired_alias_removed=
	fi
	if [ -n "$relay_uv_profile_note" ]; then
		relay_notes="${relay_notes}${relay_uv_profile_note}
"
	fi
	relay_count_finished=1
	relay_summary
	relay_ask_setup
	relay_start_setup
}

# Step 4 with npm (the fallback): npm installs the verified package, then relay must start.
relay_npm_step() {
	relay_count_step=INSTALL_NPM_FAILED
	if [ -n "$relay_user_npm_prefix" ]; then
		relay_npm_where="$relay_user_npm_prefix"
	else
		relay_npm_where=$(npm prefix -g 2>/dev/null || printf 'npm')
	fi
	relay_step_set 4 running "Installing to $(relay_display_path "$relay_npm_where") (no sudo)"
	clear_stale_relay_alias >/dev/null
	clear_retired_gate_alias
	relay_npm_log="$relay_dl_dir/npm.log"
	if [ "$relay_bootstrap_kernel_on_install" = 1 ]; then
		relay_profiles_before=$(relay_profile_snapshot)
		run_relay_npm_install "$tarball_path" RELAY_BOOTSTRAP_TOOLS_ON_INSTALL=1 RELAY_BOOTSTRAP_KERNEL_ON_INSTALL=1 RELAY_INSTALL_UV=1 \
			>"$relay_npm_log" 2>&1 </dev/null &
	else
		run_relay_npm_install "$tarball_path" RELAY_BOOTSTRAP_TOOLS_ON_INSTALL=1 >"$relay_npm_log" 2>&1 </dev/null &
	fi
	if relay_live_wait $!; then
		:
	else
		relay_npm_status=$?
		relay_npm_tail=$(tail -n 8 "$relay_npm_log" 2>/dev/null | sed 's/^/    /')
		relay_stop 4 "" "✗ stopped · npm couldn't install relay (exit $relay_npm_status)" \
			"  cause: npm on this machine, not the download (it passed its checksum)" \
			"$relay_npm_tail" \
			"  $(relay_untouched)" \
			"  next: run the same command again · still failing? send the lines above to relayevals.com/docs"
	fi
	if [ "$relay_bootstrap_kernel_on_install" = 1 ]; then
		relay_note_uv_profile_edits "$relay_profiles_before" "$(relay_profile_snapshot)" >/dev/null
	fi
	relay_count_step=INSTALL_BROKEN
	if [ "${RELAY_NODE_INSTALLED_STANDALONE:-0}" = 1 ]; then
		relay_install_bin_dir="$RELAY_STANDALONE_NODE_BIN"
		relay_path_comment="Relay standalone Node.js"
	elif [ -n "$relay_user_npm_prefix" ]; then
		relay_install_bin_dir="$relay_user_npm_prefix/bin"
		relay_path_comment="Relay npm folder"
	else
		relay_install_bin_dir=$(relay_npm_bin_dir || printf '')
		relay_path_comment="Relay: npm global bin folder"
	fi
	relay_installed_bin="$relay_install_bin_dir/$relay_cmd"
	if [ ! -x "$relay_installed_bin" ] && relay_found=$(command -v "$relay_cmd" 2>/dev/null); then
		relay_installed_bin="$relay_found"
		relay_install_bin_dir=$(dirname "$relay_found")
	fi
	if ! relay_smoke=$("$relay_installed_bin" --version 2>&1); then
		relay_smoke=$(printf '%s\n' "$relay_smoke" | tail -n 6 | sed 's/^/    /')
		relay_stop 4 "" "✗ stopped · relay was installed but doesn't start" \
			"  cause: Relay's package, not your machine" \
			"$relay_smoke" \
			"  $(relay_untouched)" \
			"  next: report it with the lines above: relayevals.com/docs"
	fi
	relay_step_set 4 done "Installed $(relay_display_path "$relay_installed_bin") (no sudo)"
	[ "$relay_plain" = 1 ] && relay_say "installed $relay_installed_bin (no sudo)"
	return 0
}

# Which way relay goes in (I2): the native build on a machine it covers, unless RELAY_INSTALL_METHOD=npm; npm
# otherwise. RELAY_INSTALL_METHOD=binary refuses a machine with no native build rather than fall back.
relay_choose_method() {
	case "$(printf '%s' "$relay_install_method" | tr '[:upper:]' '[:lower:]')" in
		auto|'') relay_install_method=auto ;;
		binary|native) relay_install_method=binary ;;
		npm) relay_install_method=npm ;;
		*)
			relay_stop 1 "" "✗ stopped · RELAY_INSTALL_METHOD is $relay_install_method, which is not a way to install relay" \
				"  cause: RELAY_INSTALL_METHOD on this machine, not Relay" \
				"  nothing was downloaded or installed · $(relay_untouched)" \
				"  next: set it to binary or npm, or unset it"
			;;
	esac
	relay_method=npm
	if [ "$relay_install_method" != npm ] && [ -n "${HOME:-}" ] &&
		relay_binary_platform_name=$(relay_binary_platform); then
		relay_method=binary
		relay_sl_4="Install to ~/.relay/bin (no sudo)"
		relay_sl_5="Add ~/.relay/bin to PATH in $relay_profile_display"
	elif [ "$relay_install_method" = binary ]; then
		relay_stop 1 "" "✗ stopped · there is no native build of relay for this machine ($(relay_os_name) $(relay_os_arch)$(relay_is_musl && printf ', musl'))" \
			"  cause: the native builds cover macOS and glibc Linux on x86_64 and arm64" \
			"  nothing was downloaded or installed · $(relay_untouched)" \
			"  next: install with npm instead: RELAY_INSTALL_METHOD=npm"
	fi
}

# Node for the npm path: Node.js is checked and, when missing or too old, installed (O01 step 1).
relay_node_step() {
	if ! relay_node_ready; then
		relay_install_node_inline
	else
		relay_os_line="$relay_os_line · Node.js $(relay_node_version)"
	fi
	relay_count_step=INSTALL_NPM_FAILED
	choose_npm_prefix
}

# The release has no native build for this machine: npm installs it instead, and the summary says why. Node is
# checked (and installed) now, back on step 1, since the native build would not have needed it.
#   $1 version
relay_binary_fallback() {
	if [ "$relay_install_method" = binary ]; then
		relay_stop 2 "" "✗ stopped · relay $1 has no native build for $relay_binary_platform_name" \
			"  cause: Relay's release, not your machine" \
			"  nothing was installed · $(relay_untouched)" \
			"  next: install with npm instead: RELAY_INSTALL_METHOD=npm"
	fi
	relay_method=npm
	relay_binary_fallback_note="relay $1 has no native build for $relay_binary_platform_name, so npm installed it."
	relay_sl_4="Install relay (no sudo)"
	relay_sl_5="Add relay to PATH in $relay_profile_display"
	# The Node checks keep their own `version`; the release's is put back after them.
	relay_bf_version="$1"
	relay_node_step
	version="$relay_bf_version"
	relay_step_set 1 done "$relay_os_line"
	[ "$relay_plain" = 1 ] && relay_say "$(printf '%s' "$relay_os_line" | sed 's/^Found/found/') (no native build of $1 for $relay_binary_platform_name: npm installs it)"
	relay_count_step=INSTALL_DOWNLOAD
	relay_step_set 2 running "Downloading relay $1"
}

# What to say about another relay first on this shell's PATH. An earlier npm install is expected when the native
# build replaces it: the PATH line puts ~/.relay/bin first, so new terminals start the native build.
#   $1 the other relay
relay_shadow_note() {
	if [ "$relay_method" = binary ] && case "$(cd "$(dirname "$1")" 2>/dev/null && pwd -P)/$(readlink "$1" 2>/dev/null)" in
		*node_modules/relay-worker*) true ;;
		*) false ;;
	esac; then
		printf '%s\n' "An earlier npm install of $relay_cmd is first on this shell's PATH: $1" \
			"New terminals start $(relay_display_path "$relay_installed_bin"); remove the npm copy any time: npm uninstall -g relay-worker"
		return 0
	fi
	printf '%s\n' "Typing $relay_cmd starts a different program first on your PATH:" \
		"  $1" \
		"Remove that one, or put $(relay_display_path "$relay_install_bin_dir") earlier in your PATH. Until then, run $relay_installed_bin."
}

# The `relay` a new shell would start, when it is not the copy just installed.
relay_shadowing_command_inline() {
	relay_sc_first=$(resolve_relay_with_original_path) || return 1
	[ -e "$relay_installed_bin" ] || return 1
	[ "$relay_sc_first" -ef "$relay_installed_bin" ] && return 1
	printf '%s' "$relay_sc_first"
}

# ── One line per step ────────────────────────────────────────────────────────
# A step prints "  Downloading Relay..." while it runs (in a terminal), then "✓ Downloaded Relay 0.6.122 · 3 s" in its
# place. What a step's commands print is kept back and shown only when the step fails.

relay_quiet() {
	[ "$relay_interactive" != 1 ]
}

relay_elapsed() {
	relay_elapsed_now=$(date +%s)
	printf '%s s' "$((relay_elapsed_now - $1))"
}

relay_step_start() {
	relay_step_label="$1"
	relay_step_started=$(date +%s)
	relay_quiet || return 0
	# On stderr, so a step started around a $(...) never ends up inside its value.
	if [ "$relay_step_tty" = 1 ] && [ -t 2 ]; then
		printf '  %s...' "$1" >&2
		relay_step_open=1
	fi
}

# Clears the running step's line, so whatever comes next starts on a clean line.
relay_step_break() {
	if [ "$relay_step_open" = 1 ]; then
		printf '\r%s' "$relay_clear_line" >&2
		relay_step_open=0
	fi
}

relay_step_done() {
	relay_quiet || return 0
	relay_step_break
	printf '✓ %s · %s\n' "$1" "$(relay_elapsed "${relay_step_started:-$relay_install_started}")"
	relay_step_label=
}

relay_step_fail() {
	relay_quiet || return 0
	relay_step_break
	[ -n "$relay_step_label" ] || return 0
	printf '✗ %s did not finish:\n' "$relay_step_label" >&2
	relay_step_label=
}

relay_restore_terminal() {
	relay_step_break
	if [ -n "${relay_as_saved:-}" ]; then
		stty "$relay_as_saved" <"${RELAY_INSTALLER_TTY:-/dev/tty}" 2>/dev/null || :
		relay_as_saved=
	fi
	if [ "${relay_live:-0}" = 1 ]; then
		printf '%s[?7h%s%s' "$relay_esc" "$relay_show_cursor" "$relay_reset"
	fi
	if [ "${relay_screen_enabled:-0}" = 1 ]; then
		if ( : <>/dev/tty ) 2>/dev/null; then
			printf '%s%s' "$relay_reset" "$relay_show_cursor" >/dev/tty
		else
			printf '%s%s' "$relay_reset" "$relay_show_cursor" >&2
		fi
	fi
}

relay_init_screen() {
	if [ "$relay_interactive" != 1 ]; then
		return
	fi
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
		if relay_quiet; then
			# Run apart (as the screen does), so set -e still holds inside, and keep the output for a failure.
			output_dir=$(create_temp_dir)
			output_file="$output_dir/output"
			"$@" >"$output_file" 2>&1 </dev/null &
			command_pid=$!
			if wait "$command_pid"; then
				command_status=0
			else
				command_status=$?
			fi
			if [ "$command_status" -ne 0 ]; then
				relay_step_fail
				if [ -s "$output_file" ]; then
					cat "$output_file" >&2
				fi
			fi
			rm -rf "$output_dir"
			return "$command_status"
		fi
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
	relay_step_start "Checking Node.js"
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
	elif relay_quiet; then
		if [ "$preflight_status" -eq 0 ]; then
			relay_step_done "Node.js $(node --version 2>/dev/null | sed 's/^v//') is ready"
		else
			relay_step_break
			relay_step_label=
			# The first time, installing Node.js says it in one line; after an install that did not work, say why.
			if [ "$relay_node_install_attempted" = 1 ]; then
				cat "$preflight_file"
			fi
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

	if relay_quiet; then
		printf 'Relay needs Node.js %s or newer, so it is installing it with %s.\n' "$relay_min_node" "$label"
		if node_install_needs_sudo "$method"; then
			if relay_prompt_yes_no \
				"Install Node.js with $label?" \
				"Installing Node.js with $label needs your password (sudo). Nothing else will ask." \
				"Continue? [Y/n]"; then
				:
			else
				prompt_status=$?
				if [ "$prompt_status" -eq 2 ]; then
					printf 'Installing it needs sudo, and there is no terminal to ask for your password.\n'
				fi
				printf 'Install Node.js %s or newer, then run this installer again.\n' "$relay_min_node"
				return 1
			fi
		fi
		install_node_npm "$method" "$label"
		return
	fi

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
	relay_node_install_attempted=1

	if relay_quiet; then
		if node_install_needs_sudo "$method"; then
			sudo -v
		fi
		relay_step_start "Installing Node.js with $label"
		relay_run_quiet_with_animation_steps \
			"Installing Node.js and npm" \
			"Installing Node.js and npm" \
			"Using $label." \
			run_node_install_method "$method"
		if [ "$method" = standalone ]; then
			load_standalone_node
			RELAY_NODE_INSTALLED_STANDALONE=1
		fi
		hash -r
		relay_step_done "Installed Node.js $(node --version 2>/dev/null | sed 's/^v//') with $label"
		return 0
	fi

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
	if relay_quiet; then
		configure_relay_path_quietly
		return 0
	fi
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

# Without questions: a shell that already finds this install is left alone; otherwise one line goes into the shell
# profile, and the installer says which file. With no profile to write (no HOME), it prints the line to add.
configure_relay_path_quietly() {
	if original_relay_path=$(resolve_relay_with_original_path); then
		case "$original_relay_path" in
			"$relay_path_bin/"*)
				print_relay_welcome
				return 0
				;;
		esac
	fi
	relay_step_start "Adding Relay to your PATH"
	profile=$(detect_shell_profile) || {
		relay_step_break
		relay_step_label=
		print_relay_path_manual_instructions
		return 0
	}
	if shell_profile_has_relay_path "$profile"; then
		relay_step_done "Your PATH line for Relay is already in $(relay_display_path "$profile")"
	else
		mkdir -p "$(dirname "$profile")"
		{
			printf '\n# %s\n' "$relay_path_comment"
			printf '%s\n' "$(relay_path_line)"
		} >>"$profile"
		relay_step_done "Added Relay to your PATH in $(relay_display_path "$profile")"
	fi
	print_retired_alias_note
	print_relay_claude_plan_reminder
	relay_finish_hint="open a new terminal, then run: $relay_cmd"
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
	relay_finish_hint="add that line, then run: $relay_cmd"
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

	# Only fetched once release keys are pinned (or a signature is required): until then the download is what it was.
	signature_path="$download_dir/SHA256SUMS.sig"
	if [ -n "$relay_release_signers" ] || relay_signature_required; then
		if ! curl -fsSL "$checksums_url.sig" -o "$signature_path" 2>/dev/null; then
			rm -f "$signature_path"
		fi
	fi

	relay_run_quiet_with_animation \
		"Downloading Relay" \
		"Downloading Relay v$version" \
		"Fetching the verified package." \
		curl -fsSL "$tarball_url" -o "$tarball_path"
	relay_step_done "Downloaded Relay $version"

	relay_step_start "Checking the download"
	verify_relay_package_checksum "$checksums_path" "$tarball_path"
	relay_step_done "Checked the download (SHA-256)"
	verify_relay_release_signature "$version" "$checksums_path" "$signature_path"
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

# Release signatures (D-78). SHA256SUMS lists every file of a release, so its signatures cover the package just
# checked against it. RELAY_REQUIRE_SIGNATURE=1 refuses a release whose signatures do not verify, =0 never does, and
# unset takes the default pinned above (warn-only: say so, and install what passed its SHA-256 checksum).
relay_signature_required() {
	case "${RELAY_REQUIRE_SIGNATURE:-}" in
		1|true|yes|required) return 0 ;;
		0|false|no|warn) return 1 ;;
	esac
	[ "$relay_require_signature_default" = 1 ]
}

relay_signature_refuse() {
	if relay_quiet; then
		# Inline (O10): the step stops, with whose it is and what to do next.
		relay_sr_first=$(printf '%s' "$1" | sed 's/^error: //')
		shift
		relay_stop 3 "" "✗ stopped · $relay_sr_first" \
			"  cause: Relay's release, not your machine · the download was deleted · $(relay_untouched)" \
			"$@" \
			"  next: run the same command again in a few minutes · fails twice? report it: relayevals.com/security"
	fi
	relay_restore_terminal
	printf '\n' >&2
	for relay_refusal_line in "$@"; do
		printf '%s\n' "$relay_refusal_line" >&2
	done
	exit 1
}

relay_signature_tell() {
	relay_signature_note="$1"
	# Inline, the summary says it; the screen says it once it is down.
	if relay_quiet; then
		return 0
	fi
	if [ "$relay_screen_enabled" != 1 ]; then
		printf '%s\n' "$relay_signature_note"
	fi
}

#   $1 version  $2 SHA256SUMS  $3 SHA256SUMS.sig (absent when the release has none)
verify_relay_release_signature() {
	signature_version="$1"
	signature_message="$2"
	signature_file="$3"
	if [ -z "$relay_release_signers" ]; then
		relay_signature_required || return 0
		relay_signature_refuse \
			"error: this installer has no release keys to check Relay v$signature_version's signature with, and a signature is required. Nothing was installed."
	fi
	if [ ! -s "$signature_file" ]; then
		if relay_signature_required; then
			relay_signature_refuse \
				"error: Relay v$signature_version has no release signature, and Relay requires one. Nothing was installed." \
				"To install it with only its SHA-256 checksum, run again with RELAY_REQUIRE_SIGNATURE=0."
		fi
		relay_signature_tell "Warning: Relay v$signature_version has no release signature. Installing it anyway: it passed its SHA-256 checksum."
		return 0
	fi

	signature_dir=$(dirname "$signature_message")
	printf '%s\n' "$relay_release_signers" >"$signature_dir/allowed_signers"
	# With Node (always, on the npm path) the checker this script carries; without it (the native build) ssh-keygen,
	# under the same rules and with the same reasons.
	if relay_node_can_verify; then
		relay_write_signature_verifier "$signature_dir/relay-release-signature.mjs"
		if signature_result=$(node "$signature_dir/relay-release-signature.mjs" "$signature_message" "$signature_file" \
			"$signature_dir/allowed_signers" "$relay_signature_namespace" "$relay_signatures_required" 2>/dev/null); then
			:
		fi
	elif signature_result=$(relay_verify_signature_ssh "$signature_message" "$signature_file" \
		"$signature_dir/allowed_signers" "$relay_signature_namespace" "$relay_signatures_required" 2>/dev/null); then
		:
	fi
	case "$signature_result" in
		"verified "*)
			relay_signature_ok=1
			relay_quiet || relay_signature_tell "✓ Verified: signed by Relay"
			return 0
			;;
		"failed "*) signature_reason="${signature_result#failed }" ;;
		*) signature_reason="the signature could not be checked" ;;
	esac
	if relay_signature_required; then
		relay_signature_refuse \
			"error: Relay v$signature_version's release signature did not verify: $signature_reason. Nothing was installed. Please tell arnav@relayevals.com."
	fi
	relay_signature_tell "Warning: Relay v$signature_version's release signature did not verify: $signature_reason. Installing it anyway: it passed its SHA-256 checksum. RELAY_REQUIRE_SIGNATURE=1 refuses a download like this."
}

# BEGIN RELAY SIGNATURE VERIFIER: scripts/lib/release-signature.mjs, copied by scripts/sync-release-trust.mjs. Do not edit here.
relay_write_signature_verifier() {
	cat >"$1" <<'RELAY_SIGNATURE_VERIFIER'
// Checks a release file's OpenSSH signatures (`ssh-keygen -Y sign`) against pinned release keys, in Node alone.
//
// install.sh carries a copy of this file, byte for byte, between its RELAY SIGNATURE VERIFIER markers and runs it
// with the Node it installs Relay with; scripts/sync-release-trust.mjs writes that copy and `--check` fails when the
// two differ. Relay's own `relay update` has the same rules in TypeScript (packages/coding-agent/src/utils/
// release-signature.ts), and both are run against the same signatures in the tests. No dependency: node: built-ins only.
//
// The format is OpenSSH's SSHSIG (PROTOCOL.sshsig). A signature file may hold several signatures one after another,
// one per release key that signed. Keys: ssh-ed25519, and the hardware-key types sk-ssh-ed25519@openssh.com and
// sk-ecdsa-sha2-nistp256@openssh.com, whose signatures must say the key was touched.
//
// As a program: node release-signature.mjs <file> <signature file> <allowed signers file> <namespace> <required>
// prints "verified <principal>,<principal>" and exits 0, or prints "failed <reason>" and exits 1.

import { createHash, createPublicKey, verify } from "node:crypto";
import { readFileSync, realpathSync } from "node:fs";
import { fileURLToPath } from "node:url";

const MAGIC = Buffer.from("SSHSIG");
const BEGIN = "-----BEGIN SSH SIGNATURE-----";
const END = "-----END SSH SIGNATURE-----";
const MAX_BUNDLE_BYTES = 64 * 1024;
const MAX_SIGNATURES = 16;
const USER_PRESENT = 0x01;
const KEY_TYPES = new Set(["ssh-ed25519", "sk-ssh-ed25519@openssh.com", "sk-ecdsa-sha2-nistp256@openssh.com"]);

export const REASONS = {
	unreadable: "the signature file is not a list of SSH signatures",
	unknownKey: "it is signed by a key that is not one of Relay's release keys",
	mismatch: "the signature does not match the file",
	namespace: "it is signed for something other than a Relay release",
	touch: "the hardware key that signed it was not touched",
};

class Reader {
	constructor(bytes) {
		this.bytes = bytes;
		this.at = 0;
	}
	u8() {
		if (this.at + 1 > this.bytes.length) throw new Error("short");
		return this.bytes[this.at++];
	}
	u32() {
		if (this.at + 4 > this.bytes.length) throw new Error("short");
		const value = this.bytes.readUInt32BE(this.at);
		this.at += 4;
		return value;
	}
	string() {
		const length = this.u32();
		if (this.at + length > this.bytes.length) throw new Error("short");
		const value = this.bytes.subarray(this.at, this.at + length);
		this.at += length;
		return value;
	}
	raw(length) {
		if (this.at + length > this.bytes.length) throw new Error("short");
		const value = this.bytes.subarray(this.at, this.at + length);
		this.at += length;
		return value;
	}
	done() {
		return this.at === this.bytes.length;
	}
}

function sshString(value) {
	const bytes = Buffer.isBuffer(value) ? value : Buffer.from(value);
	const length = Buffer.alloc(4);
	length.writeUInt32BE(bytes.length);
	return Buffer.concat([length, bytes]);
}

const sha256 = (bytes) => createHash("sha256").update(bytes).digest();

/** The keys of an OpenSSH allowed_signers file: principal, key type, key blob, and the namespaces it may sign for. */
export function parseAllowedSigners(text) {
	const signers = [];
	for (const rawLine of String(text).split("\n")) {
		const line = rawLine.trim();
		if (line === "" || line.startsWith("#")) continue;
		const tokens = line.match(/(?:[^\s"]+|"[^"]*")+/g) ?? [];
		if (tokens.length < 3) continue;
		const principal = tokens[0].split(",")[0];
		let index = 1;
		let namespaces;
		let certAuthority = false;
		if (!KEY_TYPES.has(tokens[index]) && !/^(ssh|sk|ecdsa)-/.test(tokens[index])) {
			for (const option of tokens[index].match(/(?:[^,"]+|"[^"]*")+/g) ?? []) {
				const [name, ...rest] = option.split("=");
				const value = rest.join("=").replace(/^"|"$/g, "");
				if (name.toLowerCase() === "namespaces") namespaces = value.split(",").filter(Boolean);
				if (name.toLowerCase() === "cert-authority") certAuthority = true;
			}
			index += 1;
		}
		const keyType = tokens[index];
		const base64 = tokens[index + 1];
		if (certAuthority || !KEY_TYPES.has(keyType) || !base64 || !/^[A-Za-z0-9+/]+={0,2}$/.test(base64)) continue;
		const blob = Buffer.from(base64, "base64");
		try {
			if (new Reader(blob).string().toString() !== keyType) continue;
		} catch {
			continue;
		}
		signers.push({ principal, keyType, blob, namespaces });
	}
	return signers;
}

/** The armored signatures of a signature file, in order. Throws when the file holds anything else. */
export function splitSignatureBundle(text) {
	const value = String(text);
	if (Buffer.byteLength(value) > MAX_BUNDLE_BYTES) throw new Error(REASONS.unreadable);
	const blocks = [];
	let rest = value;
	for (;;) {
		rest = rest.replace(/^\s+/, "");
		if (rest === "") break;
		if (!rest.startsWith(BEGIN)) throw new Error(REASONS.unreadable);
		const end = rest.indexOf(END);
		if (end === -1) throw new Error(REASONS.unreadable);
		blocks.push(rest.slice(0, end + END.length));
		rest = rest.slice(end + END.length);
	}
	if (blocks.length === 0 || blocks.length > MAX_SIGNATURES) throw new Error(REASONS.unreadable);
	return blocks;
}

/** One armored SSHSIG, decoded into its fields. Throws on anything that is not exactly that. */
export function parseSshSignature(armored) {
	const body = armored.slice(BEGIN.length, armored.length - END.length).replace(/\s+/g, "");
	if (!/^[A-Za-z0-9+/]+={0,2}$/.test(body)) throw new Error(REASONS.unreadable);
	const bytes = Buffer.from(body, "base64");
	try {
		const reader = new Reader(bytes);
		if (!reader.raw(MAGIC.length).equals(MAGIC) || reader.u32() !== 1) throw new Error("magic");
		const publicKey = reader.string();
		const namespace = reader.string().toString();
		const reserved = reader.string();
		const hashAlgorithm = reader.string().toString();
		const signature = reader.string();
		if (!reader.done()) throw new Error("trailing");
		return { publicKey, namespace, reserved, hashAlgorithm, signature };
	} catch {
		throw new Error(REASONS.unreadable);
	}
}

function ed25519Key(raw) {
	if (raw.length !== 32) throw new Error("key");
	return createPublicKey({ key: { kty: "OKP", crv: "Ed25519", x: raw.toString("base64url") }, format: "jwk" });
}

function p256Key(point) {
	if (point.length !== 65 || point[0] !== 4) throw new Error("key");
	return createPublicKey({
		key: {
			kty: "EC",
			crv: "P-256",
			x: point.subarray(1, 33).toString("base64url"),
			y: point.subarray(33).toString("base64url"),
		},
		format: "jwk",
	});
}

function fixedWidth(mpint) {
	let value = mpint;
	while (value.length > 0 && value[0] === 0) value = value.subarray(1);
	if (value.length > 32) throw new Error("mpint");
	return Buffer.concat([Buffer.alloc(32 - value.length), value]);
}

/** Whether `signature` (the SSHSIG's inner signature blob) is `key`'s signature of `data`. Throws REASONS.touch. */
function keySigned(keyBlob, signature, data) {
	const key = new Reader(keyBlob);
	const keyType = key.string().toString();
	const sig = new Reader(signature);
	if (sig.string().toString() !== keyType) return false;
	if (keyType === "ssh-ed25519") {
		const publicKey = ed25519Key(key.string());
		const raw = sig.string();
		if (!sig.done() || raw.length !== 64) return false;
		return verify(null, data, publicKey, raw);
	}
	if (keyType === "sk-ssh-ed25519@openssh.com") {
		const publicKey = ed25519Key(key.string());
		const application = key.string();
		const raw = sig.string();
		const flags = sig.u8();
		const counter = sig.raw(4);
		if (!sig.done() || raw.length !== 64) return false;
		const signed = Buffer.concat([sha256(application), Buffer.from([flags]), counter, sha256(data)]);
		if (!verify(null, signed, publicKey, raw)) return false;
		if ((flags & USER_PRESENT) === 0) throw new Error(REASONS.touch);
		return true;
	}
	if (keyType === "sk-ecdsa-sha2-nistp256@openssh.com") {
		if (key.string().toString() !== "nistp256") return false;
		const publicKey = p256Key(key.string());
		const application = key.string();
		const inner = new Reader(sig.string());
		const r = fixedWidth(inner.string());
		const s = fixedWidth(inner.string());
		const flags = sig.u8();
		const counter = sig.raw(4);
		if (!inner.done() || !sig.done()) return false;
		const signed = Buffer.concat([sha256(application), Buffer.from([flags]), counter, sha256(data)]);
		if (!verify("sha256", signed, { key: publicKey, dsaEncoding: "ieee-p1363" }, Buffer.concat([r, s]))) {
			return false;
		}
		if ((flags & USER_PRESENT) === 0) throw new Error(REASONS.touch);
		return true;
	}
	return false;
}

/**
 * One armored signature of `message`: { ok: true, principal } when a pinned key made it for `namespace`, otherwise
 * { ok: false, reason } with one of REASONS.
 */
export function verifySshSignature(message, armored, signers, namespace) {
	let parsed;
	try {
		parsed = parseSshSignature(armored);
	} catch {
		return { ok: false, reason: REASONS.unreadable };
	}
	const signer = signers.find((candidate) => candidate.blob.equals(parsed.publicKey));
	if (!signer) return { ok: false, reason: REASONS.unknownKey };
	if (parsed.namespace !== namespace || (signer.namespaces && !signer.namespaces.includes(namespace))) {
		return { ok: false, reason: REASONS.namespace };
	}
	if (parsed.hashAlgorithm !== "sha256" && parsed.hashAlgorithm !== "sha512") {
		return { ok: false, reason: REASONS.unreadable };
	}
	const digest = createHash(parsed.hashAlgorithm).update(message).digest();
	const signedData = Buffer.concat([
		MAGIC,
		sshString(parsed.namespace),
		sshString(parsed.reserved),
		sshString(parsed.hashAlgorithm),
		sshString(digest),
	]);
	try {
		return keySigned(signer.blob, parsed.signature, signedData)
			? { ok: true, principal: signer.principal }
			: { ok: false, reason: REASONS.mismatch };
	} catch (error) {
		return { ok: false, reason: error instanceof Error && error.message === REASONS.touch ? REASONS.touch : REASONS.mismatch };
	}
}

/**
 * Every signature in a signature file, counted by person: { verified: true, principals } when at least `required`
 * different principals signed `message`, otherwise { verified: false, principals, reason }. A signature that does not
 * verify is set aside; it counts against the release only when the rest are too few.
 */
export function verifyReleaseSignatures({ message, bundle, allowedSigners, namespace, required }) {
	const signers = typeof allowedSigners === "string" ? parseAllowedSigners(allowedSigners) : allowedSigners;
	let blocks;
	try {
		blocks = splitSignatureBundle(bundle);
	} catch {
		return { verified: false, principals: [], reason: REASONS.unreadable };
	}
	const principals = [];
	const reasons = [];
	for (const block of blocks) {
		const result = verifySshSignature(message, block, signers, namespace);
		if (result.ok) {
			if (!principals.includes(result.principal)) principals.push(result.principal);
		} else reasons.push(result.reason);
	}
	if (principals.length >= required) return { verified: true, principals };
	const order = [REASONS.mismatch, REASONS.touch, REASONS.namespace, REASONS.unknownKey, REASONS.unreadable];
	const worst = order.find((reason) => reasons.includes(reason));
	const reason =
		worst ??
		`it is signed by ${principals.length} of the ${required} people who must sign (${principals.join(", ") || "nobody"})`;
	return { verified: false, principals, reason };
}

function isMain() {
	try {
		return realpathSync(process.argv[1] ?? "") === realpathSync(fileURLToPath(import.meta.url));
	} catch {
		return false;
	}
}

if (isMain()) {
	const [file, signatureFile, signersFile, namespace, required] = process.argv.slice(2);
	if (!file || !signatureFile || !signersFile || !namespace || !/^[1-9][0-9]*$/.test(required ?? "")) {
		console.log("failed usage: <file> <signature file> <allowed signers file> <namespace> <required>");
		process.exit(2);
	}
	let result;
	try {
		result = verifyReleaseSignatures({
			message: readFileSync(file),
			bundle: readFileSync(signatureFile, "utf8"),
			allowedSigners: readFileSync(signersFile, "utf8"),
			namespace,
			required: Number(required),
		});
	} catch {
		result = { verified: false, reason: REASONS.unreadable };
	}
	console.log(result.verified ? `verified ${result.principals.join(",")}` : `failed ${result.reason}`);
	process.exit(result.verified ? 0 : 1);
}
RELAY_SIGNATURE_VERIFIER
}
# END RELAY SIGNATURE VERIFIER

confirm_install() {
	version="$1"
	tarball_url="$2"
	if relay_quiet; then
		return 0
	fi

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
	# Not asked: Relay prepares its Python runtime the first time a task needs it.
	if relay_quiet; then
		relay_bootstrap_kernel_on_install=0
		return
	fi

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
	relay_finish_hint="open a new terminal, then run: $relay_cmd"
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
	relay_finish_hint="run: $relay_installed_at"
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
	relay_install_label="Installed the app"
	if [ -n "$relay_user_npm_prefix" ]; then
		relay_install_label="Installed the app in $(relay_display_path "$relay_user_npm_prefix") (npm's own folder needs sudo)"
	fi
	if [ "$relay_bootstrap_kernel_on_install" = 1 ]; then
		relay_step_start "Installing the app and its Python runtime"
		relay_profiles_before=$(relay_profile_snapshot)
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
		relay_step_done "$relay_install_label, with its Python runtime"
		relay_note_uv_profile_edits "$relay_profiles_before" "$(relay_profile_snapshot)"
	else
		relay_step_start "Installing the app"
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
		relay_step_done "$relay_install_label"
	fi
}

# The shell profiles uv's own installer may edit (it adds a line that puts ~/.local/bin on PATH), so the installer can
# say which ones it changed. One line each: "<cksum>\t<path>", or "-\t<path>" when the file is not there.
relay_profile_snapshot() {
	[ -n "${HOME:-}" ] || return 0
	for relay_profile_name in .profile .bashrc .bash_profile .bash_login .zshrc .zshenv .config/fish/conf.d/uv.env.fish; do
		relay_profile_snapshot_one "$HOME/$relay_profile_name"
	done
	if [ -n "${ZDOTDIR:-}" ] && [ "$ZDOTDIR" != "$HOME" ]; then
		relay_profile_snapshot_one "$ZDOTDIR/.zshrc"
		relay_profile_snapshot_one "$ZDOTDIR/.zshenv"
	fi
}

relay_profile_snapshot_one() {
	if [ -f "$1" ]; then
		printf '%s\t%s\n' "$(cksum <"$1" | tr -d ' \t')" "$1"
	else
		printf -- '-\t%s\n' "$1"
	fi
}

#   $1 the snapshot before the Python step, $2 the one after
relay_note_uv_profile_edits() {
	relay_uv_changed=
	relay_uv_count=0
	relay_uv_saved_ifs=$IFS
	IFS='
'
	for relay_uv_line in $2; do
		case "
$1
" in
			*"
$relay_uv_line
"*) continue ;;
		esac
		relay_uv_file=$(relay_display_path "${relay_uv_line#*	}")
		relay_uv_count=$((relay_uv_count + 1))
		if [ -z "$relay_uv_changed" ]; then
			relay_uv_changed="$relay_uv_file"
		else
			relay_uv_changed="$relay_uv_changed, $relay_uv_file"
		fi
	done
	IFS=$relay_uv_saved_ifs
	[ "$relay_uv_count" -gt 0 ] || return 0
	if [ "$relay_uv_count" -gt 1 ]; then
		relay_uv_changed="${relay_uv_changed%, *} and ${relay_uv_changed##*, }"
	fi
	relay_uv_profile_note="uv, the Python tool Relay set up, added a line to $relay_uv_changed so new terminals find it. \"$relay_cmd uninstall\" takes it out again."
	if relay_quiet; then
		printf '%s\n' "$relay_uv_profile_note"
		relay_uv_profile_note=
	fi
}

#   $1 the tarball, then the environment assignments for npm's install scripts
run_relay_npm_install() {
	npm_tarball_path="$1"
	shift
	if [ -n "$relay_user_npm_prefix" ]; then
		env "$@" npm install -g --prefix "$relay_user_npm_prefix" --no-fund --no-audit --loglevel=error --progress=false --update-notifier=false "$npm_tarball_path"
	else
		env "$@" npm install -g --no-fund --no-audit --loglevel=error --progress=false --update-notifier=false "$npm_tarball_path"
	fi
}

main "$@"
