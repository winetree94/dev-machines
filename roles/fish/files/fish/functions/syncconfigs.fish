function syncconfigs
    set -l target $argv[1]

    switch $target
        case fish
            rsync -vrl --delete --exclude='bitwarden.fish' ~/.config/fish/ ~/.dotconfigs/roles/fish/files/fish
        case nvim
            rsync -vrl --delete ~/.config/nvim/ ~/.dotconfigs/roles/nvim/files/nvim
        case tmux
            rsync -vrl --delete ~/.tmux.conf ~/.dotconfigs/roles/tmux/files/.tmux.conf
    end

end
