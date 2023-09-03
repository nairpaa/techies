# PudgeMailer

Crafting the perfect phishing campaign shouldn't feel like a maze. With PudgeMailer's automated solutions for mail server installations and gophish setups, you're equipped to hook your targets, Pudge-style.

## Requirements

What you should buy before starting a phishing project:
- Domain
- DNS Management (e.g. cloudflare)
- VPS with IP Public (e.g. vultr, ovh, upcloud)

Before starting, make sure the following programs are installed on your VPS:
- docker
- docker-compose
- certbot
- nc
- c

Make sure these ports are not in use:
- 443 or 80 (http/s)
- 3333 (gophish dashboard)
- 993 & 143 (imap/s)
- 587, 465 & 25 (smtp/s)

## Usage

### Installation

```bash
➜ sudo ./pudgemailer.sh -h

        Usage:
          pudgemailer.sh [-d domain] [-h] [-s http|https] [-m yes|no] [-g yes|no]

        Options:
          -d domain         Domain name
          -h                Help
          -s http|https     Use SSL (default: https)
          -m yes|no         Create a mail server (default: yes)
          -g yes|no         Create a gophish server (default: yes)
```

```bash
# gophish (https) + mail server
➜ sudo ./pudgemailer.sh -d example.com -s https -m yes -g yes

# gophish (http) + mail server
➜ sudo ./pudgemailer.sh -d example.com -s http -m yes -g yes

# gophish (https)
➜ sudo ./pudgemailer.sh -d example.com -s https -m no -g yes

# mail server
➜ sudo ./pudgemailer.sh -d example.com -m yes -g no
```

### Uninstallation


```bash
➜ sudo ./pudge_uninstaller.sh -h

        Usage:
          pudge_uninstaller.sh [-d domain] [-h] [-m yes|no] [-g yes|no] [-y 2023] [-a]

        Options:
          -d domain         Domain name
          -h                Help
          -m yes|no         Remove a mail server (default: no)
          -g yes|no         Create a gophish server (default: no)
          -y year           Year of directory (default: 2023)
          -a                Remove all mail or gopish servers
```

```bash 
# uninstall specific gophish server
➜ sudo ./pudge_uninstaller.sh -d example.com -g yes

# uninstall specific mail server
➜ sudo ./pudge_uninstaller.sh -d example.com -m yes

# uninstall specific gophish and mail server
➜ sudo ./pudge_uninstaller.sh -d example.com -m yes -g yes

# uninstall all gophish and mail server
➜ sudo ./pudge_uninstaller.sh -m yes -g yes -a

# uninstall all gophish and mail server with specific year
➜ sudo ./pudge_uninstaller.sh -m yes -g yes -y 2022 -a
```