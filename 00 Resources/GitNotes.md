# Notes on Git

## Problem Solving

### Submoduling

When cloning a repo if you want to keep the folder you need to remove the .git folder and the submodules from the index:

- Remove submodules from index: `git rm --cached -r <folder where the git exists>`
- Remove .git folders:`rm -rf folder/.git`

Then git add, commit and push.
