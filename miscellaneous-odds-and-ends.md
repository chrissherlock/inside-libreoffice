#Miscellaneous tips
## vim

## git

* To show all branches in a tree like structure, run:<br><br>`git config --global alias.logtree "log --graph --simplify-by-decoration --all --branches --oneline --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"`<br><br>Then you just use `git logtree`