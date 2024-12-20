# Justfile (Convenience Command Runner)

# rust vars
RUST_LOG:= 'debug'
RUST_BACKTRACE:= '1'
RUSTFLAGS:='--cfg tokio_unstable'
TOML_VERSION:=`rg '^version = ".*"' Cargo.toml | sd '.*"(.*)".*' '$1'`
# just path vars
HOME_DIR := env_var('HOME')
LOCAL_ROOT := justfile_directory()
INVOCD_FROM := invocation_directory()
INVOC_IS_ROOT := if INVOCD_FROM == LOCAL_ROOT { "true" } else { "false" }
# custom vars
FROZE_SHA_REGEX := 'FROZE_[a-fA-F0-9]{64}_FROZE-'
# ANSI Color Codes for use with echo command
NC := '\033[0m'     # No Color
CYN := '\033[0;36m' # Cyan
BLU := '\033[0;34m' # Blue
GRN := '\033[0;32m' # Green
PRP := '\033[0;35m' # Purple
RED := '\033[0;31m' # Red
YLW := '\033[0;33m' # Yellow
BRN := '\033[0;33m' # Brown

# Default, lists commands.
_default:
        @just --list --unsorted

# Initialize repository.
[confirm]
init: && list-external-deps _gen-env _gen-git-hooks _external-wasm-installs
    cargo clean
    cargo build
    cargo doc

# Linting, formatting, typo checking, etc.
check:
    cargo clippy
    cargo fmt
    typos
    committed

# Show docs.
docs:
    rustup doc
    rustup doc --std
    cargo doc --all-features --document-private-items --open

# Update Rust-crates, non-breaking updates only.
update-soft:
    cargo update --verbose

# Update Rust-crates, first minor, then breaking changes.
[confirm]
update-hard: update-soft
    cargo update --verbose --breaking -Z unstable-options

