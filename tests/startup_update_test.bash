#!/usr/bin/env bash
# Local remotes exercise consent and failure handling without network access.
if [ -n "${ZSH_VERSION:-}" ]; then emulate -LR zsh -o KSH_ARRAYS; fi
set -eo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "$0")/.." && pwd)"
TEST_ROOT=$(mktemp -d)
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.invalid
fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }
. "$ROOT_DIR/scripts/unix/update/context.bash"
YAFP_UPDATE_CHECK=1
cleanup() { yafp_update_cleanup; rm -rf -- "$TEST_ROOT"; }
trap cleanup EXIT
reloads=0
yafp-reload() {
    reloads=$((reloads + 1))
    this_command='' previous_command='' previous_timestamp=''
}
start_check() {
    yafp_update_start
    local iteration
    for iteration in {1..300}; do
        [ ! -r "$YAFP_UPDATE_DIR/sample" ] || return 0
        sleep 0.05
    done
    fail 'Startup worker did not finish'
}
git init --quiet --bare "$TEST_ROOT/remote.git"
git clone --quiet "$TEST_ROOT/remote.git" "$TEST_ROOT/seed" 2>/dev/null
mkdir -p "$TEST_ROOT/seed/scripts/unix/update"
cp "$ROOT_DIR/scripts/unix/update/collect.bash" "$TEST_ROOT/seed/scripts/unix/update/"
printf 'one\n' > "$TEST_ROOT/seed/file.txt"
git -C "$TEST_ROOT/seed" add .
git -C "$TEST_ROOT/seed" commit --quiet -m initial
git -C "$TEST_ROOT/seed" push --quiet origin HEAD
git clone --quiet "$TEST_ROOT/remote.git" "$TEST_ROOT/YAFP install"
YAFP_ROOT="$TEST_ROOT/YAFP install"
initial=$(git -C "$YAFP_ROOT" rev-parse HEAD)
initial_branch=$(git -C "$YAFP_ROOT" symbolic-ref --short HEAD)
printf 'two\n' >> "$TEST_ROOT/seed/file.txt"
git -C "$TEST_ROOT/seed" commit --quiet -am second
git -C "$TEST_ROOT/seed" push --quiet origin HEAD

# The check targets the installation, independently of the current directory.
cd "$TEST_ROOT"
start_check
empty_path=$YAFP_UPDATE_DIR
yafp_update_notice > "$TEST_ROOT/output" <<< ''
[ ! -d "$empty_path" ] || fail 'Startup cache was not removed'
[ "$(git -C "$YAFP_ROOT" rev-parse HEAD)" = "$initial" ] || fail 'Default answer pulled'
[ "$reloads" = 0 ] || fail 'Default answer reloaded'
grep -q '☒ OUTDATED REPOSITORY: YAFP is 1 commit(s)' "$TEST_ROOT/output" || fail 'Missing behind count'
grep -q 'YAFP startup check:' "$TEST_ROOT/output" || fail 'Missing installation label for a problem'
grep -q 'Update YAFP now? \[y/N\]' "$TEST_ROOT/output" || fail 'Missing English consent prompt'
start_check
yafp_update_notice < /dev/null > "$TEST_ROOT/output"
[ "$reloads" = 0 ] || fail 'EOF was accepted'
start_check
this_command=false previous_command=previous previous_timestamp=timestamp
yafp_update_notice > "$TEST_ROOT/output" <<< y
[ "$reloads" = 1 ] || fail 'Accepted update did not reload exactly once'
[ "$(git -C "$YAFP_ROOT" rev-parse HEAD)" = "$(git -C "$TEST_ROOT/seed" rev-parse HEAD)" ] || fail 'Wrong repository updated'
[ -z "$YAFP_UPDATE_DIR" ] || fail 'Reload launched a recursive check'
[ "$this_command/$previous_command/$previous_timestamp" = 'false/previous/timestamp' ] || fail 'Reload lost previous-command context'
printf 'ok - startup update checks installation, waits for completion, defaults to N, and reloads after consent\n'

start_check
yafp_update_notice > "$TEST_ROOT/output" <<< y
[ ! -s "$TEST_ROOT/output" ] || fail 'Current checkout must be silent'
git -C "$YAFP_ROOT" remote set-url origin "$TEST_ROOT/missing.git"
start_check
yafp_update_notice > "$TEST_ROOT/output" <<< y
grep -qx '☒🌐 REMOTE CHECK FAILED' "$TEST_ROOT/output" || fail 'Remote failure message'
[ "$reloads" = 1 ] || fail 'Remote failure reloaded'
git -C "$YAFP_ROOT" remote set-url origin "$TEST_ROOT/remote.git"

