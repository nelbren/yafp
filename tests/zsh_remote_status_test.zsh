#!/usr/bin/env zsh
emulate -LR zsh
setopt KSH_ARRAYS
ROOT_DIR="${0:A:h:h}"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
export YAFP_NO_INSTALL_HOOKS=1
export YAFP_CONFIG_FILE="$ROOT_DIR/yafp-cfg.zsh.example"
export TERM=xterm-256color
. "$ROOT_DIR/yafp-ps1.zsh" || exit 1
fail() { print -u2 -r -- "not ok - $1"; exit 1; }
assert_eq() { [[ "$1" == "$2" ]] || fail "$3: expected [$1], got [$2]"; }
setup_identity() {
    git -C "$1" config user.name 'YAFP Test'
    git -C "$1" config user.email 'yafp@example.invalid'
    git -C "$1" config commit.gpgsign false
    git -C "$1" config core.hooksPath /dev/null
    git -C "$1" config maintenance.auto false
}
wait_refresh() {
    local i
    for ((i=0; i<200; i++)); do
        [[ ! -d "$cache.lock" && -s "$cache" ]] && return 0
        sleep 0.025
    done
    fail 'background worker did not finish'
}
read_context() { yafp_remote_context "$TEST_ROOT/local" main 0; }
refresh_context() { yafp_remote_context "$TEST_ROOT/local" main 1; wait_refresh; read_context; }

# All remotes are local fixtures; no credentials or network are involved.
git init --quiet --bare --initial-branch=main "$TEST_ROOT/origin.git" || exit 1
git init --quiet --initial-branch=main "$TEST_ROOT/writer" || exit 1
setup_identity "$TEST_ROOT/writer"
print initial > "$TEST_ROOT/writer/file.txt"
git -C "$TEST_ROOT/writer" add file.txt
git -C "$TEST_ROOT/writer" commit --quiet -m initial
git -C "$TEST_ROOT/writer" remote add origin "$TEST_ROOT/origin.git"
git -C "$TEST_ROOT/writer" push --quiet --set-upstream origin main
git clone --quiet "$TEST_ROOT/origin.git" "$TEST_ROOT/local"
setup_identity "$TEST_ROOT/local"
cache="$TEST_ROOT/local/.git/yafp-remote-status"
YAFP_REMOTE_CHECK_INTERVAL=300
refresh_context
assert_eq current "$yafp_ctx_git_remote_state" 'current remote'
assert_eq 1 "$yafp_ctx_git_remote_connection_announcement" 'first fresh check announcement'
read_context
assert_eq 0 "$yafp_ctx_git_remote_connection_announcement" 'announcement once'

print remote >> "$TEST_ROOT/writer/file.txt"
git -C "$TEST_ROOT/writer" commit --quiet -am remote
git -C "$TEST_ROOT/writer" push --quiet origin main
refresh_context
assert_eq behind "$yafp_ctx_git_remote_state" 'behind remote'
assert_eq 1 "$yafp_ctx_git_behind" 'behind count'
git -C "$TEST_ROOT/local" pull --quiet --ff-only
print local >> "$TEST_ROOT/local/file.txt"
git -C "$TEST_ROOT/local" commit --quiet -am local
refresh_context
assert_eq ahead "$yafp_ctx_git_remote_state" 'ahead remote'
assert_eq 1 "$yafp_ctx_git_ahead" 'ahead count'

# A push changes tracking refs and must invalidate a cached Ahead immediately.
git -C "$TEST_ROOT/local" push --quiet origin main
read_context
[[ "$yafp_ctx_git_remote_state" != ahead ]] || fail 'push left a stale Ahead cache'
wait_refresh
read_context
assert_eq current "$yafp_ctx_git_remote_state" 'current after push'
git -C "$TEST_ROOT/writer" pull --quiet --ff-only
print local2 >> "$TEST_ROOT/local/file.txt"
git -C "$TEST_ROOT/local" commit --quiet -am local2
print remote2 >> "$TEST_ROOT/writer/file.txt"
git -C "$TEST_ROOT/writer" commit --quiet -am remote2
git -C "$TEST_ROOT/writer" push --quiet origin main
refresh_context
assert_eq diverged "$yafp_ctx_git_remote_state" 'diverged remote'
assert_eq 1 "$yafp_ctx_git_ahead" 'diverged ahead count'
assert_eq 1 "$yafp_ctx_git_behind" 'diverged behind count'

# A delayed worker must not hold up a prompt or create duplicate jobs.
functions -c yafp_remote_check_worker yafp_test_real_worker
yafp_remote_check_worker() { sleep 0.5; yafp_test_real_worker "$@"; }
local_start=$EPOCHREALTIME
read_context
# Explicit refresh starts the delayed worker even with a fresh cache.
yafp_remote_context "$TEST_ROOT/local" main 1
(( EPOCHREALTIME - local_start < 0.4 )) || fail 'foreground remote operation'
assert_eq 1 "$yafp_ctx_git_remote_refreshing" 'refresh state while running'
worker_pid="$(cat "$cache.lock/pid")"
yafp_remote_context "$TEST_ROOT/local" main 1
assert_eq "$worker_pid" "$(cat "$cache.lock/pid")" 'lock prevents duplicate worker'
wait_refresh
functions -c yafp_test_real_worker yafp_remote_check_worker

