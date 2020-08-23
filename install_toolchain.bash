#!/bin/bash -eu

# ****************************************************************************
# DESCRIPTION
#   Bash script to locally install my prefered working setup, mainly based
#   one homebrew.
#   Probably this is not useful for any any other person than me.
# ****************************************************************************

# bugs and hints: lrsklemstein@gmail.com


# ----------------------------------------------------------------------------
# declarations
# ----------------------------------------------------------------------------

readonly PROG=${0##*/}

readonly HOMEBREW_BASE_URL=https://raw.githubusercontent.com/Homebrew
readonly HOMEBREW_INSTALLER_URL=${HOMEBREW_BASE_URL}/install/master/install.sh

readonly INST_MODDER=$(cd ${0%/*}; echo $PWD/mod_homebrew_installer.pl)

readonly HOMEBREW_PACKAGES=$(cd ${0%/*}; echo $PWD/packages_homebrew.txt)
readonly PYTHON_PACKAGES=$(cd ${0%/*}; echo $PWD/packages_python.txt)

readonly PROFILE_HOMEBREW=$HOME/.profile_homebrew
readonly PROFILE_USER=$HOME/.profile_local

if [ -n "$WSL_DISTRO_NAME" -a -d /mnt/c/Windows ]
then
	readonly IS_WSL_DISTRO=y
else
	readonly IS_WSL_DISTRO=n
fi

readonly TMPDIR=$(mktemp -d)
trap 'cd - >/dev/null; /bin/rm -rf $TMPDIR' 0 1 2
cd $TMPDIR


# ----------------------------------------------------------------------------
# functions
# ----------------------------------------------------------------------------

main() {
    check_requirements
    initial_cleanup

    install_homebrew

    set_homebrew_environment
    install_homebrew_packages
    install_python_packages

	if [ "$IS_WSL_DISTRO" = n ]
	then
    	install_rust
	else
		msg_warn "WSL detected, skip rust installation"	
	fi

    msg_ok "Done!"
    exit 0
}

msg_ok() {
    echo -e "\e[92m[$PROG] $1\e[39m" >&2
}

msg_warn() {
    echo -e "\e[93m[$PROG] $1\e[39m" >&2
}

msg_error() {
    echo -e "\e[91m[$PROG] $1\e[39m" >&2
}

msg_abort() {
    msg_error "$1"
    exit 1
}

check_requirements() {
    test -f $INST_MODDER || \
        msg_abort "\"$INSTALLER_MODDER\" not found"
    test -x $INST_MODDER || \
        msg_abort "\"$INSTALLER_MODDER\" found, but not executable"

    test -f $HOMEBREW_PACKAGES || \
        msg_abort "homebrew packages file \"$HOMEBREW_PACKAGES\" not found"

    test -f $PYTHON_PACKAGES || \
        msg_abort "python packages file \"$PYTHON_PACKAGES\" not found"
}

initial_cleanup() {
    local coc_path="$HOME/.config/coc"
    local coc_path_saved="${coc_path}.saved"

    if [ -d $coc_path ]
    then
        msg_warn "Detected existing $coc_path..."
        msg_warn "Will save as $coc_path_saved"

        /bin/mv -v $coc_path $coc_path_saved
    fi
}

install_homebrew() {
    local installer_basename user_name marker

    marker='[Homebrew install] '
    msg_ok "${marker}now in $PWD"
    msg_ok "${marker}download $HOMEBREW_INSTALLER_URL..."

    installer_basename=${HOMEBREW_INSTALLER_URL##*/}
    msg_ok "${marker}installer should be $PWD/$installer_basename"

    user_name=$(id -un)

    wget -q $HOMEBREW_INSTALLER_URL

    chmod +x $installer_basename
    msg_ok "chmod +x on $installer_basename"

	msg_ok "Convince $installer_basename to be behave silently..."
	$INST_MODDER $installer_basename $installer_basename.mod

	msg_ok "Call (modified) $ ./$installer_basename.mod..."
	./$installer_basename.mod

    msg_ok "${marker}...done"
}

set_homebrew_environment() {
    msg_ok "Create/overwrite $PROFILE_HOMEBREW..."
    $HOME/.linuxbrew/bin/brew shellenv >$PROFILE_HOMEBREW

    if ! grep -q ". \$HOME/.${PROFILE_HOMEBREW}" $PROFILE_USER
    then
        {
            echo ""
            echo ". ${PROFILE_HOMEBREW/$HOME/\$HOME}"
        } >> $PROFILE_USER

        msg_ok "Added sourcing of $PROFILE_HOMEBREW in $PROFILE_USER..."
    else
        msg_ok "Sourcing of $PROFILE_HOMEBREW in $PROFILE_USER already in place"
    fi

    . $PROFILE_HOMEBREW
    msg_ok "Activated homebrew environment for further processing"
}

install_homebrew_packages() {
    msg_ok "Install Homebrew packages from $HOMEBREW_PACKAGES..."

    for program in $(< $HOMEBREW_PACKAGES) 
    do
        msg_ok "-> $program"
        brew install $program
    done

    msg_ok "Homebrew package installation finshed"
}

install_python_packages() {
    msg_ok "Install Python packages from $HOMEBREW_PACKAGES..."

    for py_package in $(< $PYTHON_PACKAGES) 
    do
        msg_ok "-> $py_package"
        pip3 install $py_package
    done

    msg_ok "Python packages installation finshed"
}

install_rust() {
    local rustup_program=$(which rustup)
    if [ -n "$rustup_program" ] && [[ "$rustup_program" == $HOME/* ]]
    then
        msg_warn "Found local rust installation, will only update..."
        rustup update
        msg_warn "...done"
    else
        msg_ok "Install rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    fi
}


# ----------------------------------------------------------------------------
# main
# ----------------------------------------------------------------------------

main "$@"
