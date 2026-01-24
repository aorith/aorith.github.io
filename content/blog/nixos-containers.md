+++
title = "nixos containers on foreign distros"
date = "2023-10-21"
taxonomies.tags = [ "systemd", "nix" ]
+++

NixOS offers native support for [systemd-nspawn](https://wiki.archlinux.org/title/Systemd-nspawn) containers, a powerful and simplified alternative to LXC.

[Systemd-nspawn](https://wiki.debian.org/nspawn) is like a supercharged [chroot](https://en.wikipedia.org/wiki/Chroot), harnessing the capabilities of the Linux kernel, using cgroups and namespaces to provide isolation within a container. This isolation covers:

- Full virtualisation of the file system hierarchy
- Management of the process tree
- IPC subsystems
- Restricted access to kernel interfaces
- Controlled network access

In essence, **nspawn** delivers most of the same features as Docker but without the client-server paradigm.

While working with systemd-nspawn containers on NixOS is remarkably smooth, I want to be able to deploy a NixOS nspawn container on any operating system.

## putting commands into actions

Build time!

```sh
$ nix build
$ tree result/
result/
├── nix-support
│   ├── hydra-build-products
│   └── system
└── tarball
    └── nixos-system-x86_64-linux.tar.xz

3 directories, 3 files

$ ls -lh result/tarball/nixos-system-x86_64-linux.tar.xz
-r--r--r--. 2 root root 108M ene  1  1970 result/tarball/nixos-system-x86_64-linux.tar.xz
```

Executing these commands generates a tarball containing the complete system. Now, let's import it using `machinectl`.

```sh
$ sudo machinectl import-tar result/tarball/nixos-system-x86_64-linux.tar.xz nginx-test
Enqueued transfer job 1. Press C-c to continue download in background.
Importing '/nix/store/33xxlds8d6cygwlqh427d1qswshdl2qk-tarball/tarball/nixos-system-x86_64-linux.tar.xz', saving as 'nginx-test'.
Imported 0%.
Imported 1%.
Imported 2%.

...

Imported 98%.
Imported 99%.
Operation completed successfully.
Exiting.

$ machinectl list-images
NAME        TYPE      RO  USAGE CREATED                      MODIFIED
nginx-test  subvolume no 259.3M Fri 2023-10-20 20:13:35 CEST -

1 images listed.
```

The machine has been successfully imported and is ready for use.

```sh
$ sudo machinectl start nginx-test
$ sudo machinectl status nginx-test
nginx-test(3d62c217182949a2b563238c2439ab23)
           Since: Fri 2023-10-20 20:16:23 CEST; 8s ago
          Leader: 402906 (systemd)
         Service: systemd-nspawn; class container
            Root: /var/lib/machines/nginx-test
           Iface: ve-nginx-test
              OS: NixOS 23.11 (Tapir)
       UID Shift: 576978944
            Unit: systemd-nspawn@nginx-test.service
                  ├─payload
                  │ ├─init.scope
                  │ │ └─402906 /run/current-system/systemd/lib/systemd/systemd
                  │ └─system.slice
                  │   ├─console-getty.service
                  │   │ └─403298 agetty --login-program /nix/store/qiwc1r9wkn34wc49q1dbsh7nykwsxhi4-shadow-4.14.0/bin/login --noclear --keep-baud console 115>
                  │   ├─dbus.service
                  │   │ └─403240 /nix/store/phgwf74mmw8hi39cf1kjw81yfgsbsfjx-dbus-1.14.8/bin/dbus-daemon --system --address=systemd: --nofork --nopidfile --s>
                  │   ├─dhcpcd.service
                  │   │ ├─403176 "dhcpcd: [launcher]"
                  │   │ ├─403181 "dhcpcd: [manager] [ip4] [ip6]"
                  │   │ ├─403182 "dhcpcd: [privileged proxy]"
                  │   │ ├─403183 "dhcpcd: [network proxy]"
                  │   │ └─403184 "dhcpcd: [control proxy]"
                  │   ├─nginx.service
                  │   │ ├─403304 "nginx: master process /nix/store/sy0nqq88gnmk6z0frh5m1az3yri85xrk-nginx-1.24.0/bin/nginx -c /nix/store/3r6b2zq2f4qjdfsh1sx4>
                  │   │ └─403305 "nginx: worker process"
                  │   ├─nscd.service
                  │   │ └─403233 /nix/store/nha2gprmndij5xycg9js8i9pyndjrj01-nsncd-unstable-2022-11-14/bin/nsncd
                  │   ├─systemd-journald.service
                  │   │ └─403151 /nix/store/1zmmnm0r0bdga398rl7fc7s4hkyqxjk4-systemd-254.3/lib/systemd/systemd-journald
                  │   └─systemd-logind.service
                  │     └─403200 /nix/store/1zmmnm0r0bdga398rl7fc7s4hkyqxjk4-systemd-254.3/lib/systemd/systemd-logind
                  └─supervisor
                    └─402897 systemd-nspawn --quiet --keep-unit --boot --link-journal=try-guest --network-veth -U --settings=override --machine=nginx-test

oct 20 20:16:24 trantor systemd-nspawn[402897]:          Starting Permit User Sessions...
oct 20 20:16:24 trantor systemd-nspawn[402897]: [  OK  ] Finished Permit User Sessions.
oct 20 20:16:24 trantor systemd-nspawn[402897]: [  OK  ] Started Console Getty.
oct 20 20:16:24 trantor systemd-nspawn[402897]: [  OK  ] Reached target Login Prompts.
oct 20 20:16:25 trantor systemd-nspawn[402897]: [  OK  ] Started Nginx Web Server.
oct 20 20:16:30 trantor systemd-nspawn[402897]:
oct 20 20:16:30 trantor systemd-nspawn[402897]:
oct 20 20:16:30 trantor systemd-nspawn[402897]: <<< Welcome to NixOS 23.11.20231016.ca012a0 (x86_64) - console >>>
```

The machine is up and running!

```sh
$ curl 127.0.0.1:8888
curl: (7) Failed to connect to 127.0.0.1 port 8888 after 0 ms: Couldn't connect to server
```

Oops, we can't access the Nginx instance yet. I'll explain how to fix that shortly. For now, let's log in to the machine.

```sh
$ sudo machinectl login nginx-test
Connected to machine nginx-test. Press ^] three times within 1s to exit session.


<<< Welcome to NixOS 23.11.20231016.ca012a0 (x86_64) - pts/1 >>>


nixos login: root
Password:

[root@nixos:~]# curl 127.0.0.1:8888
hello from the container!
```

Fantastic! We're in, and Nginx is running!

### enabling external network access

The host system can control various aspects of the **nspawn** containers using nspawn configuration files. To enable external network access for our container, let's create a file named `nginx-test.nspawn` with the following content:

```ini
[Network]
VirtualEthernet=no
```

Now, copy this file to `/etc/systemd/nspawn/nginx-test.nspawn` and restart the machine.

```sh
$ sudo cp nginx-test.nspawn /etc/systemd/nspawn/
$ sudo machinectl stop nginx-test
$ sudo machinectl start nginx-test

$ curl 127.0.0.1:8888
hello from the container!
```

Great! With this configuration, we can now access Nginx externally. The setting we configured disables the virtual Ethernet connection between the host and the container, allowing the container to use the same network as the host.

## into the code

I've fully adopted [NixOS flakes](https://nixos.wiki/wiki/Flakes), which is a relatively new concept that enhances the management of Nix dependencies, greatly improving reproducibility. Keep in mind that flakes **require** a Git repository, and all files used by the flake must be at least present in staging.

The following code represents a flake that generates a tarball containing the root file system of a NixOS system with Nginx installed:

```nix
# flake.nix
{
  description = "Example NixOS Systemd-nspawn container";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = inputs: let
    forAllSystems = inputs.nixpkgs.lib.genAttrs ["aarch64-linux" "x86_64-linux"];
  in {
    packages = forAllSystems (system: {
      default = let
        nixos = inputs.nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [./configuration.nix ./nspawn-tarball.nix];
        };
      in
        nixos.config.system.build.tarball;
    });
  };
}
```

This module is responsible for generating the tarball:

```nix
# nspawn-tarball.nix
{
  config,
  pkgs,
  ...
}: let
  makeTarball = pkgs.callPackage (pkgs.path + "/nixos/lib/make-system-tarball.nix");

  indexFile = builtins.toFile "index.html" ''
    hello from the container!
  '';
in {
  boot.postBootCommands = ''
    # After booting, register the contents of the Nix store in the Nix
    # database.

    if [ -f /nix-path-registration ]; then
      ${config.nix.package.out}/bin/nix-store --load-db < /nix-path-registration &&
      rm /nix-path-registration
    fi
  '';

  system.build.tarball = makeTarball {
    extraArgs = "--owner=0";

    storeContents = [
      {
        object = config.system.build.toplevel;
        symlink = "/nix/var/nix/profiles/system";
      }
    ];

    contents = [
      {
        # systemd-nspawn requires this file to exist
        source = config.system.build.toplevel + "/etc/os-release";
        target = "/etc/os-release";
      }
      {
        source = indexFile;
        target = "/srv/www/index.html";
      }
    ];

    extraCommands = pkgs.writeScript "extra-commands" ''
      mkdir -p proc sys dev sbin
      ln -sf /nix/var/nix/profiles/system/init sbin/init
    '';
  };
}
```

And this snippet showcases the configuration of the NixOS system inside the container:

```nix
# configuration.nix
{
  pkgs,
  lib,
  ...
}: {
  boot.isContainer = true;
  documentation.enable = lib.mkDefault false;
  documentation.nixos.enable = lib.mkDefault false;

  networking.firewall.enable = false;
  users.users.root.password = "testing"; # a better approach here is to use 'users.users.root.initialHashedPassword'

  environment.systemPackages = with pkgs; [
    curl
  ];

  services.nginx = {
    enable = true;
    defaultHTTPListenPort = 8888;
    virtualHosts."www.example.com" = {
      root = "/srv/www";
    };
  };

  system.stateVersion = "23.11";
}
```

## eliminating the tarball step

The previous approach is excellent for scenarios where you need to import the generated system onto a different system that might not even have Nix installed. It can even enable you to create a self-managed container, allowing for rebuilds within the container with some additional code. However, if the target system already has Nix installed, you can optimize by utilizing the local `/nix/store`, saving both time and disk space.

I have an example that actually runs my [media-stack](https://github.com/aorith/media-stack) on Fedora Silverblue.
