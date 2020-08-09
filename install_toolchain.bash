#!/bin/bash -eu

# ****************************************************************************
# DESCRIPTION
#   Bash script to locally install my prefered working setup
#   including Python3, Go, Rust, Original-Vi and Nvim (and additionally
#   some tools like ansible and fzf). Probably this is not useful for any
#   any other person than me.
# ****************************************************************************

# bugs and hints: lrsklemstein@gmail.com


# ----------------------------------------------------------------------------
# declarations
# ----------------------------------------------------------------------------

readonly PROG=${0##*/}

readonly INST_DIR=$HOME/local_env
export PATH=$INST_DIR/bin:$PATH


# readonly SRC_PYTHON3=https://www.python.org/ftp/python/3.8.5/Python-3.8.5.tar.xz
readonly SRC_PYTHON3=  # <--  download newsest verstion instead

# readonly SRC_GO=https://golang.org/dl/go1.14.6.linux-amd64.tar.gz
readonly SRC_GO=  # <--  download newsest verstion instead

# readonly SRC_NODE=https://nodejs.org/dist/v12.18.3/node-v12.18.3-linux-x64.tar.xz
readonly SRC_NODE=

readonly BUILD_DIR="$PWD/${PROG%.*}_build_dir"
readonly DOWNLOAD_DIR="$BUILD_DIR/download"


readonly INSTALL_PYTHON3=y
readonly INSTALL_PYTHON3_MODULES=y

readonly INSTALL_GO=y

readonly INSTALL_NODE=y

readonly INSTALL_RUST=n

readonly INSTALL_NVIM=y
readonly NVIM_RELEASE=0.4



# ----------------------------------------------------------------------------
# functions
# ----------------------------------------------------------------------------

msg() {
/bin/cat >&2 << EOF

******************************************************************************
$*
******************************************************************************

EOF
}

abort() {
    echo "$*" >&2
    exit 1
}

wget_if_not_there() {
    local url="$1"

    local file="$DOWNLOAD_DIR/${url##*/}"

    test -s "$file" || wget $url -O "$file"
}

extract_arch_from_url() {
    local url="$1"

    local archive="$DOWNLOAD_DIR/${url##*/}"
    local src_dir=""

    case $archive in
        *.tar.xz)
            src_dir=$(tar tJf $archive |head -1 |tr -d '/')
            tar xJf $archive -C "$DOWNLOAD_DIR"
            ;;
        *.tar.gz|*.tgz)
            src_dir=$(tar tzf $archive |head -1 |tr -d '/')
            tar xzf $archive -C "$DOWNLOAD_DIR"
            ;;
    esac

    echo "$DOWNLOAD_DIR/$src_dir"
}

cd_to_extracted_dir_from_url() {
    local url="$1"

    src_dir=$(extract_arch_from_url "$url")

    if [ -z "$src_dir" ]
    then
        abort "unable to handle archive \"$archive\""
    fi

    cd "$src_dir"
}

