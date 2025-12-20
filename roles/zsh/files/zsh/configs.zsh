export EDITOR=nvim
export KUBECONFIG=~/.kube/k3s.yaml
ZSH_THEME="tjkirch"

export PUBLIC_CONTROL_PLANE_IP=10.23.11.1

export TALOSCONFIG=/home/winetree94/workspaces/tinyrack/public/talos/talosconfig

maybe_eval direnv hook zsh

git_clone_if_not_exists "https://github.com/nvm-sh/nvm.git" "--depth=1" "$HOME/.nvm"

git_clone_if_not_exists "https://github.com/tmux-plugins/tpm" "--depth=1" "$HOME/.tmux/plugins/tpm"

export FZF_BASE=${HOMEBREW_PREFIX}/opt/fzf
# export FZF_BASE=$(brew --prefix)/opt/fzf
