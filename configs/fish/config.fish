set -g fish_greeting ""

if status is-interactive
    type -q fastfetch; and fastfetch
end

type -q starship; and starship init fish | source

fish_add_path $HOME/.local/bin $HOME/.cargo/bin

alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias grep='grep --color=auto'
alias ..='cd ..'
alias update='sudo pacman -Syu'
