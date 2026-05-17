[private]
default:
    @just --list

# Run all checks (editorconfig + Rust fmt/lint/test)
verify: editor-config fmt-check lint test

# Scaffold a new talk dir at the repo root
new title venue="" steps="0":
    cargo run --quiet --manifest-path tools/scaff/Cargo.toml -- "{{title}}" --venue "{{venue}}" --steps {{steps}}

# Format Rust code
fmt:
    cargo fmt --manifest-path tools/scaff/Cargo.toml

# Run clippy lints
lint:
    @echo "Running clippy..."
    cargo clippy --manifest-path tools/scaff/Cargo.toml --all-targets -- -D warnings

# Run Rust tests
test:
    @echo "Running Rust tests..."
    cargo test --manifest-path tools/scaff/Cargo.toml --all-targets

# Build the release binary
build:
    cargo build --manifest-path tools/scaff/Cargo.toml --release

[private]
fmt-check:
    @echo "Checking Rust formatting..."
    cargo fmt --manifest-path tools/scaff/Cargo.toml --check

[private]
editor-config: install-editor-config-checker
    @echo "Running EditorConfig checker..."
    @if ./bin/editorconfig-checker --exclude LICENSE; then \
        echo "✅ EditorConfig check passed!"; \
    fi

[private]
install-editor-config-checker: bin-dir
    @if [ ! -f ./bin/editorconfig-checker ]; then \
        echo "Installing EditorConfig checker... "; \
        GOBIN=$(pwd)/bin go install github.com/editorconfig-checker/editorconfig-checker/v3/cmd/editorconfig-checker@latest; \
    else \
        echo "✅ EditorConfig checker already installed!"; \
    fi

[private]
bin-dir:
    @if [ ! -d "./bin" ]; then \
        echo "Creating bin directory..."; \
        mkdir -p ./bin; \
    fi
