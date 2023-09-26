set nocompatible
filetype off

set encoding=utf-8

if !exists("autocommands_loaded")
  let autocommands_loaded = 1
  autocmd!
  autocmd vimenter * NERDTree
  autocmd StdinReadPre * let s:std_in=1
  autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTreeType") && b:NERDTreeType == "primary") | q | endif

  " Make the quickfix window across the bottom
  autocmd FileType qf wincmd J
endif

set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

Plugin 'gmarik/Vundle.vim'
Plugin 'scrooloose/nerdtree'
Plugin 'scrooloose/syntastic'
Plugin 'scrooloose/nerdcommenter'
Plugin 'majutsushi/tagbar'
Plugin 'bdebruyn/cpp-dev.vim'
Plugin 'vim-scripts/bash-support.vim'
Plugin 'vim-scripts/netrw.vim'
Plugin 'vim-scripts/ctags.vim--Johnson'
Plugin 'jlanzarotta/bufexplorer'
Plugin 'rking/ag.vim'
Plugin 'tpope/vim-abolish'
Plugin 'tpope/vim-repeat'
Plugin 'kien/ctrlp.vim'
Plugin 'Valloric/YouCompleteMe'
Plugin 'aklt/plantuml-syntax'

call vundle#end()

filetype plugin indent on
syntax on

let g:VIMHOME=expand('<sfile>:p:h')

" clean up extra window from YouCompleteMe
let g:ycm_preview_to_completeopt=0
let g:ycm_autoclose_preview_window_after_completion=1
let g:ycm_actoclose_preview_window_after_insertion=1
let g:ycm_always_populate_location_list = 1

set nofoldenable

set showtabline=1
set guioptions+=e
set guifont=Monospace\ 9
set ignorecase
set smartcase
set hlsearch
set incsearch
set lazyredraw
set magic
set showmatch
set mat=2
set number
set history=1000
set nowrap
set tw=0

" Put backups in temp folder
set backup
set backupdir=~/.vim-tmp,~/.tmp,/var/tmp,/tmp
set backupskip=/tmp/*,/private/tmp/*
set directory=~/.vim-tmp,~/tmp,/var/tmp,/tmp

" no annoying sound on errors
set noerrorbells
set novisualbell
set t_vb=
set tm=500

" Tab settings
set tabstop=3
set shiftwidth=3
set softtabstop=3
set expandtab

set splitright
set splitbelow

set errorformat=\../%f\ \+%l\:%c\:%m
set errorformat+=\../%f\:%l\:%m
set errorformat+=\../%f\ \+%l\:%c\:%.%#
set errorformat+=%f\:%l\:%m
set errorformat+=%f\(%l\):%m

let mapleader = ","

" Make the quickfix window across the bottom
autocmd FileType qf wincmd J

syntax enable
set background=dark
let g:solarized_termcolors = 256
colorscheme desert

set guicursor=n-v-c:block-Cursor
set guicursor+=i:ver25-iCursor
set guicursor+=n-v-c:blinkon0
set guicursor+=i:blinkwait10

let g:NERDTreeWinPos = "left"

function! OpenNerdTreePanel()
   let g:currentWindow=winnr()
   if g:NERDTree.IsOpen()
      let g:currentWindow-=1
   else
      let g:currentWindow+=1
   endif
   exec "NERDTreeToggle"
   call RestoreEditWindow()
endfunction

inoremap jk <esc>

nnoremap <Leader>n :call OpenNerdTreePanel()<cr>
nnoremap <silent> <Leader>v :NERDTreeFind<CR>
nnoremap <leader>i :tabnew<bar>call OpenNerdTreePanel()<CR>
nnoremap <leader>D :tabclose<CR>

nmap <C-h> <C-w>h
nmap <C-j> <C-w>j
nmap <C-k> <C-w>k
nmap <C-l> <C-w>l

" " window
nmap <leader>wh :topleft  vnew<CR>
nmap <leader>wl :botright vnew<CR>
nmap <leader>wk :topleft  new<CR>
nmap <leader>wj :botright new<CR>
" buffer
nmap <leader>s<left>   :leftabove  vnew<CR>
nmap <leader>s<right>  :rightbelow vnew<CR>
nmap <leader>s<up>     :leftabove  new<CR>
nmap <leader>s<down>   :rightbelow new<CR>

