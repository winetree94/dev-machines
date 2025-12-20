git_clone_if_not_exists() {
  local repo_url="$1"
  local options="$2"
  local target_dir="$3"

  if [[ ! -d "$target_dir" ]]; then
    local parent_dir="$(dirname "$target_dir")"
    mkdir -p "$parent_dir"
    echo "📥 $repo_url clone..."
    git clone "$options" "$repo_url" "$target_dir"
  fi
}

maybe_eval() {
  local cmd="$1"
  shift
  if command -v "$cmd" >/dev/null 2>&1; then
    eval "$("$cmd" "$@")"
  fi
}

maybe_alias() {
  local cmd="$1"
  local alias_name="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    alias "$alias_name"="$cmd"
  fi
}

sync_configs() {
  # zsh
  echo "sync zsh configs"
	rsync -av --delete \
    "$HOME/.config/zsh/" "$HOME/.dotconfigs/roles/zsh/files/zsh/"
	(
		cd "$HOME/.dotconfigs"
		ansible-vault encrypt "$HOME/.dotconfigs/roles/zsh/files/zsh/secrets.zsh"
	)

  # ssh
  echo "sync ssh configs"
  rsync -av --delete \
    --include 'config' \
    --include 'winetree94_id_rsa' \
    --include 'winetree94_id_rsa.pub' \
    --exclude '*' \
    "$HOME/.ssh/" "$HOME/.dotconfigs/roles/ssh/files/.ssh/"
  (
		cd "$HOME/.dotconfigs"
		ansible-vault encrypt "$HOME/.dotconfigs/roles/ssh/files/.ssh/winetree94_id_rsa"
		ansible-vault encrypt "$HOME/.dotconfigs/roles/ssh/files/.ssh/winetree94_id_rsa.pub"
  )

  # gitconfig
  echo "sync git configs"
  rsync -av \
    "$HOME/.gitconfig" "$HOME/.dotconfigs/roles/git/files/"

  # tmux
  echo "sync tmux configs"
	rsync -av --delete \
    "$HOME/.config/tmux/" "$HOME/.dotconfigs/roles/tmux/files/tmux/"

  # nvim
  echo "sync neovim configs"
	rsync -av --delete \
    "$HOME/.config/nvim/" "$HOME/.dotconfigs/roles/nvim/files/nvim/"

  # opencode
  echo "sync opencode configs"
	rsync -av --delete \
    "$HOME/.config/opencode/" "$HOME/.dotconfigs/roles/opencode/files/opencode/"
}
