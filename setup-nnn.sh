#!/bin/bash

# setup-nnn.sh - Portable nnn file manager setup with nerd fonts
# Compiles nnn from source with O_NERD=1 flag and configures a complete
# terminal file browser environment with plugins, opener script, and shell integration
#
# Supports: Debian (apt) and Arch (pacman)
# Requirements: git, make, gcc, readline library
# Output: nnn binary, plugins, opener script, shell configuration

# Ensure that if any part of a piped command fails, the whole pipeline is considered failed
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
DISTRO=""
PKG_INSTALL=""
NNN_VERSION="v5.0"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect Linux distribution
detect_distro() {
    print_status "Detecting distribution..."
    
    if command -v pacman &> /dev/null; then
        DISTRO="arch"
        PKG_INSTALL="sudo pacman -S --noconfirm"
        print_success "Detected: Arch Linux"
    elif command -v apt &> /dev/null; then
        DISTRO="debian"
        PKG_INSTALL="sudo apt install -y"
        print_success "Detected: Debian/Ubuntu"
    else
        print_error "Unsupported distribution - need Debian or Arch"
        print_error "All other distros are dead to me"
        return 1
    fi
    
    return 0
}

# Install dependencies
install_dependencies() {
    print_status "Installing build dependencies..."
    
    if [[ "$DISTRO" == "arch" ]]; then
        $PKG_INSTALL readline git make gcc || {
            print_error "Failed to install Arch dependencies"
            return 1
        }
    elif [[ "$DISTRO" == "debian" ]]; then
        sudo apt update || print_warning "apt update failed, continuing..."
        $PKG_INSTALL libreadline-dev git make gcc build-essential || {
            print_error "Failed to install Debian dependencies"
            return 1
        }
    fi
    
    print_success "Dependencies installed"
    return 0
}

