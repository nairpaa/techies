#!/bin/bash

# -------------------------- Function Definitions --------------------------
# Check if script is run as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then 
        echo -e "\\e[31m[-]\\e[0m Please run as root."
        exit
    fi
}

print_banner() {
echo "
  _______        _     _           
 |__   __|      | |   (_)          
    | | ___  ___| |__  _  ___  ___ 
    | |/ _ \/ __| '_ \| |/ _ \/ __|
    | |  __/ (__| | | | |  __/\__ \\
    |_|\___|\___|_| |_|_|\___||___/

 Mail Server, Gopish and Evilginx3 Installation."

    echo -e "\\n\\e[33m[!]\\e[0m Before starting the installation, make sure the DNS records are set as follows:"
    if [[ $phishing_server == "yes" ]]; then
        if [[ $root_domain == "yes" ]]; then
            echo -e "> \\e[36m A   - @\t\t- 141.95.xx.xx\\e[0m"
        fi
        echo -e "> \\e[36m A   - $phishing_domain\t- 141.95.xx.xx\\e[0m"
    fi
    if [[ $mail_server == "yes" ]]; then
        echo -e "> \\e[36m A   - mail    \t- 141.95.xx.xx\\e[0m"
        echo -e "> \\e[36m MX  - @       \t- $phishing_domain.$domain\\e[0m"
        echo -e "> \\e[36m TXT - @       \t- v=spf1 mx -all\\e[0m"
        echo -e "> \\e[36m TXT - _dmarc  \t- v=DMARC1; p=reject; sp=quarantine\\e[0m"
    fi
    echo -e "\\e[32m Note: 141.95.xx.xx change with your IP.\\e[0m"

    echo -e "\\n[Type any key to continue]"
    read -s 
}

# Display help message
display_help() {
    echo -e "\\n\
        Usage:\\n\
          techies.sh [-d domain] [-h] [-m yes|no] [-p yes|no] [-x mail] [-z www]\\n\\n\
        Options:\\n\
          -d domain         Root domain name\\n\
          -h                Help\\n\
          -m yes|no         Create a mail server (default: yes)\\n\
          -p yes|no         Create a phishing server (default: yes)\\n\
          -x mailsubdomain  Subdomain for mail server\\n\
          -z phishsubdomain Subdomain for phishing\\n\
          -r yes|no         Use root domain for phishing (default: yes)      
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

# Check if the required program is installed
check_programs() {
    echo -e "\\e[32m[+]\\e[0m Checking if the required program is installed."

    programs=(docker certbot nc)

    # Add docker-compose if mail_server is set to "yes"
    [[ $mail_server == "yes" ]] && programs+=(docker-compose curl)

    for program in "${programs[@]}"; do
        if ! [ -x "$(command -v $program)" ]; then
            echo -e "\\e[31m[-]\\e[0m Error: $program is not installed."
            exit 1
        fi
    done
}

# Check if the required port is not used
check_ports() {
    echo -e "\\e[32m[+]\\e[0m Checking if the required port is not in use."

    ports=()

    # Set ports based on the mail server and gophish server settings
    [[ $mail_server == "yes" ]] && ports+=(25 465 143 587 993)
    if [[ $phishing_server == "yes" ]]; then
        ports+=(3333)
        ports+=($([[ $ssl == "https" ]] && echo 443 || echo 80))
    fi

    # Check each port
    for port in "${ports[@]}"; do
        if nc -z localhost "$port"; then
            echo -e "\\e[31m[-]\\e[0m Error: Port $port is open."
            exit 1
        fi
    done
}

mail_server_installation() {
    # Create mail directory
    local mail_dir="$project_dir/mail"
    echo -e "\e[32m[+]\\e[0m Creating directory for mail server."
    if [ -d $mail_dir ]; then
        echo -e "\\e[31m[-]\\e[0m $mail_dir directory already exists."
        exit 1
    else 
        mkdir -p $mail_dir
    fi
    
    # Download file docker-mailserver
    curl https://raw.githubusercontent.com/docker-mailserver/docker-mailserver/d2a0a5de2ed450bb13c01ca08ef4130da68fba3a/docker-compose.yml -o $mail_dir/docker-compose.yml -s
    curl https://raw.githubusercontent.com/docker-mailserver/docker-mailserver/d2a0a5de2ed450bb13c01ca08ef4130da68fba3a/mailserver.env -o $mail_dir/mailserver.env -s 
    curl https://raw.githubusercontent.com/docker-mailserver/docker-mailserver/d2a0a5de2ed450bb13c01ca08ef4130da68fba3a/mailserver.env -o $mail_dir/setup.sh -s

    # Configure mail server
    echo -e "\e[32m[+]\e[0m Configuring mail server."
    sed -i '1 i\version: "3"' $mail_dir/docker-compose.yml
    sed -i 's/container_name: mailserver/container_name: '"$domain"-mailserver'/g' $mail_dir/docker-compose.yml
    sed -i 's/domainname: example.com/domainname: '"$domain"'/g' $mail_dir/docker-compose.yml
    export volume_localtime="/etc/localtime:/etc/localtime:ro"
    export volume_letsencrypt="/etc/letsencrypt:/etc/letsencrypt"
    sed -i "s@$volume_localtime@$volume_localtime \n      - $volume_letsencrypt@g" $mail_dir/docker-compose.yml
    sed -i 's/^SSL_TYPE=/SSL_TYPE=letsencrypt/' $mail_dir/mailserver.env


}

generate_ssl_certificate() {
    echo -e "\e[32m[+]\e[0m Generating Let's Encrypt certificate."

    # Initialize an empty array to hold all domain configurations for the certificate
    declare -a cert_domains

    # Add the root domain if it's used
    if [[ $root_domain == "yes" ]]; then
        cert_domains+=("$domain")
    fi

    # Check if mail server is used and add the mail subdomain
    if [[ $mail_server == "yes" ]]; then
        cert_domains+=("$mail_subdomain.$domain")
    fi

    # Check if phishing server is used and add the phishing subdomain
    if [[ $phishing_server == "yes" ]]; then
        cert_domains+=("$phishing_domain.$domain")
    fi

    # Build the certbot command with all collected domains
    if [[ ${#cert_domains[@]} -gt 0 ]]; then
        local certbot_cmd="certbot certonly --standalone"
        for cert_domain in "${cert_domains[@]}"; do
            certbot_cmd+=" -d $cert_domain"
        done
        certbot_cmd+=" --preferred-challenges http -n --agree-tos --email youremail@example.com --cert-name $domain"
        echo -e "\e[34m[i]\e[0m Executing: $certbot_cmd"
        eval $certbot_cmd
    else
        echo -e "\e[31m[-]\e[0m No domains to certify."
    fi

    # Add admin user
    echo -e -n "\e[34m>\e[0m"
    read -p " Please input admin@$domain password: " password

    bash $mail_dir/setup.sh email add admin@$domain $password 

    # Run mail server
    echo -e "\e[32m[+]\e[0m Run the mail server."
    cd $mail_dir && docker-compose up -d > /dev/null 2>&1
    sleep 10 
    docker exec -u 0 -it $domain-mailserver bash -c 'printf "\ndefault_destination_rate_delay = 2s\n" >> /etc/postfix/main.cf' # 2s delay on every email send
    docker exec -u 0 -it $domain-mailserver bash -c 'postfix reload > /dev/null 2>&1'

    echo -e "\e[32m[+]\e[0m Generating DKIM."
    bash setup.sh config dkim domain $domain > /dev/null 2>&1

    echo -e "\e[33m[!]\e[0m Please add the following DNS records:"
    cat docker-data/dms/config/opendkim/keys/$domain/mail.txt

    cd ../../ # Back to 'root' directory
    echo -e "\e[32m[+]\e[0m Mail server installation was successful."

    if [[ $phishing_server == "yes" ]]; then
        echo ""
        echo "[Type any key to continue]"
        read -s 
        echo ""
    fi
}

main() {
    # Initialize variables
    mail_server="yes"
    phishing_server="yes"
    root_domain="yes"
    year=$(date +%Y)  # Get the current year

    # Get parameters
    while getopts 'd:hs:m:p:x:z:r:' opt; do
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
            p)
                phishing_server=$OPTARG
                validate_parameters "$phishing_server" "-p" "yes" "no"
                ;;
            x)
                mail_subdomain=$OPTARG
                ;;
            z)
                phishing_domain=$OPTARG
                ;;
            r)
                root_domain=$OPTARG
                validate_parameters "$root_domain" "-r" "yes" "no"
                ;;
            *)
                echo "Unknown option: $opt"
                exit 1
                ;;
        esac
    done

    # Check if the -d parameter exists
    if [[ -z $domain ]]; then
        echo -e "\\e[31m[-]\\e[0m The -d parameter is required."
        display_help
        exit 1
    fi

    # Check if mail server or phishing server will be installed
    if [[ $mail_server == "no" && $phishing_server == "no" ]]; then
        echo -e "\e[31m[-]\e[0m There is no program to run."
        display_help
        exit 0;
    fi

    # Check if subdomain exist if the root domain is not used
    if [[ $root_domain == "no" && -z $phishing_domain ]]; then
        echo -e "\e[31m[-]\e[0m There is no domain to run."
        display_help
        exit 0;
    fi

    # Execute the functions
    print_banner
    check_programs
    check_ports

    # Create project directory
    project_dir="$year/$domain"
    echo -e "\e[32m[+]\\e[0m Creating directory for $domain project."
    if [ -d $project_dir ]; then
        echo -e "\\e[31m[-]\\e[0m $domain directory already exists."
        exit 1
    else 
        mkdir -p $project_dir
    fi

    # Generate SSL let's encrypt
    generate_ssl_certificate

    # Run mail server instalation
    if [[ $mail_server == "yes" ]]; then
        mail_server_installation
    fi

}

# -------------------------- Script Execution --------------------------
check_root
main "$@"