+++
title = "blocking ips with nftables"
date = "2026-01-18"
taxonomies.tags = [ "networking", "nixos" ]
+++

Internet is plagued with bots searching for security vulnerabilities, often this involves running a port scan of some sort to
discover services on remote hosts. I run a small VPS to host some services and while most of them are only listening on the
wireguard interface I wanted a system that automatically blocked such port scans.

In the process I also wanted to switch the system to fully utilize [nftables](https://netfilter.org/projects/nftables/) and learn about it along the way.

## logging connection attempts to suspicious ports

I thought about setting a rule that would log all connection attempts to ports where I don't even have any service listening on.
This was pretty straightforward with nftables:

```
tcp dport { 22, 3306 } log prefix "PORTMON: "
```

After applying the rule I could see some connection attempts:

```sh
$ journalctl -k | grep PORTMON: | tail -1
Jan 18 19:04:26 arcadia kernel: PORTMON: IN=enp1s0 OUT= MAC=96:00:03:06:75:d1:d2:74:7f:6e:37:e3:08:00 SRC=X.X.X.X DST=Y.Y.Y.Y LEN=40 TOS=0x00 PREC=0x00 TTL=247 ID=54321 PROTO=TCP SPT=33064 DPT=22 WINDOW=65535 RES=0x00 SYN URGP=0
```

My idea was to immediately block all the offending IPs so the rule didn't have any rate limiting to avoid flooding the logs.

### blocking with fail2ban

Since I already have [fail2ban](https://github.com/fail2ban/fail2ban) running on the server I setup some simple rules to block all IPs as soon as they were logged.

To enable it, I created the following jail configuration:

```ini
[portmon]
enabled = true
action = nftables-allports
         ntfy
backend = systemd
journalmatch = _TRANSPORT=kernel
filter = portmon
maxretry = 1
```

And the following filter:

```ini
# /etc/fail2ban/filter.d/portmon.conf
[Definition]
failregex = ^.*PORTMON: .* SRC=<ADDR>.* DST=.*$
```

The `nfty` action sends a request to [nfty](https://ntfy.sh/) topic which, to be honest, I never check.

This system worked fine but I wanted to try blocking them using only nftables rules.

## blocking directly with nftables

This is pretty simple to configure although a bit less flexible that using fail2ban since we cannot increase the ban time for recurring offenders or send notifications upon a new ban (which, tbh would be fairly easy to automate).

To do it I just created a new table with a chain that has a lower priority than the regular filter chain and a set to store the IPs:

```
table inet portmon {
  set whitelist4 {
    type ipv4_addr
    flags interval # cidr ranges
    elements = { 127.0.0.1/24, 10.255.254.0/24, 172.17.0.0/16, 172.18.0.0/16 }
  }

  set ban4 {
    type ipv4_addr
    flags timeout
    timeout 8h
  }

  chain input {
      type filter hook input priority -10

      ip saddr @ban4 drop
      meta l4proto { tcp, udp } th dport { 22, 3306 } ip saddr != @whitelist4 add @ban4 { ip saddr } drop
  }
}
```

The whitelist is not really required but I guess that it does not hurt to avoid having myself blocked from the VPN address or something.

After running those rules for a couple of hours I can already see some offenders in the ip set:

```sh
$ sudo nft -j list ruleset | jq -r '.nftables[] | select(.set.name == "ban4") | .set.elem[].elem.val' | wc -l
53
```

## extra: nixos setup with nftables

My VPS currently runs nixos and it has some services that run on docker. Docker likes to [mess with iptables rules](https://docs.docker.com/engine/network/packet-filtering-firewalls/#prevent-docker-from-manipulating-firewall-rules) and its support for ntfables is not a 100% there yet, but it is usable.

In order to enable nftables I had to enable it (which automatically picks other nix configurations that setup ports, etc):

```nix
networking.nftables.enable = true;
```

And tell docker to use nftables:

```nix
virtualisation.docker.extraOptions = "--iptables=False --firewall-backend=nftables";
virtualisation.docker.extraPackages = [ pkgs.nftables ];
```

I also defined the new table using nix:

```nix
    networking.nftables = {
      enable = true;
      tables = {
        portmon = {
          name = "portmon";
          enable = true;
          family = "inet";
          content = ''
            set whitelist4 {
              type ipv4_addr
              flags interval # cidr ranges

[ ... ]
```

... aaand that's about it.
