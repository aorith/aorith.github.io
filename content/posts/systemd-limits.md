---
title: "Resource Limits in systemd"
date: "2023-10-20T19:37:13+02:00"
tags:
  - systemd
draft: false
---

In the world of system administration and resource management, understanding how to set and test resource limits is crucial. Today, we'll delve into systemd, a vital component in many Linux distributions, and explore how to impose limits on resources like memory and CPU. We'll also walk through practical examples to test these limits effectively.

## Setting Resource Limits

In the systemd configuration, you can define resource limits for services and units. Here's an example configuration snippet that sets memory and CPU limits for a service:

```ini
[Service]
# Define a custom slice for these limits to apply
Slice="mycustom.slice"

MemoryAccounting=yes
MemoryHigh=2G
MemoryMax=4G
MemorySwapMax=500M
CPUAccounting=true

# Weight among units in the same slice
CPUWeight=50

# Maximum percentage; values above 100 indicate multiple cores
CPUQuota=50%
```

This configuration limits memory usage to 4 GB, with a swap limit of 500 MB, and assigns a CPU weight and quota. These settings help manage resource allocation effectively.

## Testing Resource Limits

To test these resource limits, especially memory limits, you can use the `systemd-run` command. Here's an example command to run a shell session with specified resource constraints:

```sh
$ cd /tmp
$ systemd-run --shell \
    --property=PrivateTmp=True \
    --property=Slice=custom.slice \
    --property=MemoryAccounting=true \
    --property=MemoryHigh=50M \
    --property=MemoryMax=100M
```

In older versions of systemd, you would use the following command:

```sh
systemd-run \
    --property=PrivateTmp=True \
    --property=Slice=custom.slice \
    --property=MemoryAccounting=true \
    --property=MemoryHigh=50M \
    --property=MemoryMax=100M \
    -t /bin/bash
```

This command opens a shell where you can run commands to increment memory usage. To check the memory usage of this unit, use the following command:

```sh
$ systemd-cgls /custom.slice
Control group /custom.slice:
└─run-u101.service (#8362)
  → user.invocation_id: 264efe4a84b243b3bd4e8b42c533fdb5
  └─3827 /run/current-system/sw/bin/bash
```

This will display the control group hierarchy, showing the unit you created. In this case, it's `run-u101.service`. You can inspect the memory usage by running:

```sh
$ systemctl status run-u101.service
```

Now, you can execute commands within the shell to increase memory usage, for instance:

```sh
$ cd /dev/shm
$ fallocate -l 30M file.img
```

You'll notice memory usage increases. If you reach the `MemoryHigh` limit, systemd will try to free unused memory, in this scenario the `fallocate` command will slow down. When you hit the `MemoryMax` limit, it results in an Out of Memory (OOM) condition.

### Note on Old systemd Versions

In older versions of systemd, you cannot specify a maximum memory swap limit, and the behavior when reaching the `MemoryHigh` value is different. At this point, systemd starts using the swap.

## Changing Properties on the Fly

You can change these resource limits on the fly using `systemctl`. For example, to modify the `MemoryHigh` property for a running service, use:

```sh
$ systemctl set-property --runtime run-re2a468435d1149debba0bbab9ac6cc1f.service MemoryHigh=69M
```

Understanding how to set and test resource limits is essential for efficient system resource management. systemd provides powerful tools to control these limits, ensuring your applications run smoothly without consuming excessive resources.