strip_binaries_in() {
    local dir="$1"

    for binary in $(file $dir/* |\
        awk '/not stripped/ {prog=$1; sub(/:/, "", prog); print prog}')
    do
        strip $binary
    done
}

# ----------------------------------------------------------------------------
# main
# ----------------------------------------------------------------------------


[ -d "$INST_DIR" ]      || mkdir -p "$INST_DIR"
[ -d "$BUILD_DIR" ]     || mkdir -p "$BUILD_DIR"
[ -d "$DOWNLOAD_DIR" ]  || mkdir -p "$DOWNLOAD_DIR"


# ****************************************************************************
# Python3
# ****************************************************************************

if [ "$INSTALL_PYTHON3" = "y" ]
then
    cd $BUILD_DIR

    msg "donwload and extract Python3..."

    pysite='https://www.python.org'

    if [ -n "$SRC_PYTHON3" ]
    then
        python_download_url="$SRC_PYTHON3"
    else
        python3_latest=$(wget -qO- "${pysite}/downloads/source/" | \
            grep 'Latest Python 3 Release' | \
            sed -e 's/.*Python *//' -e 's/<.*//')

        python_download_url="${pysite}/ftp/python/${python3_latest}/"
        python_download_url+="Python-${python3_latest}.tar.xz"
    fi

    wget_if_not_there $python_download_url
    cd_to_extracted_dir_from_url $python_download_url

    msg "configure Python..."
    ./configure --prefix=$INST_DIR --enable-optimizations

    msg "make and install Python3..."

    make
    make install

    msg "check if installation is complete"

    python_modules_to_check=(
        ssl
        bz2
    )

    for python_module_to_check in ${python_modules_to_check[@]}
    do
        python3 -m $python_module_to_check
    done

    # why not?
    msg "upgrade Python3 pip"
    pip3 install --upgrade pip


    if [ "$INSTALL_PYTHON3_MODULES" = "y" ]
    then
        msg "Install Python3 modules..."

        python_module_list=(
            ansible
            jedi                # needed for Vim/Nvim coc
            pudb                # Turbo IDE like python debugger
            pylint
            pyls                # Python language server
            pytest
            ranger-fm           # Terminal based file manager
            virtualenv
            youtube-dl
        )

        for python_module in ${python_module_list[@]}
        do
            msg "  -> intall Python module $python_module..."
            pip3 install $python_module
        done
    else
        msg "Install *no* Python3 modules"
    fi
else
    msg "skipped Python3 installation"
fi


# ****************************************************************************
# Go
# ****************************************************************************

if [ "$INSTALL_GO" = "y" ]
then
    msg "Installing Go..."

    export GOPATH=$INST_DIR/go

    if [ ! -d "$GOPATH" ]
    then
        mkdir -vp $GOPATH/{bin,src,pkg}
    fi

    if [ -n "$SRC_GO" ]
    then
        go_download_url="$SRC_GO"
    else
        go_download_url=$(wget -qO- https://golang.org/dl/ | \
            grep linux-amd64 | head -1 |sed -e 's/.*href="//'  -e 's/".*//')
        go_download_url="https://golang.org${go_download_url}"
    fi

    go_name="${go_download_url##*/}"
    go_name="${go_name%%.linux-amd64*}"

    msg "Go download URL is $go_download_url; download and extract..."

    wget_if_not_there "$go_download_url"
    go_dir=$(extract_arch_from_url "$go_download_url")

    [ -n "$go_dir" ] || \
        abort "unable to extract go_dir from URL $go_download_url"

    msg "Go distribution dir from downloaded archive is \"$go_dir\""

    go_inst_dir=$INST_DIR/opt
    [ -d "$go_inst_dir" ] || mkdir -p "$go_inst_dir"

    go_dest_dir="$go_inst_dir/$go_name"

    if [ ! -d "$go_dest_dir" ]
    then
        /bin/mv $go_dir $go_dest_dir
        cd $go_inst_dir

        /bin/ln -fs $go_name go
        msg "Created go symlink in $go_inst_dir"
    fi

    export PATH=$INST_DIR/opt/go/bin:$PATH

    msg "Installing Go based programs..."

    go_program_url_list=(
    "github.com/wallix/awless"
        "github.com/junegunn/fzf"
    )

    for go_program_url in "${go_program_url_list[$@]}"
    do
        go_program_name="${go_program_url##*/}"
        msg "  -> $go_program_name from $go_program_url"

        go get     $go_program_url
        go install $go_program_url
    done

    strip_binaries_in $INST_DIR/opt/go/bin
    strip_binaries_in $INST_DIR/go/bin

else
    msg "skipped Go"
fi


# ----------------------------------------------------------------------------
# Node LTS (needed for Nvim-Coc LSP)
# ----------------------------------------------------------------------------

if  [ "$INSTALL_NODE" = "y" ]
then
    msg "Installing Node..."

    node_site="https://nodejs.org/en/download"

    if [ -n "$SRC_NODE" ]
    then
        node_download_url=$SRC_NODE
    else
        node_download_url=$(wget -qO- "${node_site}" \
		| sed -ne 's!.*href="\(https://.*-linux-x64\.tar\.xz\).*!\1!p' \
		| head -1)
	fi

    msg "Node download URL is $node_download_url; download and extract..."

    wget_if_not_there $node_download_url
    node_dir=$(extract_arch_from_url "$node_download_url")

	echo "node dir: $node_dir"

	node_inst_dir=$INST_DIR/opt
	[ -d "$node_inst_dir" ] || mkdir -p $node_inst_dir

	/bin/mv -v $node_dir $node_inst_dir
	cd $node_inst_dir

	/bin/ln -sf ${node_dir##*/} node
else
    msg "skipped Node"
fi


# ----------------------------------------------------------------------------
# Rust
# ----------------------------------------------------------------------------

if [ "$INSTALL_RUST" = "y" ]
then
    msg "Installing Rust..."

    rustup_prog="$HOME/.cargo/bin/rustup"

    if [ -f "$rustup_prog" ]
    then
        $rustup_prog update
    else
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |sh -s -- -y
    fi

    strip_binaries_in $HOME/.cargo/bin

else
    msg "skipped Rust"
fi


# ----------------------------------------------------------------------------
# Neovim
# ----------------------------------------------------------------------------

if [ "$INSTALL_NVIM" = "y" ]
then
    msg "Install Neovim..."

    cd $BUILD_DIR

    nvim_git_url=https://github.com/neovim/neovim.git

    git clone $nvim_git_url --branch release-${NVIM_RELEASE:-0.4} \
        --single-branch nvim

    cd nvim

	make_out=nvim_make.out

	declare -a failed_pair_list

	while :
	do
		make CMAKE_INSTALL_PREFIX=$INST_DIR CMAKE_BUILD_TYPE=RelWithDebInfo 2>&1 \
			| tee $make_out

		# ugly hack for WSL (at least...)
		#
		failed_pair=$(tail -50 $make_out \
			| perl -0777 -e 'my $f = <>; if ($f =~m{failed to rename\s+(\S+)\s+to\s+(\S+)\s+because: Permission denied}) { my ($f, $t) = ($1, $2);  print  "$f:$t\n";}')

		if [ -z "$failed_pair" ]
		then

			# !!!
			# TODO: check make file for other errors
			# !!!

			break
		else
			if [[ "${failed_pair_list[@]}" =~ "$failed_pair" ]]
			then
				abort "error pair prodcuces twice: $failed_par"		
			else
				echo "found error pair the first time, try 1x again... ($failed_pair)"	
				failed_pair_list+=("$failed_pair")

				failed_from=${failed_pair%:*}
				failed_to=${failed_pair#*:}

				/bin/mv -v "$failed_from" "$failed_to"
			fi
		fi
	done

    test -f $HOME/.config/nvim/autoload/plug.vim && /bin/rm -vf $_
    test -d $HOME/.local/share/nvim && /bin/rm -rf $_

    make install

    if [ "$INSTALL_PYTHON3" = "y" ]
    then
        python_modules_needed_for_nvim=(
            pynvim
            neovim
        )
    
        for python_module in ${python_modules_needed_for_nvim[$@]}
        do
                pip3 install $python_module
        done
    fi
else
    msg "Skip installation of Neovim..."
fi


# ----------------------------------------------------------------------------
# Generate environment hints
# ----------------------------------------------------------------------------

strip_binaries_in $INST_DIR/bin

home_def="${INST_DIR/$HOME/\$HOME}"

msg "Add the following lines to your local profile:"

echo ""
echo "export LOCAL_ENV=$home_def"

local_env_path_list=(
    '$LOCAL_ENV/bin'
    '$LOCAL_ENV/opt/go/bin'
    '$LOCAL_ENV/opt/node/bin'
    '$LOCAL_ENV/go/bin'
)

path_export_line=
for local_env_path in ${local_env_path_list[$@]}
do
    path_export_line+=${path_export_line+$path_export_line:}$local_env_path
done

[ "$INSTALL_RUST" = "y" ] && path_export_line+=':$LOCAL_ENV/.cargo/bin'
path_export_line+=':$PATH'

echo $path_export_line

echo 'export MANPATH=${MANPATH+$MANPATH:}$LOCAL_ENV/share/man'

echo ""

msg "Done!"
exit 0


# ----------------------------------------------------------------------------
# Done?
# ----------------------------------------------------------------------------
