#!/bin/bash

# Setup script for image.nvim plugin in LazyVim
# This script automates the installation and configuration of image.nvim
# for viewing images directly in Neovim when using Kitty terminal

set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if running in Kitty terminal
check_terminal() {
    if [[ "$TERM" != "xterm-kitty" ]]; then
        print_warning "This script is designed for Kitty terminal"
        print_warning "Current terminal: $TERM"
        print_warning "Image preview may not work in other terminals"
    else
        print_success "Running in Kitty terminal - perfect for image.nvim!"
    fi
}

# Check for ImageMagick
check_imagemagick() {
    print_status "Checking for ImageMagick..."
    
    if command -v magick &> /dev/null; then
        print_success "ImageMagick found (magick command)"
        return 0
    elif command -v convert &> /dev/null; then
        print_success "ImageMagick found (convert command)"
        return 0
    else
        print_error "ImageMagick not found!"
        print_status "Installing ImageMagick..."
        
        if command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm imagemagick
        elif command -v apt &> /dev/null; then
            sudo apt update && sudo apt install -y imagemagick
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y ImageMagick
        else
            print_error "Package manager not recognized. Please install ImageMagick manually."
            return 1
        fi
    fi
}

# Check Neovim and LazyVim
check_neovim() {
    print_status "Checking for Neovim..."
    
    if ! command -v nvim &> /dev/null; then
        print_error "Neovim not found! Please install Neovim first."
        return 1
    fi
    
    print_success "Neovim found: $(nvim --version | head -n1)"
    
    # Check if LazyVim is installed
    if [[ ! -d "$HOME/.config/nvim" ]]; then
        print_error "LazyVim configuration not found at ~/.config/nvim"
        print_status "Please install LazyVim first: https://lazyvim.github.io/install"
        return 1
    fi
    
    print_success "LazyVim configuration found"
}

# Create image.nvim configuration
create_config() {
    print_status "Creating image.nvim configuration..."
    
    local config_dir="$HOME/.config/nvim/lua/plugins"
    local config_file="$config_dir/image.lua"
    
    # Ensure plugins directory exists
    mkdir -p "$config_dir"
    
    # Create the configuration file
    cat > "$config_file" << 'EOF'
return {
  "3rd/image.nvim",
  event = "VeryLazy",
  opts = {
    backend = "kitty",
    integrations = {
      markdown = {
        enabled = true,
        clear_in_insert_mode = false,
        download_remote_images = true,
        only_render_image_at_cursor = false,
        filetypes = { "markdown", "vimwiki" },
      },
      neorg = {
        enabled = true,
        clear_in_insert_mode = false,
        download_remote_images = true,
        only_render_image_at_cursor = false,
        filetypes = { "norg" },
      },
    },
    max_width = nil,
    max_height = nil,
    max_width_window_percentage = nil,
    max_height_window_percentage = 50,
    window_overlap_clear_enabled = false,
    window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "" },
    editor_only_render_when_focused = false,
    tmux_show_only_in_active_window = false,
    hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp" },
  },
}
EOF
    
    if [[ -f "$config_file" ]]; then
        print_success "Configuration created at: $config_file"
    else
        print_error "Failed to create configuration file"
        return 1
    fi
}

# Test Kitty image display
test_kitty() {
    print_status "Testing Kitty image display capability..."
    
    # Create a simple test image if none exists
    local test_image="/tmp/test_image.png"
    
    if [[ ! -f "$test_image" ]]; then
        print_status "Creating test image..."
        magick -size 100x100 xc:blue "$test_image" 2>/dev/null || convert -size 100x100 xc:blue "$test_image"
    fi
    
    print_status "Testing Kitty icat command..."
    if kitty +kitten icat "$test_image" &>/dev/null; then
        print_success "Kitty image display working correctly!"
    else
        print_warning "Kitty image display test failed"
        print_warning "Make sure you're running this in a Kitty terminal"
    fi
    
    # Clean up test image
    rm -f "$test_image"
}

# Main installation function
install_image_nvim() {
    print_status "Starting image.nvim setup for LazyVim..."
    echo
    
    # Run checks
    check_terminal
    check_imagemagick || exit 1
    check_neovim || exit 1
    create_config || exit 1
    test_kitty
    
    echo
    print_success "image.nvim setup completed!"
    echo
    print_status "Next steps:"
    echo "1. Open Neovim in Kitty terminal: nvim"
    echo "2. LazyVim will auto-install the plugin (or run :Lazy sync)"
    echo "3. Test with an image file: nvim /path/to/image.png"
    echo
    print_status "Supported formats: PNG, JPG, JPEG, GIF, WebP"
    print_status "Works in: Kitty terminal with ImageMagick"
    echo
}

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Setup image.nvim plugin for LazyVim to display images in Neovim"
    echo
    echo "OPTIONS:"
    echo "  -h, --help     Show this help message"
    echo "  -t, --test     Only test current setup without installing"
    echo
    echo "REQUIREMENTS:"
    echo "  - Kitty terminal"
    echo "  - Neovim with LazyVim"
    echo "  - ImageMagick (will be installed if missing)"
    echo
    echo "EXAMPLES:"
    echo "  $0              # Full installation"
    echo "  $0 --test       # Test current setup only"
    echo
}

# Test only function
test_only() {
    print_status "Testing current image.nvim setup..."
    echo
    
    check_terminal
    check_imagemagick
    check_neovim
    
    # Check if config exists
    if [[ -f "$HOME/.config/nvim/lua/plugins/image.lua" ]]; then
        print_success "image.nvim configuration found"
    else
        print_warning "image.nvim configuration not found"
    fi
    
    test_kitty
}

# Parse command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -t|--test)
        test_only
        exit 0
        ;;
    "")
        install_image_nvim
        ;;
    *)
        print_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac
