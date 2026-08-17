#!/usr/bin/env bash
#
set -euo pipefail

declare -a NAME
declare -a SELECTED

PKG_MANAGER="pacman"

is_yay_installed() {
    command -v yay >/dev/null 2>&1
}

install_yay() {
    clear
    echo "yay is not installed on this system"
    read -rp "Do you want to install it? [Y/n]: " ans || true
    case "${ans,,}" in
        y|yes)
            echo
            echo "Ensuring base dependencies (git, base-devel) are installed"
            sudo pacman -S --needed --noconfirm git base-devel || {
                echo "Failed to install base dependencies"
                pause
                return 1
            }

            local build_dir
            build_dir=$(mktemp -d)
            echo
            echo "Cloning and building yay..."
            if git clone https://aur.archlinux.org/yay.git "$build_dir/yay" \
                && (cd "$build_dir/yay" && makepkg -si --noconfirm); then
                rm -rf "$build_dir"
                echo
                echo "yay installed successfully"
                pause
                return 0
            else
                rm -rf "$build_dir"
                echo
                echo "Failed to install yay"
                pause
                return 1
            fi
            ;;
        *)
            echo "yay installation cancelled"
            pause
            return 1
            ;;
    esac
}

toggle_pkg_manager() {
    if [[ "$PKG_MANAGER" == "pacman" ]]; then
        if ! is_yay_installed; then
            if install_yay; then
                PKG_MANAGER="yay"
            fi
        else
            PKG_MANAGER="yay"
        fi
    else
        PKG_MANAGER="pacman"
    fi
}

pkg_install() {
    if [[ "$PKG_MANAGER" == "yay" ]]; then
        yay -S --needed "$@"
    else
        sudo pacman -S --needed "$@"
    fi
}

pkg_update() {
    if [[ "$PKG_MANAGER" == "yay" ]]; then
        yay -Syu
    else
        sudo pacman -Syu
    fi
}

pkg_remove() {
    if [[ "$PKG_MANAGER" == "yay" ]]; then
        yay -Rns "$@"
    else
        sudo pacman -Rns "$@"
    fi
}

init_names() {
    # --- Web Browsers ---
    NAME[1]="firefox"
    NAME[2]="librewolf"
    NAME[3]="brave-bin"
    NAME[4]="chromium"
    NAME[5]="google-chrome"

    # --- Media Players & Viewers ---
    NAME[6]="vlc"
    NAME[7]="mpv"
    NAME[8]="qview"

    # --- Office & Document Viewers ---
    NAME[9]="okular"
    NAME[10]="onlyoffice-bin"
    NAME[11]="libreoffice-fresh"

    # --- Archive & Compression Tools ---
    NAME[12]="7zip"
    NAME[13]="peazip-qt-bin"

    # --- Downloaders & Network Tools ---
    NAME[14]="aria2"
    NAME[15]="yt-dlp"
    NAME[16]="freedownloadmanager"

    # --- Code & Text Editors ---
    NAME[17]="code"
    NAME[18]="neovim"
    NAME[19]="micro"

    # --- CLI File Managers, Search & Navigation Utilities ---
    NAME[20]="ripgrep"
    NAME[21]="fd"
    NAME[22]="fzf"
    NAME[23]="zoxide"
    NAME[24]="yazi"

    # --- Modern Terminal Substitutes & Utilities ---
    NAME[25]="bat"
    NAME[26]="eza"
    NAME[27]="tree"
    NAME[28]="tldr"
    NAME[29]="navi"
    NAME[30]="pacman-contrib"

    # --- System Monitoring, Power & Disk Analytics ---
    NAME[31]="btop"
    NAME[32]="duf"
    NAME[33]="dust"
    NAME[34]="powertop"

    # --- System Info & Benchmarking ---
    NAME[35]="fastfetch"
    NAME[36]="hyperfine"

    # --- Version Control (Git Tools) ---
    NAME[37]="git"
    NAME[38]="github-cli"
    NAME[39]="sourcegit-bin"

    # --- Build Systems & Automation ---
    NAME[40]="make"
    NAME[41]="cmake"
    NAME[42]="ninja"

    # --- Compilers & Binary Toolchains ---
    NAME[43]="gcc"
    NAME[44]="clang"
    NAME[45]="binutils"

    # --- Debuggers, Static Analysis & Memory Profilers ---
    NAME[46]="gdb"
    NAME[47]="lldb"
    NAME[48]="valgrind"
    NAME[49]="cppcheck"

    deselect_all_progs
}

prog_count() {
    echo "${#NAME[@]}"
}

deselect_all_progs() {
    local count
    count=$(prog_count)
    for ((i = 1; i <= count; i++)); do
        SELECTED[i]=0
    done
}

select_all_progs() {
    local count
    count=$(prog_count)
    for ((i = 1; i <= count; i++)); do
        SELECTED[i]=1
    done
}

toggle_single() {
    local idx="$1"
    if [[ "${SELECTED[$idx]}" -eq 1 ]]; then
        SELECTED[idx]=0
    else
        SELECTED[idx]=1
    fi
}

pause() {
    read -rp "Press [Enter] to continue..." _ || true
}

go_done() {
    echo
    echo "The operation is done."
    pause
}

