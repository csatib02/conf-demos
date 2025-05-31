[private]
default:
    @just --list

verify: editor-config

[private]
editor-config: install-editor-config-checker
    @echo "Running EditorConfig checker..."
    @if ./bin/editorconfig-checker --exclude LICENSE; then \
        echo "✅ EditorConfig check passed!"; \
    fi

[private]
bin-dir:
    @if [ ! -d "./bin" ]; then \
        echo "Creating bin directory..."; \
        mkdir -p ./bin; \
    fi

[private]
install-editor-config-checker: bin-dir
    @if [ ! -f ./bin/editorconfig-checker ]; then \
        echo "Installing EditorConfig checker... "; \
        GOBIN=$(pwd)/bin go install github.com/editorconfig-checker/editorconfig-checker/v3/cmd/editorconfig-checker@latest; \
    else \
        echo "✅ EditorConfig checker already installed!"; \
    fi
