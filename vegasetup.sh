#!/bin/bash

# Do not change!
VERSION="1.2.1"

# Check for sudo privileges
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root or with sudo." 
    exit 1
fi

# Extract distribution name and version from /etc/os-release
if [ -f /etc/os-release ]; then
    DISTRO_NAME=$(grep -w "NAME" /etc/os-release | cut -d '"' -f 2)
    DISTRO_VERSION=$(grep -w "VERSION" /etc/os-release | cut -d '"' -f 2)
else
    DISTRO_NAME="Unknown"
    DISTRO_VERSION="Unknown"
fi

# Ascii art generated from patorjk.com using the Jerusalem font
# Jerusalem by Gedaliah Friedenberg - based on Standard by G. Chappell & Ian Chai
# Questions and comments regarding jerusalem.flf to gfrieden@nyx.cs.du.edu
# Modified for figlet 2.1 by Glenn Chappell 16 Dec 1993
# Date: 13 Feb 1994
echo
echo ' __     _______ ____    _    ____  _____ _____ _   _ ____'
echo '\ \   / | ____/ ___|  / \  / ___|| ____|_   _| | | |  _ \'
echo ' \ \ / /|  _|| |  _  / _ \ \___ \|  _|   | | | | | | |_) |'
echo '  \ V / | |__| |_| |/ ___ \ ___) | |___  | | | |_| |  __/'
echo '   \_/  |_____\____/_/   \_|____/|_____| |_|  \___/|_|'
echo
echo "Welcome to the VegaSetup Script Version $VERSION!"
echo "This script will guide you through the process of setting up your user and"
echo "public key, this script will automatically disable SSH password authentication."
#echo "The script will also disable the root user and setup command logging & journaling."
echo
echo "Running on $DISTRO_NAME $DISTRO_VERSION"
if [ -f "/etc/vega-version" ]; then
    echo -n "Installed from the Vega Template Image Version: "
    cat /etc/vega-version
fi
echo
# Check for a newer version
LATEST_VERSION=$(curl -s "https://raw.githubusercontent.com/BoredKevin/VegaSetup/main/version")
if [[ "$LATEST_VERSION" && "$LATEST_VERSION" != "$VERSION" ]]; then
    echo "######################################################################################"
    echo
    echo "A newer version ($LATEST_VERSION) of the script is available. You are currently using version $VERSION"
    echo "Get the latest version by running the following command:"
    echo
    echo "bash <(curl -s https://raw.githubusercontent.com/BoredKevin/VegaSetup/main/setup.sh)"
    echo
    echo "######################################################################################"
fi
echo Press CTRL+C or Command+C at anytime to exit
echo
# Prompt for hostname
read -p "Enter the new hostname (leave blank if unchanged): " NEW_HOSTNAME
NEW_HOSTNAME=${NEW_HOSTNAME:-$(hostname)}

# Prompt for username
read -p "Enter the new username: " USERNAME
if [[ -z "$USERNAME" ]]; then
    echo "Username cannot be empty. Aborting setup."
    exit 1
fi

# Prompt for public key
read -p "Enter the SSH public key for the user (leave blank if not provided): " PUBLIC_KEY

# Validate the public key if provided
if [[ -n "$PUBLIC_KEY" ]]; then
    if echo "$PUBLIC_KEY" | ssh-keygen -y -f /dev/stdin > /dev/null 2>&1; then
        echo "Public key is valid."
    else
        echo "Invalid public key format. Aborting setup."
        exit 1
    fi
else
    echo "No public key provided. Password authentication will remain enabled!"
    echo "WARNING! This is not recommended! Please abort this script and generate a public key instead!"
fi


# Prompt for password (silent)
read -sp "Enter the password for the new user: " PASSWORD
echo
if [[ -z "$PASSWORD" ]]; then
    echo "Password cannot be empty. Aborting setup."
    exit 1
fi

# Print values for confirmation
echo "Please confirm the following details:"
echo "################################################"
echo "Hostname: $NEW_HOSTNAME"
echo "Username: $USERNAME"
echo "Password: (redacted)"
echo "Public Key: ${PUBLIC_KEY:-No public key provided}"
echo "################################################"
read -p "Are these details correct? (Y/n): " confirm_choice
confirm_choice=${confirm_choice:-y}

if [[ ! "$confirm_choice" =~ ^[Yy]$ ]]; then
    echo "Aborting setup."
    exit 1
