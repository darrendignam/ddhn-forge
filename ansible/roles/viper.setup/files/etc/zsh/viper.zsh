# ViPER interactive shell behaviour, sourced from /etc/zsh/zshrc.
#
# Two plugins do the work:
#   zsh-syntax-highlighting  colours the first word by whether it resolves to something
#                            runnable, so a typo is red before you press return
#   zsh-autosuggestions      offers the rest of the line in grey from history
#
# Order matters: autosuggestions must be sourced after syntax highlighting, or the
# highlighter repaints over the suggestion and it never becomes visible.

[[ -o interactive ]] || return

HISTFILE=${HOME}/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS

# A new appliance has no history, so seed it once from the shipped examples. Without
# this the grey suggestions stay empty until the user has typed everything by hand,
# which is precisely when the hint is least useful.
if [[ ! -f ${HISTFILE} && -r /usr/local/share/viper/viper-history ]]; then
  cp /usr/local/share/viper/viper-history "${HISTFILE}"
  chmod 600 "${HISTFILE}"
fi

# Read it explicitly. HISTFILE is set here, after zsh has already decided what to load,
# so a history file that was seeded by post-install.sh rather than by the branch above
# would otherwise be ignored and the suggestions would come up empty.
[[ -r ${HISTFILE} ]] && fc -R "${HISTFILE}"

autoload -Uz compinit && compinit -d "${HOME}/.zcompdump"
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

[[ -r /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

if [[ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  # Fall back to the completion system when history has no match, so the suggestion
  # still appears for a command the user has not run before.
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)
  source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# Right arrow or End accepts the grey suggestion.
bindkey '^[[C' forward-char
bindkey '^[OF' end-of-line

# Prompt. The working directory leads, because on an appliance whose job is running
# tools over files, that is the piece of context that matters.
#
# user@host is dropped. In the container the hostname is the random container ID, which
# tells nobody anything and pushes the path to the right; in the VM it is always
# "viper", which is equally uninformative. Where identity does matter, over SSH, it is
# shown, since then you may well be on a machine that is not this one.
#
# %(4~|.../%3~|%~) keeps a deep path readable by eliding all but the last three parts.
if [[ -n ${SSH_CONNECTION} ]]; then
  PROMPT='%F{green}%n@%m%f %B%F{cyan}%(4~|.../%3~|%~)%f%b %F{yellow}❯%f '
else
  PROMPT='%B%F{cyan}%(4~|.../%3~|%~)%f%b %F{yellow}❯%f '
fi

# Failed commands announce themselves on the right rather than silently.
RPROMPT='%(?..%F{red}exit %?%f)'
