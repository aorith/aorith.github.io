---
title: "Locking mechanisms in python scripts"
date: "2024-04-13T10:50:53+02:00"
tags:
  - python
---

Today, I wanted to create a basic locking mechanism in Python to prevent certain commands/functions from running concurrently.

I have an script that runs inside of a CI/CD pipeline but it can also be triggered manually. The problem is that certain commands within the script shouldn't be executed in parallel and I would like to handle that gracefully.

## Use case

Imagine a Python script that manages the compilation and distribution of software builds with two main command modes: `build` and `deploy`.

1. **`python3 script.py build`**: Compiles source code into executables and libraries, creating compilation artifacts.

2. **`python3 script.py deploy`**: Tags, packages, and deploys compiled artifacts to an environment.

It's easy to notice that it would be a bad idea to run these commands in
parallel. If a `deploy` operation starts while a `build` is still processing,
the deployment might catch incomplete or outdated artifacts.

There are many things that could go wrong in this scenario.

## First try: Initial implementation

I thought that this would be pretty easy to implement, I reached the [fcntl](https://docs.python.org/3/library/fcntl.html) documentation and came up with this:

```python
import fcntl
import sys
import time
from contextlib import contextmanager
from pathlib import Path


@contextmanager
def lock_execution(lock_file_path: Path = Path("/tmp/.example.lock")):
    """Prevents parallel execution."""

    with open(lock_file_path, "w") as f:
        try:
            fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
            yield
        except IOError:
            print(
                f"Another instance using the lock '{lock_file_path}' is already running.",
                file=sys.stderr,
            )
            sys.exit(0)
        finally:
            fcntl.flock(f, fcntl.LOCK_UN)


def main():
    print("Running main ...")
    with lock_execution():
        print("Lock acquired, running ...")
        time.sleep(5)
        print("Done.")


if __name__ == "__main__":
    main()
```

The idea is to wrap the code that shouldn't be parallelized with the context manager `lock_execution` function. Now, when I try to run this script from two terminal windows I get the following:

```bash
# Terminal 1
[aorith@arcadia:~] $ python3 /tmp/first.py
Running main ...
Lock acquired, running ...

# Terminal 2
[aorith@arcadia:~] $ python3 /tmp/first.py
Running main ...
Another instance using the lock '/tmp/.example.lock' is already running.

# Terminal 1 (after 5 seconds)
Done.
```

But what if this script is executed by different users? Only the user that creates the lock file will be able to use the script. Other users will be greeted with this error:

```python
PermissionError: [Errno 13] Permission denied: '/tmp/.example.lock'
```

## Second try: Making it compatible with multiple users

The script cannot just delete the lock file when it finishes as it would introduce race conditions that are very difficult to catch and debug. So let's try _chmoding_ the file upon creation and see what happens.

```python {hl_lines=["5-9"]}
@contextmanager
def lock_execution(lock_file_path: Path = Path("/tmp/.example.lock")):
    """Prevents parallel execution."""

    try:
        lock_file_path.touch()
        os.chmod(lock_file_path, 0o666)
    except PermissionError:
        pass
```

Ok, that should give `rw` permissions to everyone upon creation. Let's try it and see what happens:

```bash
# Terminal 1 (root)
[root@arcadia:~] % python3 /tmp/second.py
Running main ...
Lock acquired, running ...

# Terminal 2 (user)
[aorith@arcadia:~] $ python3 /tmp/second.py
Running main ...
Another instance using the lock '/tmp/.example.lock' is already running.

# Now the other way around
# Terminal 1 (user)
[aorith@arcadia:~] $ python3 /tmp/second.py
Running main ...
Lock acquired, running ...


# Terminal 2 (root)
[root@arcadia:~] % python3 /tmp/second.py
Running main ...
Another instance using the lock '/tmp/.example.lock' is already running.
```

Looks good, the lock file is created and owned by root but all the users can use it a as lock file without issues.

Hmm, just to be safe, let's remove the lock file and create it with a regular user:

```bash {hl_lines=["24","26-27"]}
# Terminal 1 (root)
[root@arcadia:~] % rm /tmp/.example.lock
[root@arcadia:~] %

# Terminal 2 (user)
[aorith@arcadia:~] $ python3 /tmp/second.py
Running main ...
Lock acquired, running ...

# Terminal 1 (root)
[root@arcadia:~] % python3 /tmp/second.py
Running main ...
Traceback (most recent call last):
  File "/tmp/second.py", line 42, in <module>
    main()
  File "/tmp/second.py", line 35, in main
    with lock_execution():
  File "/nix/store/il591rdaydbqr2cysh6vsa2kazxprzsn-python3-3.11.8/lib/python3.11/contextlib.py", line 137, in __enter__
    return next(self.gen)
           ^^^^^^^^^^^^^^
  File "/tmp/second.py", line 19, in lock_execution
    with open(lock_file_path, "w") as f:
         ^^^^^^^^^^^^^^^^^^^^^^^^^
PermissionError: [Errno 13] Permission denied: '/tmp/.example.lock'

[root@arcadia:~] % ls -lrt /tmp/.example.lock
-rw-rw-rw- 1 aorith aorith 0 abr 13 13:41 /tmp/.example.lock
```

Wait, what? How comes that root doesn't have permissions ...?

After some digging, I found out that it's a security measure introduced in the Linux kernel for versions >= 4.9, this [stackexchange post](https://unix.stackexchange.com/questions/691441/root-cannot-write-to-file-that-is-owned-by-regular-user) has more details about it.

## Third try: Fix the permissions issue

Alright, let's modify the code to workaround the security measure. We are already creating the file with a `touch` command when it's missing and the write permissions are not required to lock it. So let's change the `open` mode:

```python {hl_lines=["1"]}
    with open(lock_file_path, "r") as f:
        try:
            fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
```

Now the lock file is only open in read mode and it seems to work fine:

```bash
# Terminal 1 (user)
[aorith@arcadia:~] $ python3 /tmp/third.py
Running main ...
Lock acquired, running ...

# Terminal 2 (root)
[root@arcadia:~] % python3 /tmp/third.py
Running main ...
Another instance using the lock '/tmp/.example.lock' is already running.

[root@arcadia:~] % ls -l /tmp/.example.lock
-rw-rw-rw- 1 aorith aorith 0 abr 13 13:56 /tmp/.example.lock
```

Hmm, am I done? Not really... What happens if the protected code raises another `IOError` exception?

```python {hl_lines=["5"]}
def main():
    print("Running main ...")
    with lock_execution():
        print("Lock acquired, running ...")
        Path("/tmp/this/path/does/not/exists").touch()
        time.sleep(5)
        print("Done.")
```

```bash
# Terminal 1 (the only one running the script)
[aorith@arcadia:~] $ python3 /tmp/third.py
Running main ...
Lock acquired, running ...
Another instance using the lock '/tmp/.example.lock' is already running.
```

Ehm... I don't have another instance running, what is going on? The answer is that the code block wrapped with the context manager function runs at the position of the `yield` statement, and that statement is wrapped with a `try/except` block that captures all the `IOError` exceptions.

Not good, errors would be hidden unexpectedly.

## Final version: Running the code outside of the try/except block

We need to move the `yield` statement outside of the `try/except` block and be very careful with the `finally` block as it has priority with some statements as explained [here](https://docs.python.org/3/reference/compound_stmts.html#finally-clause).

I'm also adding a boolean to move the `sys.exit` out of the `IOError` exception, just to be safe:

```python {hl_lines=["11","17","19","25-26","28"]}
@contextmanager
def lock_execution(lock_file_path: Path = Path("/tmp/.example.lock")):
    """Prevents parallel execution."""

    try:
        lock_file_path.touch()
        os.chmod(lock_file_path, 0o666)
    except PermissionError:
        pass

    locked: bool = False

    # https://unix.stackexchange.com/questions/691441/root-cannot-write-to-file-that-is-owned-by-regular-user
    with open(lock_file_path, "r") as f:
        try:
            fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
            # we don't yield here, we want to raise IOError if it's not coming from flock
        except IOError:
            locked = True
            print(
                f"Another instance using the lock '{lock_file_path}' is already running.",
                file=sys.stderr,
            )
        finally:
            if locked:
                sys.exit(0)

            yield # code runs here
            fcntl.flock(f, fcntl.LOCK_UN)
```

Now when I apply this context manager function over a block of code that raises an `IOError` (or any) exception its raised normally:

```bash
[aorith@arcadia:~] $ python3 /tmp/finalversion.py
Running main ...
Lock acquired, running ...
Traceback (most recent call last):
  File "/tmp/finalversion.py", line 48, in <module>
    main()
  File "/tmp/finalversion.py", line 42, in main
    Path("/tmp/this/path/does/not/exists").touch()
  File "/nix/store/il591rdaydbqr2cysh6vsa2kazxprzsn-python3-3.11.8/lib/python3.11/pathlib.py", line 1108, in touch
    fd = os.open(self, flags, mode)
         ^^^^^^^^^^^^^^^^^^^^^^^^^^
FileNotFoundError: [Errno 2] No such file or directory: '/tmp/this/path/does/not/exists'
```

## Extra: Other ways of acquiring a lock

I have considered other ways that do not use a file for locking, for example we can bind a port using the `socket` library:

```python
import sys
import socket

def some_command():
        try:
            s = socket.socket()
            s.bind(("127.0.0.1", 12340))
        except OSError:
            print("Another instance is running...")
            sys.exit(0)

        # Main code goes here ...
```

The problem with this approach is that we to reserve port numbers if we are using this locking method with multiple scripts in the same machine and that is not very intuitive, locking using files can have a descriptive name.

Another method would be to bind to a unix socket, so we don't lose the advantage of giving the lock file a descriptive name:

```python
@contextmanager
def lock_execution(lock_file_path: Path = Path("/tmp/.example.lock")):
    """Prevents parallel execution."""

    locked: bool = False

    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        s.bind(str(lock_file_path))
    except OSError:
        locked = True
        print(
            f"Another instance using the lock '{lock_file_path}' is already running.",
            file=sys.stderr,
        )
    finally:
        if locked:
            sys.exit(0)

        try:
            yield
        finally:
            # Make sure that the socket is deleted even if the protected code raises an exception or exits
            lock_file_path.unlink(missing_ok=True)
```

This seems to also work for all the scenarios that I've tested. It requires an extra `try/except` block to ensure that the socket file is removed at the end.

I'll keep using the `fcntl` method because it seems less _hacky_.

Please, leave a comment if you have some other interesting implementations :)