# Compile and install nnn
compile_nnn() {
    print_status "Compiling nnn from source with nerd font support..."
    
    # Clean up any existing build
    if [[ -d "/tmp/nnn" ]]; then
        print_status "Cleaning up old build directory..."
        rm -rf /tmp/nnn
    fi
    
    # Clone nnn repository
    print_status "Cloning nnn repository..."
    if ! git clone --quiet --depth 1 https://github.com/jarun/nnn.git /tmp/nnn; then
        print_error "Failed to clone nnn repository"
        return 1
    fi
    
    # Compile with nerd font support
    print_status "Compiling with O_NERD=1 flag..."
    cd /tmp/nnn || return 1
    
    if ! make O_NERD=1; then
        print_error "Compilation failed"
        return 1
    fi
    
    # Install binary
    print_status "Installing nnn to /usr/local/bin..."
    if ! sudo install -m 755 /tmp/nnn/nnn /usr/local/bin/; then
        print_error "Failed to install nnn binary"
        return 1
    fi
    
    print_success "nnn compiled and installed successfully"
    
    # Install plugins
    print_status "Installing nnn plugins..."
    mkdir -p "$HOME/.config/nnn/plugins"
    
    if ! cp -r /tmp/nnn/plugins/* "$HOME/.config/nnn/plugins/"; then
        print_warning "Failed to copy some plugins"
    fi
    
    chmod +x "$HOME/.config/nnn/plugins/"* 2>/dev/null || print_warning "Some plugins may not be executable"
    
    print_success "Plugins installed to ~/.config/nnn/plugins/"
    
    # Cleanup
    print_status "Cleaning up build directory..."
    rm -rf /tmp/nnn
    
    return 0
}

# Create nnn opener script
create_opener_script() {
    print_status "Creating nnn_opener.sh in ~/bin..."
    
    # Ensure ~/bin exists
    mkdir -p "$HOME/bin"
    
    # Create the opener script with heredoc
    cat > "$HOME/bin/nnn_opener.sh" << 'EOF'
#!/bin/bash

    # Get the MIME type of the file
    FPATH="$1"
    MIMETYPE="$(file -bL --mime-type -- "${FPATH}")"

    case "${MIMETYPE}" in
        # Text files and similar
        text/*|application/json|application/xml|application/x-shellscript|inode/x-empty|\
        application/x-yaml|application/javascript)
            if [ -w "$1" ]; then
                tmux new-window -n "edit" "$EDITOR \"$1\""
            else
                tmux new-window -n "edit" "sudo $EDITOR \"$1\""
            fi
        ;;

        # Images
        image/*)
            if type chafa >/dev/null 2>&1; then
                tmux new-window -n "image" "chafa \"$1\"; read -n 1"
            elif type timg >/dev/null 2>&1; then
                tmux new-window -n "image" "timg \"$1\"; read -n 1"
            elif type viu >/dev/null 2>&1; then
                tmux new-window -n "image" "viu \"$1\"; read -n 1"
            else
                echo "No terminal image viewer found. Install chafa, timg, or viu"
                exit 1
            fi
        ;;

        # PDFs
        application/pdf)
            if type pdftotext >/dev/null 2>&1; then
                tmux new-window -n "pdf" "pdftotext \"$1\" - | less"
            elif type mutool >/dev/null 2>&1; then
                tmux new-window -n "pdf" "mutool draw -F txt \"$1\" | less"
            else
                echo "No PDF viewer found. Install poppler-utils or mupdf-tools"
                exit 1
            fi
        ;;

        # Everything else
        *)
            echo "Cannot open file type: ${MIMETYPE}"
            exit 1
        ;;
    esac
EOF

    # Make executable
    chmod +x "$HOME/bin/nnn_opener.sh"
    
    if [[ -x "$HOME/bin/nnn_opener.sh" ]]; then
        print_success "Opener script created at ~/bin/nnn_opener.sh"
        return 0
    else
        print_error "Failed to create opener script"
        return 1
    fi
}

# Configure shell integration
configure_shell() {
    print_status "Configuring shell integration..."
    
    # Detect shell rc file
    local shell_rc=""
    if [[ -f "$HOME/.zshrc" ]]; then
        shell_rc="$HOME/.zshrc"
        print_status "Found .zshrc"
    elif [[ -f "$HOME/.bashrc" ]]; then
        shell_rc="$HOME/.bashrc"
        print_status "Found .bashrc"
    else
        print_warning "No .zshrc or .bashrc found, creating .bashrc..."
        touch "$HOME/.bashrc"
        shell_rc="$HOME/.bashrc"
    fi
    
    # Check if nnn configuration already exists
    if grep -q "# nnn file manager configuration" "$shell_rc" 2>/dev/null; then
        print_warning "nnn configuration already exists in $shell_rc"
        print_status "Skipping shell configuration..."
        return 0
    fi
    
    # Append nnn configuration
    print_status "Adding nnn configuration to $shell_rc..."
    
    cat >> "$shell_rc" << 'EOF'

# nnn file manager configuration
# Added by setup-nnn.sh

# nnn environment variables
if [ -f ~/bin/nnn_opener.sh ]; then
    export NNN_OPENER=~/bin/nnn_opener.sh
fi
export NNN_PAGER="${PAGER:-less}"
export NNN_PLUG="p:preview-tui;f:fzf"
export NNN_FCOLORS='c1e2B32e006033f7c6d6abc4'
export NNN_BATTHEME='Nord'
export NNN_BATSTYLE='plain'

# nnn function with advanced features
nn(){
    # Block nesting of nnn in subshells
    [ "${NNNLVL:-0}" -eq 0 ] || {
        echo "nnn is already running"
        return
    }
    if [ -z "$EDITOR" ]; then
        EDITOR=nano
    fi

    NNN_FIFO="$(mktemp --suffix=-nnn -u)"
    export NNN_FIFO
    export NNN_TMPFILE="${XDG_CONFIG_HOME:-$HOME/.config}/nnn/.lastd"
    (umask 077; mkfifo "$NNN_FIFO")
    command nnn -dHEPp "$@"
    [ ! -f "$NNN_TMPFILE" ] || {
        . "$NNN_TMPFILE"
        rm -f -- "$NNN_TMPFILE" > /dev/null
    }
}

# nnn minimal function
n(){
    # Block nesting of nnn in subshells
    [ "${NNNLVL:-0}" -eq 0 ] || {
        echo "nnn is already running"
        return
    }
    if [ -z "$EDITOR" ]; then
        EDITOR=nano
    fi

    NNN_FIFO="$(mktemp --suffix=-nnn -u)"
    export NNN_FIFO
    export NNN_TMPFILE="${XDG_CONFIG_HOME:-$HOME/.config}/nnn/.lastd"
    (umask 077; mkfifo "$NNN_FIFO")
    command nnn -E "$@"
    [ ! -f "$NNN_TMPFILE" ] || {
        . "$NNN_TMPFILE"
        rm -f -- "$NNN_TMPFILE" > /dev/null
    }
}
EOF

    print_success "Shell configuration added to $shell_rc"
    return 0
}

# Verify installation
verify_installation() {
    print_status "Verifying installation..."
    
    local errors=0
    
    # Check nnn binary
    if command -v nnn &> /dev/null; then
        print_success "nnn binary found: $(which nnn)"
    else
        print_error "nnn binary not found in PATH"
        errors=$((errors + 1))
    fi
    
    # Check plugins directory
    if [[ -d "$HOME/.config/nnn/plugins" ]]; then
        local plugin_count=$(find "$HOME/.config/nnn/plugins" -type f | wc -l)
        print_success "Plugins directory exists ($plugin_count plugins)"
    else
        print_error "Plugins directory not found"
        errors=$((errors + 1))
    fi
    
    # Check opener script
    if [[ -x "$HOME/bin/nnn_opener.sh" ]]; then
        print_success "Opener script exists and is executable"
    else
        print_error "Opener script not found or not executable"
        errors=$((errors + 1))
    fi
    
    # Check shell configuration
    if [[ -f "$HOME/.zshrc" ]] && grep -q "nnn file manager configuration" "$HOME/.zshrc"; then
        print_success "Shell configuration added to .zshrc"
    elif [[ -f "$HOME/.bashrc" ]] && grep -q "nnn file manager configuration" "$HOME/.bashrc"; then
        print_success "Shell configuration added to .bashrc"
    else
        print_warning "Shell configuration may not be properly added"
    fi
    
    if [[ $errors -eq 0 ]]; then
        print_success "Verification complete - all checks passed!"
        return 0
    else
        print_error "Verification failed with $errors error(s)"
        return 1
    fi
}

# Test current setup
test_setup() {
    print_status "Testing current nnn setup..."
    echo
    
    # Check if nnn is installed
    if command -v nnn &> /dev/null; then
        print_success "nnn is installed: $(nnn -V 2>&1 | head -n1)"
    else
        print_error "nnn is not installed"
    fi
    
    # Check for nerd font support
    if nnn -V 2>&1 | grep -qi "O_NERD"; then
        print_success "nnn compiled with nerd font support"
    else
        print_warning "nnn may not have nerd font support"
    fi
    
    # Check plugins
    if [[ -d "$HOME/.config/nnn/plugins" ]]; then
        local plugin_count=$(find "$HOME/.config/nnn/plugins" -type f 2>/dev/null | wc -l)
        print_success "Plugins directory exists ($plugin_count plugins)"
    else
        print_warning "Plugins directory not found"
    fi
    
    # Check opener script
    if [[ -x "$HOME/bin/nnn_opener.sh" ]]; then
        print_success "Opener script exists"
    else
        print_warning "Opener script not found"
    fi
    
    # Check shell config
    if [[ -f "$HOME/.zshrc" ]] && grep -q "nnn file manager configuration" "$HOME/.zshrc"; then
        print_success "Shell configuration found in .zshrc"
    elif [[ -f "$HOME/.bashrc" ]] && grep -q "nnn file manager configuration" "$HOME/.bashrc"; then
        print_success "Shell configuration found in .bashrc"
    else
        print_warning "Shell configuration not found"
    fi
    
    echo
}

# Main installation function
install_nnn() {
    print_status "Starting portable nnn installation..."
    echo
    
    # Run installation steps
    detect_distro || exit 1
    install_dependencies || exit 1
    compile_nnn || exit 1
    create_opener_script || exit 1
    configure_shell || exit 1
    
    echo
    verify_installation || {
        print_error "Installation completed with errors"
        exit 1
    }
    
    echo
    print_success "nnn installation completed successfully!"
    echo
    print_status "Next steps:"
    echo "1. Restart your shell or run: source ~/.zshrc (or ~/.bashrc)"
    echo "2. Launch nnn with full features: nn"
    echo "3. Launch nnn minimal: n"
    echo "4. Try the fzf plugin: Press ; then f inside nnn"
    echo
    print_status "Key bindings:"
    echo "  ;f  - Launch fzf fuzzy finder"
    echo "  ;p  - Preview files"
    echo "  ?   - Show help inside nnn"
    echo
    print_status "Opener script handles text, images, and PDFs in tmux windows"
    echo
}

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Portable nnn file manager setup with nerd fonts support"
    echo "Compiles from source and configures complete terminal file browser"
    echo
    echo "OPTIONS:"
    echo "  -h, --help     Show this help message"
    echo "  -t, --test     Test current nnn setup without installing"
    echo
    echo "REQUIREMENTS:"
    echo "  - Debian (apt) or Arch (pacman)"
    echo "  - git, make, gcc, readline library"
    echo "  - Optional: tmux (for opener script)"
    echo "  - Optional: fzf (for fuzzy finding)"
    echo
    echo "FEATURES:"
    echo "  - nnn compiled with nerd font support (O_NERD=1)"
    echo "  - All official plugins installed"
    echo "  - Custom opener script for text/images/PDFs"
    echo "  - Shell integration (nn and n functions)"
    echo "  - fzf plugin on semicolon+f"
    echo
    echo "EXAMPLES:"
    echo "  $0              # Full installation"
    echo "  $0 --test       # Test current setup"
    echo
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -t|--test)
        test_setup
        exit 0
        ;;
    "")
        install_nnn
        ;;
    *)
        print_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac

