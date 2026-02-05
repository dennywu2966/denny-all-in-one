" Minimal neovim config for PR review

call plug#begin('~/.local/share/nvim/plugged')

" Git integration
Plug 'tpope/vim-fugitive'

" Better diff viewing
Plug 'sindrets/diffview.nvim'

" Required dependency for diffview
Plug 'nvim-lua/plenary.nvim'

" File icons (optional but nice)
Plug 'nvim-tree/nvim-web-devicons'

call plug#end()

" Basic settings
set number
set relativenumber
set expandtab
set tabstop=4
set shiftwidth=4
set cursorline
set signcolumn=yes
set termguicolors

" Better diff colors
highlight DiffAdd    guibg=#1e3a1e guifg=NONE
highlight DiffDelete guibg=#3a1e1e guifg=NONE
highlight DiffChange guibg=#1e1e3a guifg=NONE
highlight DiffText   guibg=#3a3a1e guifg=NONE

" Key mappings for diff review
nnoremap <leader>do :DiffviewOpen main...es-lance-claude<CR>
nnoremap <leader>dc :DiffviewClose<CR>
nnoremap <leader>df :DiffviewFileHistory %<CR>
nnoremap ]c ]c
nnoremap [c [c

" Easier navigation
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-h> <C-w>h
nnoremap <C-l> <C-w>l