fi

# Ask if the user wants to update packages
read -p "Do you want to update the packages? (Y/n): " update_choice
update_choice=${update_choice:-y}

# Ask if the user wants to enable global command logging
echo "Do you want to enable command logging for all users? This will log every command executed in the shell for every user."
read -p "Enable command logging? (Y/n): " logging_choice
logging_choice=${logging_choice:-y}

# Ask if the user wants to disable the root user
echo "Do you want to disable the root user? This will prevent users from using sudo su - to enter the root account."
read -p "Disable root user? (Y/n): " disable_root_choice
disable_root_choice=${disable_root_choice:-n}

if [[ "$update_choice" =~ ^[Yy]$ ]]; then
    echo "Updating packages..."
    sudo apt update && sudo apt upgrade -y
else
    echo "Skipping package update."
fi

# Change the hostname
hostnamectl set-hostname "$NEW_HOSTNAME"

# Create new user and add to sudo group
adduser --gecos "" --disabled-password "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd
usermod -aG sudo "$USERNAME"

# Create .ssh directory for the new user if a public key is provided
if [[ -n "$PUBLIC_KEY" ]]; then
    mkdir -p /home/"$USERNAME"/.ssh
    chmod 700 /home/"$USERNAME"/.ssh

    # Add the public key to the authorized_keys file
    echo "$PUBLIC_KEY" > /home/"$USERNAME"/.ssh/authorized_keys
    chmod 600 /home/"$USERNAME"/.ssh/authorized_keys
    chown -R "$USERNAME":"$USERNAME" /home/"$USERNAME"/.ssh

    # Disable password authentication in SSH
    sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
    # Restart the SSH service to apply changes
    systemctl restart sshd
else
    echo "Warning: No public key provided. SSH password authentication will remain enabled."
fi

## Check if the user "vega" exists
#if [ -f "/etc/vega-version" ]; then
#    echo "You are using the Vega Image Template, deleting the default user and its home directory..."
#    # Delete the "vega" user and its home directory
#    userdel -f -r vega
#    if [ $? -eq 0 ]; then
#        echo "User 'vega' successfully deleted."
#    else
#        echo "Failed to delete the user 'vega'."
#    fi
#fi

if [[ "$logging_choice" =~ ^[Yy]$ ]]; then
    echo "Setting up command logging for all users..."

    # Create rsyslog configuration to log shell commands
    echo 'local6.* /var/log/commands.log' > /etc/rsyslog.d/bash.conf

    # Append logging configuration to /etc/bash.bashrc to affect all users
    GLOBAL_BASHRC="/etc/bash.bashrc"
    whoami_logging='whoami="$(whoami)@$(echo $SSH_CONNECTION | awk '\''{print $1}'\'')"'
    prompt_command='export PROMPT_COMMAND='\''RETRN_VAL=$?;logger -p local6.debug "$whoami [$$]: $(history 1 | sed '\''"s/^[ ]*[0-9]\+[ ]*//"'\'' ) [$RETRN_VAL]"'\'

    # Add logging config to the global bashrc
    if ! grep -q "logger -p local6.debug" "$GLOBAL_BASHRC"; then
        echo "$whoami_logging" >> "$GLOBAL_BASHRC"
        echo "$prompt_command" >> "$GLOBAL_BASHRC"
        echo "Global command logging enabled for all users."
    else
        echo "Command logging is already configured globally."
    fi

    # Restart rsyslog service to apply logging changes
    systemctl restart rsyslog
    echo "Command logging is now enabled for all users."
else
    echo "Skipping command logging setup."
fi

if [[ "$disable_root_choice" =~ ^[Yy]$ ]]; then
    echo "Disabling the root user..."
    # Logic to disable the root user goes here
    sed -i 's|^root:\(.*\):/bin/bash|root:\1:/sbin/nologin|' /etc/passwd
    echo "Root user has been disabled."
else
    echo "Skipping root user disable."
fi

# Replace the /etc/motd with the new message
cat <<EOL > /etc/motd
Welcome to $DISTRO_NAME $DISTRO_VERSION! This installation was set up using VegaSetup Version $VERSION

To remove this message, simply delete the /etc/motd file.
EOL

echo "User $USERNAME created with password, public key added (if provided), default user removed."
echo "You are now ready to use your new server! Login with the user $USERNAME and the set password."