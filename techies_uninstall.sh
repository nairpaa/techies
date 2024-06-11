#!/bin/bash

# -------------------------- Function Definitions --------------------------
# Check if script is run as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then 
        echo -e "\\e[31m[-]\\e[0m Please run as root."
        exit
    fi
}

# Display help message
display_help() {
    echo -e "\\n\
        Usage:\\n\
          pudge_uninstaller.sh [-d domain] [-h] [-m yes|no] [-g yes|no] [-y 2023] [-a]\\n\\n\
        Options:\\n\
          -d domain         Domain name\\n\
          -h                Help\\n\
          -m yes|no         Remove a mail server (default: no)\\n\
          -g yes|no         Create a gophish server (default: no)\\n\
          -y year           Year of directory (default: $year_dir)\\n\
          -a                Remove all mail or gopish servers
      "
}

# Validate the input parameters
validate_parameters() {
    local value=$1
    local flag=$2
    shift
    shift
    local valid_values=("$@")

    # Convert the valid values array to the desired string format
    local formatted_values=$(printf "'%s' or " "${valid_values[@]}" | sed 's/ or $//')

    if [[ ! " ${valid_values[@]} " =~ " ${value} " ]]; then
        echo -e "\e[31m[-]\e[0m The ${flag} parameter must be ${formatted_values[@]}."
        display_help
        exit 1
    fi
}

server_uninstallation() {
    local server_type="$1"
    local base_dir="$year_dir-$server_type"
    local docker_name="$2"
    local server_domains=($(ls $base_dir))

    if [[ $all_server == "no" ]]; then
        echo -e "\\e[32m[+]\\e[0m Removing $domain $server_type server directory."
        rm -rf $base_dir/$domain

        echo -e "\\e[32m[+]\\e[0m Removing $domain $server_type server docker."
        docker stop $domain-$docker_name > /dev/null 2>&1
        docker rm $domain-$docker_name > /dev/null 2>&1
    else 
        echo -e "\\e[32m[+]\\e[0m Removing the $server_type server base directory."
        rm -rf $base_dir

        for domain in "${server_domains[@]}"; do
            echo -e "\\e[32m[+]\\e[0m Removing $domain $server_type server docker."
            docker stop $domain-$docker_name > /dev/null 2>&1
            docker rm $domain-$docker_name > /dev/null 2>&1
        done
    fi
}

mail_server_uninstallation() {
    server_uninstallation "mail" "mailserver"
}

gophish_uninstallation() {
    server_uninstallation "gophish" "gophish"
}

main() {
    # Initialize variables
    mail_server="no"
    gophish_server="no"
    year_dir=$(date +%Y)
    all_server="no"

    # Get parameters
    while getopts 'd:hs:m:g:y:a' opt; do
        case $opt in
            d)
                domain=$OPTARG
                ;;
            h)
                display_help
                exit 0
                ;;
            m)
                mail_server=$OPTARG
                validate_parameters "$mail_server" "-m" "yes" "no"
                ;;
            g)
                gophish_server=$OPTARG
                validate_parameters "$gophish_server" "-g" "yes" "no"
                ;;
            y)
                year_dir=$OPTARG
                ;;
            a)
                all_server="yes"
                ;;
            *)
                echo "Unknown option: $opt"
                exit 1
                ;;
        esac
    done

    # Check if the -d parameter exists if only want to uninstall specific domain server
    if [[ -z $domain && $all_server == "no" ]]; then
        echo -e "\\e[31m[-]\\e[0m The -d parameter is required."
        display_help
        exit 1
    fi

    # Check if mail server or gophish server will be installed
    if [[ $mail_server == "no" && $gophish_server == "no" ]]; then
        echo -e "\e[31m[-]\e[0m There is no program to run."
        display_help
        exit 0;
    fi

    # Execute the functions
    if [[ $mail_server == "yes" ]]; then
        mail_server_uninstallation
    fi

    if [[ $gophish_server == "yes" ]]; then
        gophish_uninstallation
    fi
}

# -------------------------- Script Execution --------------------------
check_root
main "$@"