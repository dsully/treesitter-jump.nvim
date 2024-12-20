rockspec_format = "3.0"
package = "treesitter-jump.nvim"
version = "scm-1"
source = {
    url = "git+https://github.com/dsully/treesitter-jump.nvim",
}
dependencies = {
    "lua >= 5.1, < 5.4",
}
test_dependencies = {
    "nlua",
    "busted",
}