multi_input_progs() {
    local choice="$1"
    local count
    count=$(prog_count)
    local invalid=""
    local tokens
    tokens="${choice//,/ }"

    for tok in $tokens; do
        local matched=0

        if [[ "$tok" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            local rangeStart="${BASH_REMATCH[1]}"
            local rangeEnd="${BASH_REMATCH[2]}"
            if (( rangeStart >= 1 && rangeEnd <= count && rangeStart <= rangeEnd )); then
                for ((n = rangeStart; n <= rangeEnd; n++)); do
                    toggle_single "$n"
                done
                matched=1
            fi
        elif [[ "$tok" =~ ^[0-9]+$ ]]; then
            if (( tok >= 1 && tok <= count )); then
                toggle_single "$tok"
                matched=1
            fi
        fi

        if [[ "$matched" -eq 0 ]]; then
            invalid="$invalid $tok"
        fi
    done

    if [[ -n "$invalid" ]]; then
        echo
        echo "Invalid or out-of-range input:$invalid"
        pause
    fi
}

run_programs() {
    clear
    local count
    count=$(prog_count)
    local to_install=()

    for ((i = 1; i <= count; i++)); do
        if [[ "${SELECTED[$i]}" -eq 1 ]]; then
            to_install+=("${NAME[$i]}")
        fi
    done

    if [[ ${#to_install[@]} -eq 0 ]]; then
        echo "No programs selected"
        pause
        return
    fi

    echo "Installing the following packages:"
    printf '    - %s\n' "${to_install[@]}"
    echo

    pkg_install "${to_install[@]}" || true
    go_done
    deselect_all_progs
}

update_menu() {
    clear
    echo "Checking available updates..."
    pkg_update || true
    go_done
    deselect_all_progs
}

remove_menu() {
    clear
    pacman -Qe || true
    echo
    echo "Type the exact package name(s) as shown above, separated by commas"
    echo "Type 0 to go back"
    read -rp "--> " choice || true

    [[ -z "${choice:-}" ]] && return
    [[ "$choice" == "0" ]] && return

    local tokens="${choice//,/ }"
    local to_remove=()
    for pkg in $tokens; do
        to_remove+=("$pkg")
    done

    if [[ ${#to_remove[@]} -gt 0 ]]; then
        echo
        echo "Removing the following packages:"
        printf '    - %s\n' "${to_remove[@]}"
        pkg_remove "${to_remove[@]}" || true
    fi

    go_done
    deselect_all_progs
}

more_prog() {
    clear

    if ! command -v fzf >/dev/null 2>&1; then
        echo "fzf is required for interactive search but is not installed"
        read -rp "Do you want to install fzf now? [Y/n]: " ans || true
        case "${ans,,}" in
            y|yes|"")
                if ! pkg_install "fzf"; then
                    echo "Failed to install fzf"
                    pause
                    return 1
                fi
                ;;
            *)
                echo "Search cancelled"
                pause
                return 0
                ;;
        esac
        clear
    fi

    local fzf_header="Press [TAB] for multi-select | Press [ENTER] to confirm"
    local selected_apps

    if [[ "$PKG_MANAGER" == "yay" ]]; then
        selected_apps=$(yay -Slq | fzf -m --prompt="Search Package > " --header="$fzf_header" || true)
    else
        selected_apps=$(pacman -Slq | fzf -m --prompt="Search Package > " --header="$fzf_header" || true)
    fi

    [[ -z "${selected_apps:-}" ]] && return 0

    local to_install=()
    readarray -t to_install <<< "$selected_apps"

    echo
    echo "Installing selected package(s):"
    printf '    - %s\n' "${to_install[@]}"
    echo

    pkg_install "${to_install[@]}" || true
    go_done
    deselect_all_progs
}

pacman_menu() {
    while true; do
        clear
        cat <<'EOF'

                                                \\!//
                                                (o o)
             -------------------------------oOOo-(_)-oOOo-------------------------------
EOF
        printf "                                       Package Manager: %s\n" "${PKG_MANAGER,,}"
        cat <<'EOF'
             ---------------------------------------------------------------------------

EOF
        local count
        count=$(prog_count)
        local rows=$(( (count + 2) / 3 ))
        [[ $rows -lt 1 ]] && rows=1

        for ((r = 1; r <= rows; r++)); do
            local c1=$r
            local c2=$((r + rows))
            local c3=$((r + rows * 2))
            local col1="" col2="" col3=""
            local mark

            if ((c1 <= count)); then
                mark=" "
                [[ "${SELECTED[$c1]}" -eq 1 ]] && mark="*"
                col1=$(printf "[%-2s] %-18s %s" "$c1" "${NAME[$c1]}" "$mark")
            fi
            if ((c2 <= count)); then
                mark=" "
                [[ "${SELECTED[$c2]}" -eq 1 ]] && mark="*"
                col2=$(printf "[%-2s] %-18s %s" "$c2" "${NAME[$c2]}" "$mark")
            fi
            if ((c3 <= count)); then
                mark=" "
                [[ "${SELECTED[$c3]}" -eq 1 ]] && mark="*"
                col3=$(printf "[%-2s] %-18s %s" "$c3" "${NAME[$c3]}" "$mark")
            fi
            printf "                 %-26s%-26s%-26s\n" "$col1" "$col2" "$col3"
        done

        cat <<'EOF'

   [U] Update Programs
   [R] Remove Programs
   [M] More
   [P] Toggle (pacman/yay)

             ---------------------------------------------------------------------------

                   [A] Select All             [D] Deselect All             [X] Exit

EOF
        echo "Tip: You can select multiple items, e.g. 1,3,5 or 1-5 or 1-3,7,10-12"
        echo
        read -rp "--> Select option(s) and press [S] to Start: " choice || true

        [[ -z "${choice:-}" ]] && continue

        case "${choice^^}" in
            X) exit 0 ;;
            S) run_programs ;;
            A) select_all_progs ;;
            D) deselect_all_progs ;;
            U) update_menu ;;
            R) remove_menu ;;
            M) more_prog ;;
            P) toggle_pkg_manager ;;
            *) multi_input_progs "$choice" ;;
        esac
    done
}

init_names
pacman_menu
