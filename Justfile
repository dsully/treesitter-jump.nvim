# List available commands
default:
    @just --list

# Run tests using busted
test:
    @busted

# Format Lua code using stylua
format:
    @stylua lua
    @stylua spec

# Install dependencies using luarocks
deps:
    @luarocks install --local treesitter-jump.nvim-scm-1.rockspec
