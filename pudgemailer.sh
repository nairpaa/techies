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
  _____           _            __  __       _ _           
 |  __ \         | |          |  \/  |     (_) |          
 | |__) |   _  __| | __ _  ___| \  / | __ _ _| | ___ _ __ 
 |  ___/ | | |/ _\` |/ _\` |/ _ \ |\/| |/ _\` | | |/ _ \ '__|
 | |   | |_| | (_| | (_| |  __/ |  | | (_| | | |  __/ |   
 |_|    \__,_|\__,_|\__, |\___|_|  |_|\__,_|_|_|\___|_|   
                     __/ |                                
                    |___/                                 

 Mail Server & Gopish Installation v2.0"

    echo -e "\\n\\e[33m[!]\\e[0m Before starting the mail server installation, make sure the DNS records are set as follows:"
    echo -e "> \\e[36m A   - @       - 141.95.xx.xx\\e[0m"
    if [[ $mail_server == "yes" ]]; then
        echo -e "> \\e[36m A   - mail    - 141.95.xx.xx\\e[0m"
        echo -e "> \\e[36m MX  - @       - mail.$domain\\e[0m"
        echo -e "> \\e[36m TXT - @       - v=spf1 mx -all\\e[0m"
        echo -e "> \\e[36m TXT - _dmarc  - v=DMARC1; p=reject; sp=quarantine\\e[0m"
    fi

    echo -e "\\n[Type any key to continue]"
    read -s 
}

# Display help message
display_help() {
    echo -e "\\n\
        Usage:\\n\
          pudgemailer.sh [-d domain] [-h] [-s http|https] [-m yes|no] [-g yes|no]\\n\\n\
        Options:\\n\
          -d domain         Domain name\\n\
          -h                Help\\n\
          -s http|https     Use SSL (default: https)\\n\
          -m yes|no         Create a mail server (default: yes)\\n\
          -g yes|no         Create a gophish server (default: yes)\\n\
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
    if [[ $gophish_server == "yes" ]]; then
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

create_directory() {
    local dir_name="$2-$1"
    local domain="$3"
    echo -e "\\e[32m[+]\\e[0m Creating $domain directory for $1 server."
    if [ -d $dir_name/$domain ]; then
        echo -e "\\e[31m[-]\\e[0m $domain directory already exists."
        exit 1
    else 
        mkdir -p $dir_name/$domain
    fi
}

download_files() {
    local dir_name="$2-$1"
    local domain="$3"
    local base_url="$4"
    shift 4
    local files=("$@")
    echo -e "\\e[32m[+]\\e[0m Downloading configuration files."
    for file in "${files[@]}"; do
        curl "$base_url/$file" -o $dir_name/$domain/$file -s
        if [ ! -f "$dir_name/$domain/$file" ]; then
            echo -e "\\e[31m[-]\\e[0m $file failed to download."
            exit 1
        fi
    done
    echo -e "\\e[32m[+]\\e[0m Files downloaded successfully."
}

mail_server_installation() {
    local mail_dir="$year-mail"
    create_directory "mail" "$year" "$domain"
    download_files "mail" "$year" "$domain" "https://raw.githubusercontent.com/docker-mailserver/docker-mailserver/d2a0a5de2ed450bb13c01ca08ef4130da68fba3a" "docker-compose.yml" "mailserver.env" "setup.sh"
    
    # Configure mail server
    echo -e "\e[32m[+]\e[0m Configuring mail server."
    sed -i '1 i\version: "3"' $mail_dir/$domain/docker-compose.yml
    sed -i 's/container_name: mailserver/container_name: '"$domain"-mailserver'/g' $mail_dir/$domain/docker-compose.yml
    sed -i 's/domainname: example.com/domainname: '"$domain"'/g' $mail_dir/$domain/docker-compose.yml
    export volume_localtime="/etc/localtime:/etc/localtime:ro"
    export volume_letsencrypt="/etc/letsencrypt:/etc/letsencrypt"
    sed -i "s@$volume_localtime@$volume_localtime \n      - $volume_letsencrypt@g" $mail_dir/$domain/docker-compose.yml
    sed -i 's/^SSL_TYPE=/SSL_TYPE=letsencrypt/' $mail_dir/$domain/mailserver.env

    echo -e "\e[32m[+]\e[0m Generating letsencrypt certificate."
    echo -e "\e[33m[!]\e[0m Don't forget to configure acme-challange:"
    echo ""
    certbot certonly -d $domain -d mail.$domain --manual --preferred-challenges dns

    echo -e -n "\e[34m>\e[0m"
    read -p " Please input admin@$domain password: " password

    bash $mail_dir/$domain/setup.sh email add admin@$domain $password 

    echo -e "\e[32m[+]\e[0m Run the mail server."
    cd $mail_dir/$domain && docker-compose up -d > /dev/null 2>&1
    sleep 10 
    docker exec -u 0 -it $domain-mailserver bash -c 'printf "\ndefault_destination_rate_delay = 2s\n" >> /etc/postfix/main.cf' # 2s delay on every email send
    docker exec -u 0 -it $domain-mailserver bash -c 'postfix reload > /dev/null 2>&1'

    echo -e "\e[32m[+]\e[0m Generating DKIM."
    bash setup.sh config dkim domain $domain > /dev/null 2>&1

    echo -e "\e[33m[!]\e[0m Please add the following DNS records:"
    cat docker-data/dms/config/opendkim/keys/$domain/mail.txt

    cd ../../ # Back to 'root' directory
    echo -e "\e[32m[+]\e[0m Mail server installation was successful."

    if [[ $gophish_server == "yes" ]]; then
        echo ""
        echo "[Type any key to continue]"
        read -s 
        echo ""
    fi
}

gophish_installation() {
    create_directory "gophish" "$year" "$domain"

    echo -e "\e[32m[+]\e[0m Setting-up Gophish"
    if [[ $ssl == "https" ]]; then
        # Run gophish with https
        docker run -d -p 127.0.0.1:3333:3333 -p 443:443 --name $domain-gophish -v $(pwd)/static:/opt/gophish/static/endpoint -v $(pwd)/letsencrypt:/opt/gophish/letsencrypt gophish/gophish > /dev/null 2>&1
        
        # Configuring ssl
        echo -e "\e[32m[+]\e[0m Adding letsencrypt certificate."
        if [[ $mail_server == "no" ]]; then
            certbot certonly -d $domain --manual --preferred-challenges dns
        fi
        docker exec -it $domain-gophish sed -i "s/0.0.0.0:80/0.0.0.0:443/g" /opt/gophish/config.json  # Make gophish use ssl
        docker exec -it $domain-gophish sed -i "s/false/true/g" /opt/gophish/config.json # Make gophish use ssl
        export path_certadmin="/opt/gophish/letsencrypt/phishing"
        export path_certuser="/opt/gophish/letsencrypt/phishing"
        docker exec -it $domain-gophish sed -i "s@gophish_admin@$path_certadmin@g" /opt/gophish/config.json # setup ssl certificate
        docker exec -it $domain-gophish sed -i "s@example@$path_certadmin@g" /opt/gophish/config.json # setup ssl certificate
        cp /etc/letsencrypt/live/$domain/fullchain.pem ./letsencrypt/phishing.crt
        cp /etc/letsencrypt/live/$domain/privkey.pem ./letsencrypt/phishing.key
        docker exec -it -u 0 $domain-gophish chmod -R 777 /opt/gophish/letsencrypt/
    else
        # Run gophish with http
        docker run -d -p 127.0.0.1:3333:3333 -p 80:80 --name $domain-gophish -v $(pwd)/static:/opt/gophish/static/endpoint -v $(pwd)/letsencrypt:/opt/gophish/letsencrypt gophish/gophish > /dev/null 2>&1 
    fi
    
    # Restart gophish
    echo -e "\e[32m[+]\e[0m Restarting gophish."
    docker stop $domain-gophish > /dev/null 2>&1
    docker start $domain-gophish > /dev/null 2>&1
    sleep 10 # wait for new credentials to appear in the log

    echo -e "\e[32m[+]\e[0m Finish. Ready to go."

    # Print default password admin
    echo -e "\e[32m[+]\e[0m Please try logging in with the following credentials:"
    export password=$(sudo docker logs $domain-gophish 2>&1 | grep "Please login with the username admin and the password" | tail -1 | awk '{print $NF}' | sed 's/"//g')
    echo -e "\e[36mLink    : https://localhost:3333/\e[0m"
    echo -e "\e[36mUsername: admin\e[0m"
    echo -e "\e[36mPassword: $password\e[0m"
}

main() {
    # Initialize variables
    ssl="https"
    mail_server="yes"
    gophish_server="yes"
    year=$(date +%Y)  # Get the current year

    # Get parameters
    while getopts 'd:hs:m:g:' opt; do
        case $opt in
            d)
                domain=$OPTARG
                ;;
            h)
                display_help
                exit 0
                ;;
            s)
                ssl=$OPTARG
                validate_parameters "$ssl" "-s" "http" "https"
                ;;
            m)
                mail_server=$OPTARG
                validate_parameters "$mail_server" "-m" "yes" "no"
                ;;
            g)
                gophish_server=$OPTARG
                validate_parameters "$gophish_server" "-g" "yes" "no"
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

    # Check if mail server or gophish server will be installed
    if [[ $mail_server == "no" && $gophish_server == "no" ]]; then
        echo -e "\e[31m[-]\e[0m There is no program to run."
        display_help
        exit 0;
    fi

    # Execute the functions
    print_banner
    check_programs
    check_ports

    if [[ $mail_server == "yes" ]]; then
        mail_server_installation
    fi

    if [[ $gophish_server == "yes" ]]; then
        gophish_installation
    fi

}

# -------------------------- Script Execution --------------------------
check_root
main "$@"