#!/usr/bin/env bash
# install.sh - Install libshell from GitHub Release
# Usage: curl -fsSL https://raw.githubusercontent.com/GCS-ZHN/libshell/main/install.sh | bash
#    or: ./install.sh [OPTIONS]
#
# Options:
#   -d, --dir DIR      Installation directory (default: ~/.libshell)
#   -v, --version VER  Install specific version (default: latest)
#   -s, --shell SHELL  Configure for shell: bash, zsh, pwsh, all (default: auto-detect)
#   -h, --help         Show this help message

set -e

# Configuration
GITHUB_REPO="GCS-ZHN/libshell"
INSTALL_DIR="${HOME}/.libshell"
VERSION="latest"
SHELL_TYPE="auto"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper functions
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Install libshell from GitHub Release.

Options:
  -d, --dir DIR      Installation directory (default: ~/.libshell)
  -v, --version VER  Install specific version (default: latest)
  -s, --shell SHELL  Configure for shell: bash, zsh, pwsh, all (default: auto-detect)
  -h, --help         Show this help message

Examples:
  $0                          # Install latest to ~/.libshell, auto-detect shell
  $0 -d /opt/libshell         # Install to custom directory
  $0 -v v1.0.0                # Install specific version
  $0 -s zsh                   # Configure only for zsh

EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -s|--shell)
            SHELL_TYPE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            error "Unknown option: $1"
            usage
            ;;
    esac
done

# Detect available tools for downloading
detect_downloader() {
    if command -v curl &>/dev/null; then
        echo "curl"
    elif command -v wget &>/dev/null; then
        echo "wget"
    else
        error "Neither curl nor wget found. Please install one of them."
        exit 1
    fi
}

# Download file
download() {
    local url="$1"
    local output="$2"
    local downloader
    downloader=$(detect_downloader)
    
    if [ "$downloader" = "curl" ]; then
        curl -fsSL "$url" -o "$output"
    else
        wget -q "$url" -O "$output"
    fi
}

# Get JSON value (simple parser, no jq dependency)
get_json_value() {
    local json="$1"
    local key="$2"
    echo "$json" | grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'
}

# Get latest version from GitHub API
get_latest_version() {
    local api_url="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
    local response
    local downloader
    downloader=$(detect_downloader)
    
    if [ "$downloader" = "curl" ]; then
        response=$(curl -fsSL "$api_url" 2>/dev/null) || {
            error "Failed to fetch latest version from GitHub API"
            exit 1
        }
    else
        response=$(wget -qO- "$api_url" 2>/dev/null) || {
            error "Failed to fetch latest version from GitHub API"
            exit 1
        }
    fi
    
    local tag_name
    tag_name=$(get_json_value "$response" "tag_name")
    
    if [ -z "$tag_name" ]; then
        error "Failed to parse latest version from GitHub API"
        exit 1
    fi
    
    echo "$tag_name"
}

# Detect current shell
detect_shell() {
    local shell_name
    shell_name=$(basename "$SHELL")
    case "$shell_name" in
        bash|zsh)
            echo "$shell_name"
            ;;
        pwsh|powershell)
            echo "pwsh"
            ;;
        *)
            # Fallback: check what's available
            if [ -n "$ZSH_VERSION" ]; then
                echo "zsh"
            elif [ -n "$BASH_VERSION" ]; then
                echo "bash"
            else
                echo "bash"  # Default
            fi
            ;;
    esac
}

# Get shell config file
get_shell_config() {
    local shell_type="$1"
    case "$shell_type" in
        bash)
            if [ -f "$HOME/.bashrc" ]; then
                echo "$HOME/.bashrc"
            elif [ -f "$HOME/.bash_profile" ]; then
                echo "$HOME/.bash_profile"
            else
                echo "$HOME/.bashrc"
            fi
            ;;
        zsh)
            echo "$HOME/.zshrc"
            ;;
        pwsh)
            # PowerShell profile path varies by platform
            if [ -n "$USERPROFILE" ]; then
                # Windows
                echo "$USERPROFILE/Documents/PowerShell/Microsoft.PowerShell_profile.ps1"
            else
                # Linux/macOS
                echo "$HOME/.config/powershell/Microsoft.PowerShell_profile.ps1"
            fi
            ;;
    esac
}

# Add source line to shell config
configure_shell() {
    local shell_type="$1"
    local config_file
    config_file=$(get_shell_config "$shell_type")
    
    if [ -z "$config_file" ]; then
        warn "Could not determine config file for $shell_type"
        return 1
    fi
    
    local source_line
    local lib_file
    
    case "$shell_type" in
        bash)
            lib_file="${INSTALL_DIR}/lib.bash"
            source_line="source \"${lib_file}\""
            ;;
        zsh)
            lib_file="${INSTALL_DIR}/lib.zsh"
            source_line="source \"${lib_file}\""
            ;;
        pwsh)
            lib_file="${INSTALL_DIR}/lib.ps1"
            source_line=". \"${lib_file}\""
            ;;
    esac
    
    # Check if already configured
    if [ -f "$config_file" ] && grep -qF "$lib_file" "$config_file" 2>/dev/null; then
        info "libshell already configured in $config_file"
        return 0
    fi
    
    # Create config file directory if needed
    local config_dir
    config_dir=$(dirname "$config_file")
    mkdir -p "$config_dir"
    
    # Add source line
    echo "" >> "$config_file"
    echo "# libshell - added by install.sh" >> "$config_file"
    echo "$source_line" >> "$config_file"
    
    success "Added libshell to $config_file"
}

# Main installation
main() {
    info "Installing libshell..."
    
    # Determine version to install
    if [ "$VERSION" = "latest" ]; then
        info "Fetching latest version..."
        VERSION=$(get_latest_version)
    fi
    info "Version: $VERSION"
    
    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    info "Install directory: $INSTALL_DIR"
    
    # Download release tarball
    local download_url="https://github.com/${GITHUB_REPO}/releases/download/${VERSION}/libshell-${VERSION}.tar.gz"
    local tmp_file
    tmp_file=$(mktemp)
    
    info "Downloading from $download_url..."
    if ! download "$download_url" "$tmp_file"; then
        error "Failed to download release"
        rm -f "$tmp_file"
        exit 1
    fi
    
    # Extract to installation directory
    info "Extracting..."
    tar -xzf "$tmp_file" -C "$INSTALL_DIR" --strip-components=1
    rm -f "$tmp_file"
    
    # Make scripts executable
    chmod +x "$INSTALL_DIR"/*.sh 2>/dev/null || true
    
    success "libshell $VERSION installed to $INSTALL_DIR"
    
    # Configure shell
    if [ "$SHELL_TYPE" = "auto" ]; then
        SHELL_TYPE=$(detect_shell)
        info "Detected shell: $SHELL_TYPE"
    fi
    
    if [ "$SHELL_TYPE" = "all" ]; then
        for s in bash zsh; do
            configure_shell "$s" || true
        done
    else
        configure_shell "$SHELL_TYPE" || true
    fi
    
    echo ""
    success "Installation complete!"
    echo ""
    info "To start using libshell, either:"
    echo "  1. Restart your shell"
    echo "  2. Run: source ${INSTALL_DIR}/lib.${SHELL_TYPE:-bash}"
    echo ""
    info "To enable auto-updates, add to your shell config:"
    echo "  export LIBSHELL_AUTO_UPDATE=1"
}

main "$@"
