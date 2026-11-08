# create-dotnet-devcert

A simple script that creates and trusts a local development CA and a localhost server certificate for .NET on Ubuntu, Arch, and Fedora based distributions.

## What does the script do

The script uses OpenSSL to create a persistent local CA and a separate server certificate for `localhost`. The CA is installed and trusted at:

- The system certificate store, for local applications and service-to-service communication
- Existing user NSS databases, including Chromium and Postman Snap databases when present

The server certificate is signed by the local CA and exported as a PFX for ASP.NET Core or Docker. The CA is kept between runs so newly generated server certificates remain trusted. The CA private key must remain private and must never be copied to a server or shared.

Generated files:

- CA certificate: `${XDG_DATA_HOME:-$HOME/.local/share}/dotnet-devcert/localhost-ca.crt`
- CA private key: `${XDG_DATA_HOME:-$HOME/.local/share}/dotnet-devcert/localhost-ca.key`
- Server PFX: `$HOME/.aspnet/https/localhost.pfx`
- Public server certificate: `$HOME/.aspnet/https/localhost.crt`

## Prerequisites

- dotnet-sdk (Version >= 5.0)
- openssl
- libnss3-tools
  - Ubuntu: `sudo apt install openssl libnss3-tools`
  - Arch: `sudo pacman -S openssl nss`
  - Fedora: `sudo dnf install openssl nss-tools`

## Usage

Simply run the script needed for your distribution.

Ubuntu based distributions:
`sh ./scripts/ubuntu-create-dotnet-devcert.sh`

Arch based distributions:
`sh ./scripts/arch-create-dotnet-devcert.sh`

Fedora based distributions:
`sh ./scripts/fedora-create-dotnet-devcert.sh`

Use `-s` to also copy the CA certificate, public server certificate, and PFX to your home directory for manual import or use. Do not copy or share the CA private key.

## More info

More information about this can be found on my blog post [https://blog.wille-zone.de/post/aspnetcore-devcert-for-ubuntu](https://blog.wille-zone.de/post/aspnetcore-devcert-for-ubuntu).
