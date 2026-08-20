#!/usr/bin/env bash

set -euo pipefail

declare -a NAME
declare -a DISPLAY
declare -a SELECTED

PKG_MANAGER="pacman"

is_yay_installed() {
    command -v yay >/dev/null 2>&1
}

install_yay() {
    clear
    echo "yay is not installed"
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
            echo
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

add_pkg() {
    local name="$1"
    local display="$2"
    local idx=$((${#NAME[@]} + 1))
    NAME[idx]="$name"
    DISPLAY[idx]="$display"
}

init_pkg() {
    NAME=()
    DISPLAY=()

    # Web Browsers
    add_pkg "firefox"             "Mozilla Firefox"
    add_pkg "librewolf"           "LibreWolf"
    add_pkg "brave-bin"           "Brave"
    add_pkg "chromium"            "Chromium"
    add_pkg "google-chrome"       "Google Chrome"

    # Multimedia
    add_pkg "vlc"                 "VLC media player"
    add_pkg "mpv"                 "mpv"
    add_pkg "gthumb"              "GThumb"
    add_pkg "viewnior"            "Viewnior"

    # Office
    add_pkg "okular"              "KDE Okular"
    add_pkg "onlyoffice-bin"      "OnlyOffice"
    add_pkg "libreoffice-fresh"   "LibreOffice"

    # Archive
    add_pkg "peazip"              "PeaZip"

    # Downloaders
    add_pkg "freedownloadmanager" "FDM"
    add_pkg "yt-dlp"              "yt-dlp"
    add_pkg "media-downloader"

    # CLI File Managers, Search & Navigation Utilities
    add_pkg "ripgrep"             "ripgrep"
    add_pkg "fd"                  "fd"
    add_pkg "fzf"                 "fzf"
    add_pkg "zoxide"              "zoxide"
    add_pkg "yazi"                "Yazi"
    add_pkg "bat"                 "bat"
    add_pkg "eza"                 "eza"
    add_pkg "tree"                "Tree"
    add_pkg "tldr"                "tldr"
    add_pkg "navi"                "navi"

    # System Monitoring, Power & Disk Analytics
    add_pkg "duf"                 "duf"
    add_pkg "dust"                "dust"
    add_pkg "btop"                "btop"
    add_pkg "fastfetch"           "Fastfetch"
    add_pkg "powertop"            "PowerTOP"
    add_pkg "pacman-contrib"      "pacman-contrib"

    # Text Editors
    add_pkg "code"                "VS Code"
    add_pkg "neovim"              "Neovim"
    add_pkg "micro"               "micro"

    # Git Tools
    add_pkg "git"                 "Git"
    add_pkg "github-cli"          "GitHub CLI"
    add_pkg "sourcegit-bin"       "SourceGit"

    # Deve Tools
    add_pkg "cmake"               "CMake"
    add_pkg "make"                "GNU Make"
    add_pkg "ninja"               "Ninja"
    add_pkg "base-devel"          "Base dev"
    add_pkg "clang"               "Clang"
    add_pkg "cppcheck"            "Cppcheck"
    add_pkg "hyperfine"           "hyperfine"

    deselect_all_pkg
}

pkg_count() {
    echo "${#NAME[@]}"
}

deselect_all_pkg() {
    local count
    count=$(pkg_count)
    for ((i = 1; i <= count; i++)); do
        SELECTED[i]=0
    done
}

select_all_pkg() {
    local count
    count=$(pkg_count)
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

multi_input_pkg() {
    local choice="$1"
    local count
    count=$(pkg_count)
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

run_pkg() {
    clear
    local count
    count=$(pkg_count)
    local to_install=()

    for ((i = 1; i <= count; i++)); do
        if [[ "${SELECTED[$i]}" -eq 1 ]]; then
            to_install+=("${NAME[$i]}")
        fi
    done

    if [[ ${#to_install[@]} -eq 0 ]]; then
        echo "No packages selected"
        pause
        return
    fi

    echo "Installing the following packages:"
    printf '    - %s\n' "${to_install[@]}"
    echo

    pkg_install "${to_install[@]}" || true
    go_done
    deselect_all_pkg
}

update_menu() {
    clear
    echo "Checking available updates..."
    pkg_update || true
    go_done
    deselect_all_pkg
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
    deselect_all_pkg
}

more_pkg() {
    clear

    if ! command -v fzf >/dev/null 2>&1; then
        echo "fzf is required for interactive search but is not installed"
        read -rp "Do you want to install fzf? [Y/n]: " ans || true
        case "${ans,,}" in
            y|yes|"")
                if ! pkg_install "fzf"; then
                    echo "Failed to install fzf"
                    pause
                    return 1
                fi
                ;;
            *)
                return 1
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
    deselect_all_pkg
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
        count=$(pkg_count)
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
                col1=$(printf "%s [%2s] %-18s" "$mark" "$c1" "${DISPLAY[$c1]}")
            fi
            if ((c2 <= count)); then
                mark=" "
                [[ "${SELECTED[$c2]}" -eq 1 ]] && mark="*"
                col2=$(printf "%s [%2s] %-18s" "$mark" "$c2" "${DISPLAY[$c2]}")
            fi
            if ((c3 <= count)); then
                mark=" "
                [[ "${SELECTED[$c3]}" -eq 1 ]] && mark="*"
                col3=$(printf "%s [%2s] %-18s" "$mark" "$c3" "${DISPLAY[$c3]}")
            fi
            printf "                 %-26s%-26s%-26s\n" "$col1" "$col2" "$col3"
        done

        cat <<'EOF'

   [U] Update Packages
   [R] Remove Packages
   [M] More
   [P] Toggle (pacman/yay)

             ---------------------------------------------------------------------------

                   [A] Select All            [D] Deselect All            [0] Exit

EOF
        echo "Tip: You can select multiple items, e.g. 1,3,5 or 1-5 or 1-3,7,10-12"
        echo
        read -rp "--> Select option(s) and press [S] to Start: " choice || true

        [[ -z "${choice:-}" ]] && continue

        case "${choice^^}" in
            0) exit 0 ;;
            S) run_pkg ;;
            A) select_all_pkg ;;
            D) deselect_all_pkg ;;
            U) update_menu ;;
            R) remove_menu ;;
            M) more_pkg ;;
            P) toggle_pkg_manager ;;
            *) multi_input_pkg "$choice" ;;
        esac
    done
}

init_pkg
pacman_menu
