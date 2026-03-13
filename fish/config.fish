if status is-interactive
    set -gx EDITOR nvim
    set -gx VISUAL nvim

    alias ls='ls --color=auto'
    alias la='ls -a'
    alias ll='ls -lah'
    alias c='clear'
    alias v='nvim'

    alias scshot='~/scripts/screenshot --area'
    alias volup='~/scripts/volume up'
    alias voldn='~/scripts/volume down'
    alias volmute='~/scripts/volume mute'

    if type -q fastfetch
        fastfetch --logo-type image --logo ~/assets/fetch.png
    end
end

