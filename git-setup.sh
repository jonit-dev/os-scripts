#!/bin/bash

# Git Configuration Script
# This script sets up Git with user preferences and handy aliases.

echo "=== Git Configuration Setup ==="

# Function to prompt for input with a default value
prompt() {
    local PROMPT_MESSAGE=$1
    local DEFAULT_VALUE=$2
    read -p "$PROMPT_MESSAGE [$DEFAULT_VALUE]: " INPUT
    # If input is empty, use the default value
    if [ -z "$INPUT" ]; then
        INPUT=$DEFAULT_VALUE
    fi
    echo "$INPUT"
}

# Retrieve existing Git config if available
CURRENT_NAME=$(git config --global user.name)
CURRENT_EMAIL=$(git config --global user.email)

# Prompt for Git user name
if [ -z "$CURRENT_NAME" ]; then
    DEFAULT_NAME="Your Name"
else
    DEFAULT_NAME="$CURRENT_NAME"
fi
USER_NAME=$(prompt "Enter your Git user name" "$DEFAULT_NAME")

# Prompt for Git user email
if [ -z "$CURRENT_EMAIL" ]; then
    DEFAULT_EMAIL="you@example.com"
else
    DEFAULT_EMAIL="$CURRENT_EMAIL"
fi
USER_EMAIL=$(prompt "Enter your Git user email" "$DEFAULT_EMAIL")

# Set Git global user name and email
git config --global user.name "$USER_NAME"
git config --global user.email "$USER_EMAIL"

echo "✅ Git user.name set to '$USER_NAME'"
echo "✅ Git user.email set to '$USER_EMAIL'"

# Set default pull strategy to rebase
git config --global pull.rebase true
echo "✅ Set 'pull.rebase' to true (default pull strategy: rebase)"

# Automatically set upstream when creating new branches
git config --global branch.autoSetupMerge always
git config --global push.default simple
echo "✅ Enabled automatic upstream tracking for new branches"
echo "✅ Set 'push.default' to 'simple'"

# Set default editor to nano (you can change this to vim, code, etc.)
git config --global core.editor nano
echo "✅ Set default Git editor to 'nano'"

# Add Git aliases for productivity
echo "✅ Setting up Git aliases..."

git config --global alias.st status
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
git config --global alias.lg "log --oneline --graph --decorate --all"
git config --global alias.last "log -1 HEAD"
git config --global alias.unstage "reset HEAD --"
git config --global alias.amend "commit --amend"
git config --global alias.discard "checkout --"
git config --global alias.visual "!gitk &"
git config --global alias.logg "log --pretty=format:'%C(yellow)%h%Creset - %C(green)(%ar)%Creset %s%C(red)%d%Creset %C(blue)[%an]%Creset' --abbrev-commit --date=relative"

echo "✅ Git aliases set:"
echo "   st        => status"
echo "   co        => checkout"
echo "   br        => branch"
echo "   ci        => commit"
echo "   lg        => Pretty compact log with graph"
echo "   last      => Show the last commit"
echo "   unstage   => Unstage files"
echo "   amend     => Amend the last commit"
echo "   discard   => Discard changes in working directory"
echo "   visual    => Open GitK"
echo "   logg      => Customized pretty log"

# Optional: Enable colored Git output
git config --global color.ui true
echo "✅ Enabled colored Git output"

# Optional: Set up default merge tool (e.g., vimdiff, meld)
# Uncomment and set your preferred merge tool
# git config --global merge.tool vimdiff
# echo "✅ Set default merge tool to 'vimdiff'"

echo "🎉 Git configuration setup complete!"
