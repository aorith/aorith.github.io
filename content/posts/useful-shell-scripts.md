---
title: "Useful Shell Scripts"
date: "2023-11-03T19:03:12+01:00"
draft: false
tags:
  - shell
---

The first thing that I do when I turn on my PC is to launch a terminal emulator and a tmux session. I live in the command line, surrounded by CLI tools and [neovim](https://neovim.io/).
Over the years, I've crafted a bunch of shell scripts to help in my daily workflows and decided to write a short post to share some of them.

All my custom scripts begin with a comma (`,`), a handy trick I adopted for quick access. By typing `,<TAB>` in the terminal, auto-completion instantly lists all of them, ensuring they don't get mixed up with other executables present in `$PATH`. Note that these scripts aren't POSIX compliant; I use them exclusively on my machines which have recent versions of bash.

## Random Password Generator

If you're anything like me, you frequently need to churn out random passwords, tokens, or arbitrary strings. While graphical tools and online generators exist, I've always preferred the speed and convenience of the terminal. Typing `,randompassword` and copying its output is pretty fast, you can also choose the length of the string by passing it as the first argument:

```shell
$ ,randompassword 10
F541LkLsjj
```

The script makes use of two sources of entropy, `/dev/urandom` and `openssl rand`. By default I don't use a big character set, only `A-Z-a-z-0-9-_.`, however it can be changed easily in the script by modifying the arguments of `tr`. Here's the script:

```shell
#!/usr/bin/env bash

randompassword() {
    local seed1 seed2 size
    size=${1:-18}
    seed1=$(tr -dc 'A-Z-a-z-0-9-_.' </dev/urandom | head -c "$((size * 2))")
    seed2=$(openssl rand -base64 "$((size * 2))" | tr -dc 'A-Z-a-z-0-9-_.')
    printf '%s\n\n' "$(fold -w1 <<<"${seed1}${seed2}${RANDOM}" | shuf | tr -d '\n' | head -c "$size")"
}

randompassword "$@"
```

However, When I need something more featureful, I use [KeePassXC](https://keepassxc.org/).

## SSL Certificate Chain Verification

Next script is a bit more complicated, I use it in order to quickly check the certificate chain of local certificates. It employs some `awk` wizardry to parse a certificate in PEM format.

Here's an example, I'll firstly download a certificate chain and then check it with the script, note that `openssl s_client -showcerts` already does a validation, to the best of my knowledge, there isn't an inbuilt command for local certificate chain validation:

```shell
$ echo | openssl s_client -showcerts -connect aorith.github.io:443 > /tmp/cert.crt
depth=2 C = US, O = DigiCert Inc, OU = www.digicert.com, CN = DigiCert Global Root CA
verify return:1
depth=1 C = US, O = DigiCert Inc, CN = DigiCert TLS RSA SHA256 2020 CA1
verify return:1
depth=0 C = US, ST = California, L = San Francisco, O = "GitHub, Inc.", CN = *.github.io
verify return:1
DONE

$ ,certs_check-cert-chain /tmp/cert.crt
 0: subject=C = US, ST = California, L = San Francisco, O = "GitHub, Inc.", CN = *.github.io
issuer=C = US, O = DigiCert Inc, CN = DigiCert TLS RSA SHA256 2020 CA1
 1: subject=C = US, O = DigiCert Inc, CN = DigiCert TLS RSA SHA256 2020 CA1
issuer=C = US, O = DigiCert Inc, OU = www.digicert.com, CN = DigiCert Global Root CA

openssl verify: /tmp/cert.crt: OK
```

Here's the full script:

```shell
#!/usr/bin/env bash

chain_pem="${1}"

if [[ ! -f "${chain_pem}" ]]; then
    echo "Usage: $0 BASE64_CERTIFICATE_CHAIN_FILE" >&2
    exit 1
fi

if ! openssl x509 -in "${chain_pem}" -noout 2>/dev/null; then
    echo "${chain_pem} is not a certificate" >&2
    exit 1
fi

awk -F'\n' '
        BEGIN {
            showcert = "openssl x509 -noout -subject -issuer"
            append=0
        }

        /-----BEGIN CERTIFICATE-----/ {
            printf "%2d: ", count
            append=1
        }

        {
            if (append == "1") {
                cert=cert "\n" $0
            }
        }

        /-----END CERTIFICATE-----/ {
            append=0
            printf "%s\n", cert | showcert
            close(showcert)
            cert=""
            count++
        }
    ' "${chain_pem}"

printf "\nopenssl verify: %s\n" "$(openssl verify -untrusted "${chain_pem}" "${chain_pem}")"
```

## Checking SSL Certificate Information and Expiry Date

When I need to verify the installed certificate of a domain, I use the following two commands:

1. To retrieve the certificate's complete information:

```shell
echo -n | openssl s_client -servername $domain -connect $domain:443 2>/dev/null
```

2. To extract only the certificate's validity dates:

```shell
echo -n | openssl s_client -servername $domain -connect $domain:443 2>/dev/null | openssl x509 -noout -dates
```

For convenience I use the following script which runs both commands:

```shell
#!/usr/bin/env bash

check_cert_for_domain() {
    local Remote
    [[ -n "$1" ]] || {
        echo "Usage: ${FUNCNAME[0]} <domain> [ip-address-to-connect-to]"
        return 1
    }
    [[ -n "$2" ]] && Remote="$2" || Remote="$1"
    echo -e "$(tput setaf 3)$ echo -n | openssl s_client -servername $1 -connect ${Remote}:443 2>/dev/null$(tput sgr0)"
    echo -n | openssl s_client -servername "${1}" -connect "${Remote}:443" 2>/dev/null
    echo -e "$(tput setaf 3)$ echo -n | openssl s_client -servername $1 -connect ${Remote}:443 2>/dev/null | openssl x509 -noout -dates$(tput sgr0)"
    echo -n | openssl s_client -servername "${1}" -connect "${Remote}:443" 2>/dev/null | openssl x509 -noout -dates
}

check_cert_for_domain "$@"
```

Here's an example against `aorith.github.io`:

```shell
$ ,certs_check-cert-for-domain aorith.github.io
```

The output will also print the individual openssl commands used:

```
$ echo -n | openssl s_client -servername aorith.github.io -connect aorith.github.io:443 2>/dev/null
CONNECTED(00000003)
---
Certificate chain
 0 s:C = US, ST = California, L = San Francisco, O = "GitHub, Inc.", CN = *.github.io
   i:C = US, O = DigiCert Inc, CN = DigiCert TLS RSA SHA256 2020 CA1
   a:PKEY: rsaEncryption, 2048 (bit); sigalg: RSA-SHA256
   v:NotBefore: Feb 21 00:00:00 2023 GMT; NotAfter: Mar 20 23:59:59 2024 GMT
 1 s:C = US, O = DigiCert Inc, CN = DigiCert TLS RSA SHA256 2020 CA1
   i:C = US, O = DigiCert Inc, OU = www.digicert.com, CN = DigiCert Global Root CA
   a:PKEY: rsaEncryption, 2048 (bit); sigalg: RSA-SHA256
   v:NotBefore: Apr 14 00:00:00 2021 GMT; NotAfter: Apr 13 23:59:59 2031 GMT

...
Verify return code: 0 (ok)
...
$ echo -n | openssl s_client -servername aorith.github.io -connect aorith.github.io:443 2>/dev/null | openssl x509 -noout -dates
notBefore=Feb 21 00:00:00 2023 GMT
notAfter=Mar 20 23:59:59 2024 GMT
```

## Parse Unix Timestamps

This little script parses UNIX timestamps and outputs the result as a JSON string. To convert a UNIX timestamp, simply call the script followed by the timestamp:

```shell
$ ,unixdate 1699935000
```

Output:

```json
[
  {
    "timestamp": 1699935000
  },
  {
    "tz": "Europe/Madrid",
    "date": "mar 14 nov 2023 05:10:00 CET"
  },
  {
    "tz": "UTC",
    "date": "mar 14 nov 2023 04:10:00 UTC"
  }
]
```

You can change the local timezone with the variable `MYTZ`:

```shell
$ MYTZ="America/Los_Angeles" ,unixdate 1699935000
```

Output:

```json
[
  {
    "timestamp": 1699935000
  },
  {
    "tz": "America/Los_Angeles",
    "date": "lun 13 nov 2023 20:10:00 PST"
  },
  {
    "tz": "UTC",
    "date": "mar 14 nov 2023 04:10:00 UTC"
  }
]
```

Here's the script:

```shell
#!/usr/bin/env bash

unixdate() {
    local EXE timestamp json count
    MYTZ="${MYTZ:-Europe/Madrid}"
    EXE='command date'
    command -v gdate >/dev/null 2>&1 && EXE='command gdate'

    timestamp="${1:-}"
    [[ -z $timestamp ]] && {
        echo -n "Unix timestamp: "
        read -r timestamp
    }

    json="[ { \"timestamp\": ${timestamp} } "
    count=0
    for _tz in "$MYTZ" "UTC" "${2:-}"; do
        [[ -n "$_tz" ]] || continue
        json="${json}, { \"tz\": \"${_tz}\", \"date\": \"$(TZ=${_tz} $EXE --date=@"${timestamp}")\" }"
        count=$((count + 1))
    done

    jq . <<<"${json} ]"
}

unixdate "$@"
```
