#!/bin/bash
# build.sh - Build script for WindowsBootCreator
# Usage: ./build.sh [release|debug|clean|run|test]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="WindowsBootCreator"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# ============================================================================
# Build Functions
# ============================================================================

build_debug() {
    log_info "Building $APP_NAME (debug)..."
    cd "$SCRIPT_DIR"
    swift build
    log_success "Debug build complete: .build/debug/$APP_NAME"
}

build_release() {
    log_info "Building $APP_NAME (release)..."
    cd "$SCRIPT_DIR"
    swift build -c release
    log_success "Release build complete: .build/release/$APP_NAME"
}

clean_build() {
    log_info "Cleaning build artifacts..."
    cd "$SCRIPT_DIR"
    swift package clean
    rm -rf .build
    log_success "Build artifacts cleaned"
}

run_app() {
    local config="${1:-debug}"
    local binary_path=".build/$config/$APP_NAME"

    if [[ ! -f "$binary_path" ]]; then
        log_warning "Binary not found, building first..."
        if [[ "$config" == "release" ]]; then
            build_release
        else
            build_debug
        fi
    fi

    log_info "Launching $APP_NAME..."
    "$binary_path"
}

run_tests() {
    log_info "Running sandbox tests..."
    cd "$SCRIPT_DIR/sandbox"
    ./run-all-tests.sh "$@"
}

show_help() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  debug     Build debug configuration (default)"
    echo "  release   Build release configuration"
    echo "  clean     Remove build artifacts"
    echo "  run       Build and run the app (debug)"
    echo "  run-release  Build and run the app (release)"
    echo "  test      Run sandbox tests"
    echo "  help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Build debug"
    echo "  $0 release      # Build release"
    echo "  $0 run          # Build and run"
    echo "  $0 test         # Run tests"
    echo ""
}

# ============================================================================
# Main
# ============================================================================

case "${1:-debug}" in
    debug|build)
        build_debug
        ;;
    release)
        build_release
        ;;
    clean)
        clean_build
        ;;
    run)
        run_app debug
        ;;
    run-release)
        run_app release
        ;;
    test)
        shift
        run_tests "$@"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
