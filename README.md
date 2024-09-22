# VegaSetup Script

Welcome to the VegaSetup script! This script simplifies the process of setting up a new user on your server, including configuring SSH access and disabling password authentication.

This script is meant to be used with the Vega Template Image (coming soon)

## Features

- Guides you through setting up a new user and SSH key
- Creates a new user and adds them to the sudo group.
- Configures SSH settings for enhanced security.
- Updates the system packages if desired.

## Usage

To download and run the setup script, execute the following one-liner in your terminal:

```bash
bash <(curl -s https://raw.githubusercontent.com/BoredKevin/VegaSetup/main/setup.sh)
```

## License

This work is licensed under the GNU General Public License v3.0