printf 'local\n' > "$YAFP_ROOT/local.txt"
git -C "$YAFP_ROOT" add local.txt
git -C "$YAFP_ROOT" commit --quiet -m local
start_check
yafp_update_notice > "$TEST_ROOT/output" <<< y
grep -q '⚠ REMOTE NOT UPDATED: 1 local commit has not been pushed to origin/' "$TEST_ROOT/output" || fail 'Missing ahead warning'
grep -q '^⚠ REMOTE NOT UPDATED:.*[^)]$' "$TEST_ROOT/output" || fail 'Startup warning must not have enclosing parentheses'
[ "$reloads" = 1 ] || fail 'Ahead checkout reloaded'
printf 'dirty\n' > "$YAFP_ROOT/dirty.tmp"
start_check
yafp_update_notice > "$TEST_ROOT/output" <<< y
grep -q '^⚠ REMOTE NOT UPDATED: 1 local commit has not been pushed to origin/' "$TEST_ROOT/output" || fail 'Local changes obscured remote status'
if grep -q 'UNCOMMITTED CHANGES' "$TEST_ROOT/output"; then fail 'Startup must report remote state independently of local changes'; fi
rm -f "$YAFP_ROOT/dirty.tmp"
printf 'three\n' >> "$TEST_ROOT/seed/file.txt"
git -C "$TEST_ROOT/seed" commit --quiet -am third
git -C "$TEST_ROOT/seed" push --quiet origin HEAD
local_head=$(git -C "$YAFP_ROOT" rev-parse HEAD)
start_check
yafp_update_notice > "$TEST_ROOT/output" 2>&1 <<< y
grep -q '☒ DIVERGED REPOSITORY' "$TEST_ROOT/output" || fail 'Diverged update must fail safely'
[ "$(git -C "$YAFP_ROOT" rev-parse HEAD)" = "$local_head" ] || fail 'Divergence changed HEAD'
[ "$reloads" = 1 ] || fail 'Failed pull reloaded'

start_check
git -C "$YAFP_ROOT" checkout --quiet --detach
yafp_update_notice > "$TEST_ROOT/output" <<< y
[ ! -s "$TEST_ROOT/output" ] || fail 'Stale branch result was offered'
start_check
yafp_update_notice > "$TEST_ROOT/output" <<< y
grep -q 'DETACHED HEAD' "$TEST_ROOT/output" || fail 'Missing detached status'
git -C "$YAFP_ROOT" checkout --quiet "$initial_branch"
git -C "$YAFP_ROOT" branch --unset-upstream
start_check
yafp_update_notice > "$TEST_ROOT/output" <<< y
grep -q 'NO UPSTREAM' "$TEST_ROOT/output" || fail 'Missing upstream status'
git -C "$YAFP_ROOT" worktree add --quiet -b startup-worktree "$TEST_ROOT/worktree" "origin/$initial_branch"
YAFP_ROOT="$TEST_ROOT/worktree"
start_check
grep -q '^ok 0 ' "$YAFP_UPDATE_DIR/sample" || fail 'Tracking worktree was not checked'
yafp_update_notice > "$TEST_ROOT/output" <<< y
[ ! -s "$TEST_ROOT/output" ] || fail 'Current worktree must be silent'
# A hung transport must produce an error and terminate its child process group.
real_git=$(command -v git)
mkdir "$TEST_ROOT/bin"
cat > "$TEST_ROOT/bin/git" <<'EOF'
#!/usr/bin/env bash
for argument in "$@"; do
    if [ "$argument" = fetch ]; then
        sleep 30 &
        printf '%s\n' "$!" > "$YAFP_TEST_UPDATE_CHILD"
        wait
        exit 0
    fi
done
exec "$YAFP_TEST_UPDATE_GIT" "$@"
EOF
chmod +x "$TEST_ROOT/bin/git"
timeout_started=$SECONDS
YAFP_TEST_UPDATE_GIT="$real_git" YAFP_TEST_UPDATE_CHILD="$TEST_ROOT/child" \
    PATH="$TEST_ROOT/bin:$PATH" bash "$ROOT_DIR/scripts/unix/update/collect.bash" \
    "$YAFP_ROOT" "$TEST_ROOT/timeout-sample" 1 > /dev/null 2>&1
[ "$((SECONDS - timeout_started))" -lt 5 ] || fail 'Transport exceeded its timeout'
grep -q '^error ' "$TEST_ROOT/timeout-sample" || fail 'Hung transport did not time out'
IFS= read -r transport_pid < "$TEST_ROOT/child"
sleep 0.1
if kill -0 "$transport_pid" 2>/dev/null; then fail 'Timed-out transport survived'; fi
yafp_update_on_load > "$TEST_ROOT/output"
[ ! -s "$TEST_ROOT/output" ] || fail 'Healthy first load must be silent'
[ "$YAFP_UPDATE_SESSION_PID" = "$$" ] || fail 'First load did not check'
YAFP_ROOT="$TEST_ROOT/missing-installation"
yafp_update_on_load > "$TEST_ROOT/output"
[ ! -s "$TEST_ROOT/output" ] || fail 'Repeated entry checked twice'
YAFP_UPDATE_CHECK=0
yafp_update_start
[ -z "$YAFP_UPDATE_DIR" ] || fail 'Disabled check started a worker'
printf 'ok - startup update handles failures, divergence, stale results, detached/untracked branches, worktrees, and disabling\n'