mkdir "$cache.lock"
print 99999999 > "$cache.lock/pid"
yafp_remote_context "$TEST_ROOT/local" main 1
wait_refresh
[[ ! -d "$cache.lock" ]] || fail 'abandoned lock cleanup'

git -C "$TEST_ROOT/local" remote set-url origin "$TEST_ROOT/missing.git"
refresh_context
assert_eq error "$yafp_ctx_git_remote_state" 'failed fetch'
cd "$TEST_ROOT/local" || exit 1
yafp-ack >/dev/null
assert_eq 1 "$YAFP_REMOTE_OFFLINE_ACKNOWLEDGED" 'acknowledgement'
git remote set-url origin "$TEST_ROOT/origin.git"
refresh_context
assert_eq 0 "$YAFP_REMOTE_OFFLINE_ACKNOWLEDGED" 'recovery clears acknowledgement'
assert_eq 1 "$yafp_ctx_git_remote_connection_announcement" 'offline recovery announcement'

COLUMNS=200
# Detect git init in the same directory after caching a non-repository.
mkdir "$TEST_ROOT/initialized"
cd "$TEST_ROOT/initialized"
YAFP_REPOS=1
YAFP_GIT_LAST_PWD=''
yafp_git_context 0
assert_eq 0 "$yafp_ctx_git_has_repo" 'before git init'
git init --quiet --initial-branch=main
yafp_git_context 0
assert_eq 1 "$yafp_ctx_git_has_repo" 'git init detected without changing directory'
assert_eq no-commits "$yafp_ctx_git_remote_state" 'initial commit warning'
assert_eq '' "$yafp_ctx_git_remote_refresh_in" 'initial commit has no countdown'
[ ! -e .git/yafp-remote-status.lock ] || fail 'initial commit started a worker'
for theme in default minimal light; do
    YAFP_THEME="$theme"
    load_theme
    indicator="$(theme_render_git_remote_status)"
    case "$indicator" in
        *'○0'*'⚠ NO COMMITS'*|*'⚠ NO COMMITS'*'○0'*) ;;
        *) fail "$theme missing initial commit warning" ;;
    esac
done
printf initial > file.txt
git add file.txt
yafp_git_context 0
assert_eq 1 "$yafp_ctx_git_staged" 'initial staged file remains visible'
assert_eq no-commits "$yafp_ctx_git_remote_state" 'staging retains initial warning'
git -c user.name=Test -c user.email=test@example.invalid \
    -c commit.gpgsign=false -c core.hooksPath=/dev/null commit --quiet -m initial
yafp_git_context 0
assert_eq '' "$yafp_ctx_git_remote_state" 'first commit clears initial warning'
cd "$TEST_ROOT/local"

# Upstream, detached HEAD, worktree, and missing Git all degrade silently.
git branch --unset-upstream
read_context
assert_eq no-upstream "$yafp_ctx_git_remote_state" 'no upstream'
assert_eq '' "$yafp_ctx_git_remote_refresh_in" 'no tracking countdown'
[[ ! -d "$cache.lock" ]] || fail 'no upstream started a worker'
COLUMNS=200
for theme in default minimal light; do
    YAFP_THEME="$theme"
    load_theme
    indicator="$(theme_render_git_remote_status)"
    [[ "$indicator" == *'⇡?'* && "$indicator" == *'⚠ NO UPSTREAM'* ]] ||
        fail "$theme tracking warning"
done
git remote remove origin
read_context
assert_eq '' "$yafp_ctx_git_remote_state" 'local-only repo'
git remote add publish "$TEST_ROOT/origin.git"
read_context
assert_eq no-upstream "$yafp_ctx_git_remote_state" 'remote without tracking refs'
git remote remove publish
git remote add origin "$TEST_ROOT/origin.git"
git fetch --quiet origin
git branch --set-upstream-to=origin/main main >/dev/null
git worktree add --quiet --detach "$TEST_ROOT/worktree" HEAD
cd "$TEST_ROOT/worktree" || exit 1
YAFP_REPOS=1
yafp_git_context 0
assert_eq 1 "$yafp_ctx_git_has_repo" 'worktree detected'
assert_eq unnamed "$yafp_ctx_git_branch" 'detached branch fallback'
assert_eq '' "$yafp_ctx_git_remote_state" 'detached has no remote checks'
cd "$TEST_ROOT/local" || exit 1
YAFP_INITIAL_REMOTE_CHECK_PENDING=1
YAFP_REMOTE_CHECK_INTERVAL=0
yafp_git_context 0
assert_eq '' "$yafp_ctx_git_remote_state" 'remote disabled'
[[ ! -d "$cache.lock" ]] || fail 'disabled checks create worker'
(
    PATH="$TEST_ROOT/empty"
    YAFP_GIT_LAST_PWD=''
    yafp_git_context 0
    # .git fast path sees the directory, but all optional Git calls stay quiet.
    [[ "$yafp_ctx_git_remote_state" == '' ]] || exit 1
) || fail 'missing optional Git'
print -r -- 'ok - zsh asynchronous Git, cache, locking, recovery, and worktrees'
