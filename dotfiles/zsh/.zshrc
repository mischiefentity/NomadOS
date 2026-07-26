# Lines configured by zsh-newuser-install
bindkey -e
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/mischief/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall


# Replaces Zsh's basic default "archlinux%" prompt with Kali's username@hostname:/full/current/directory % prompt
autoload -U colors && colors

PROMPT='%F{#d18b55}┌──(%F{#e6d6bd}%n@%m%F{#d18b55})-[%F{#c6a27a}%~%F{#d18b55}]
└─%F{#e6d6bd}$ %f'