# Run Trunk server and open webpage to access it
web-local:
    @echo 'A webpage will open; paste (auto-copied) site in once trunk server is running.'
    @echo '{{GRN}}-------{{NC}} go to: {{BLU}}http://localhost:8080/index.html#dev{{NC}} {{GRN}}-------{{NC}}'
    echo 'http://localhost:8080/index.html#dev' | pbcopy
    (sleep 2; open http://localhost:8080/index.html#dev )&
    @echo '{{PRP}}Address {{RED}}copied{{PRP}} to clipboard for pasting.{{NC}}'
    @echo 'NOTE: clicking link may not work.  Hashtag is not properly transmitted.'
    trunk serve

# Add a package to workspace // adds and removes a bin to update workspace package register
packadd name:
    cargo new --bin {{name}}
    rm -rf {{name}}
    cargo generate --path ./.support_data/cargo_generate_templates/template__new_package --name {{name}}


# All tests, little feedback unless issues are detected.
test:
    cargo test --doc
    cargo nextest run --cargo-quiet --cargo-quiet --no-fail-fast

# Runtests for a specific package.
testp package="":
    cargo test --doc --quiet --package {{package}}
    cargo nextest run --cargo-quiet --cargo-quiet --package {{package}} --no-fail-fast

# Run a specific test with output visible. (Use '' for test_name to see all tests and set log_level)
test-view test_name="" log_level="error":
    @echo "'Fun' Fact; the '--test' flag only allows integration test selection and will just fail on unit tests."
    RUST_LOG={{log_level}} cargo test {{test_name}} -- --nocapture

# Run a specific test with NEXTEST with output visible. (Use '' for test_name to see all tests and set log_level)
testnx-view test_name="" log_level="error":
    @echo "'Fun' Fact; the '--test' flag only allows integration test selection and will just fail on unit tests."
    RUST_LOG={{log_level}} cargo nextest run {{test_name}} --no-capture --no-fail-fast

# All tests, little feedback unless issues are detected.
test-whisper:
    cargo test --doc --quiet
    cargo nextest run --cargo-quiet --cargo-quiet --status-level=leak

# Run performance analysis on a package.
perf package *args:
    cargo build --profile profiling --bin {{package}};
    hyperfine --export-markdown=.output/profiling/{{package}}_hyperfine_profile.md './target/profiling/{{package}} {{args}}' --warmup=3 --shell=none;
    samply record --output=.output/profiling/{{package}}_samply_profile.json --iteration-count=3 ./target/profiling/{{package}} {{args}};

# Possible future perf compare command.
perf-compare-info:
    @echo "Use hyperfine directly:\n{{GRN}}hyperfine{{NC}} {{BRN}}'cmd args'{{NC}} {{BRN}}'cmd2 args'{{NC}} {{PRP}}...{{NC}} --warmup=3 --shell=none"


# List dependencies. (This command has dependencies.)
list-external-deps:
    @echo "{{CYN}}List of external dependencies for this command runner and repo:"
    xsv table ad_deps.csv

# Info about Rust-Compiler, Rust-Analyzer, Cargo-Clippy, and Rust-Updater.
rust-meta-info:
    rustc --version
    rust-analyzer --version
    cargo-clippy --version
    rustup --version
# ######################################################################## #

# Print reminder: how to set env vars that propagate to child shells.
_remind-setenv:
    @ echo '{{GRN}}set -a{{NC}}; {{GRN}}source {{BLU}}.env{{NC}}; {{GRN}}set +a{{NC}}'

# ######################################################################## #

# Ensure wasm32 target prepared for rust and install `trunk`
_external-wasm-installs:
    rustup target add wasm32-unknown-unknown
    cargo install --locked trunk

# Generate .env file from template, if .env file not present.
_gen-env:
    @ if [ -f '.env' ]; then echo '`{{BRN}}.env{{NC}}` exists, {{PRP}}skipping creation{{NC}}...' && exit 0; else cp -n .support_data/template.env .env; echo "{{BLU}}.env{{NC}} created from template. {{GRN}}Please fill in the necessary values.{{NC}}"; echo "e.g. via 'nvim .env'"; fi

# Attempt to add all git-hooks. (no overwrite)
_gen-git-hooks: _gen-precommit-hook _gen-commitmsg-hook

# Attempt to add `pre-commit` git-hook. (no overwrite)
_gen-precommit-hook:
    @ if [ -f '.git/hooks/pre-commit' ]; then echo '`.git/hooks/{{BRN}}pre-commit{{NC}}` exists, {{PRP}}skipping creation{{NC}}...' && exit 0; else cp -n .support_data/git_hooks/pre-commit .git/hooks/pre-commit; chmod u+x .git/hooks/pre-commit; echo live "{{BLU}}pre-commit{{NC}} hook added to {{GRN}}.git/hooks{{NC}} and set as executable"; fi

# Attempt to add `commit-msg` git-hook. (no overwrite)
_gen-commitmsg-hook:
    @ if [ -f '.git/hooks/commit-msg' ]; then echo '`.git/hooks/{{BRN}}commit-msg{{NC}}` exists, {{PRP}}skipping creation{{NC}}...' && exit 0; else cp -n .support_data/git_hooks/commit-msg .git/hooks/commit-msg; chmod u+x .git/hooks/commit-msg; echo live "{{BLU}}commit-msg{{NC}} hook added to {{GRN}}.git/hooks{{NC}} and set as executable"; fi

# ######################################################################## #

# ripgrep for elements in braces -- to see mustache insertions
[no-cd]
_template-rg *INSIDE:
	@ echo "-- NOTE: this is run from calling directory; not justfile directory. --"
	rg --hidden "\{\{.*{{INSIDE}}.*\}\}"

# build deployable release and open some convenience docs
_web-deploy:
    @ echo 'Note: a github workflow should have already deployed this to github pages if permitted.'
    trunk build --release
    @ echo "a static site has been loaded to dist/, you can add this to, for example, github pages"
    sleep 2
    open https://docs.github.com/en/free-pro-team@latest/github/working-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site

# ######################################################################## #

# Freeze! For your safety.
_freeze file:
	mv -iv {{file}} FROZE_{{sha256(file)}}_FROZE-{{file}} | rg {{file}}

# Unfreeze a file. (removes 'FROZE...FROZE-' tag from filename)
_thaw file:
	echo {{file}} | sd '{{FROZE_SHA_REGEX}}' '' | xargs mv -iv {{file}}

# Search local files through ice.
_arctic-recon iceless_name:
	fd --max-depth 1 '{{FROZE_SHA_REGEX}}{{iceless_name}}' | rg {{iceless_name}}


# ######################################################################## #

# Speak Funny to Me!
_uu:
	echo {{uuid()}}

# Say my name.
_sha file:
	echo {{sha256_file(file)}}

# Example function for syntax reference
_example-file-exists-test file:
    echo {{ if path_exists(file) == "true" { "hello" } else { "goodbye" } }}

# ######################################################################## #


# # Clean up cargo build artifacts.
# [confirm]
# teardown:
#     cargo clean

# # Auto-fix some errors picked up by check. (Manual exclusion of data folder as additional safeguard.)
# [confirm]
# fix:
#      typos --exclude '*/data/*' --write-changes

# # Run git hook.
# git-hook hook='pre-commit':
#     git hook run {{hook}}

# # Watch a file: compile & run on changes.
# watch file_to_run:
#     cargo watch --quiet --clear --exec 'run --quiet --example {{file_to_run}}'
