# Miscellaneous odds and ends

## Miscellaneous tips

### vim

* My `.vimrc`:

```text
set tabstop=4
set shiftwidth=4
set expandtab
highlight ExtraWhitespace ctermbg=red guibg=red
match ExtraWhitespace /\s\+$/

augroup trailing_whitespace
  autocmd!
  autocmd BufWritePre *.c :%s/\s\+$//e
  autocmd BufWritePre *.h :%s/\s\+$//e
  autocmd BufWritePre *.cxx :%s/\s\+$//e
  autocmd BufWritePre *.hxx :%s/\s\+$//e
augroup END

nmap <silent> <A-Up> :wincmd k<CR>
nmap <silent> <A-Down> :wincmd j<CR>
nmap <silent> <A-Left> :wincmd h<CR>
nmap <silent> <A-Right> :wincmd l<CR>
```

### git

* To show all branches in a tree like structure, run:  `git config --global alias.logtree "log --graph --simplify-by-decoration --all --branches --oneline --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"`  Then you just use `git logtree`

## Document Liberation Project

* [https://www.documentliberation.org/](https://www.documentliberation.org/)
* [https://davetardon.wordpress.com/category/document-liberation/](https://davetardon.wordpress.com/category/document-liberation/)

