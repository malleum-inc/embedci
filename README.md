# EmbedCI

This project aims to provide docker containers for different architectures that are
commonly found in embedded devices. The base OS is based on Debian Linux and uses QEMU
user mode as well as binfmt to automatically run foreign binaries "natively" on x86
systems.

## Why do this?

Running QEMU against foreign libraries involves lots of awful hacks to get executables to run and link
properly at runtime. Dockers are a great way to make things more portable and provide a smoother experience
when it comes to cross-compiling tools for different architectures. It is much slower than using
a native cross-compilation toolchain, however, it provides a quick and dirty way to get started with 
cross-compiling tools for embedded devices.

Finally, this project is just the beginning of a much larger project which is yet to be announced! 

# Usage

## Build a Container
The `build.sh` script is designed to let you build Linux containers targeting different
architectures and debian versions and variants. The root filesystem is built using the
`debootstrap` script with an instance of `qemu-<arch>-static` copied into `/usr/bin` of
the container's filesystem. This allows foreign binaries to run "natively". Here's an
example of how you would build a container running debian buster with the minimal base
variant for `armel` processors.

```bash
$ ./build.sh armel buster minbase 
```  

The arguments for `build.sh` are as follows:

```
usage: ./build.sh <cpu architecture> [debian version] [debian variant]
```

Where:
* `<cpu architecture>` is one of the following entries from the debian supported architectures 
[wiki page](https://www.debian.org/ports/).
* `[debian version]` (optional, default=`buster`) is the version of Debian you want to run.
* `[debian variant]` (option, default=`minbase`) is the variant of Debian you want to bootstrap. As of this
writing, `minbase` and `buildd` are supported.

The acceptable values for Debian version and variant can be found from the Debian 
[release page](https://www.debian.org/releases/) and `debootstrap` manpage, respectively, for future 
releases. However, `fakechroot` should be avoided for the variant as it is not supported.

## Running a Container
The `./run.sh` script can be used to run containers you've built. Here's an example of how you would run
a container built for the `armel` architecture with the `minbase` variant:

```bash
$ ./run.sh armel buster minbase
```

The arguments are exactly the same as the `build.sh` script, however, the version and variant parameters
are required:

```
usage: ./build.sh <cpu architecture> <debian version> <debian variant>
```

Docker containers are built with `/bin/bash` as the entrypoint by default. If you are using `docker run`
to run your containers, you will have to map the corresponding `qemu-*-static` binary to the container's
`/usr/bin` path in order for the container to work.

# Credit
Credit goes to [@nachoparker](https://github.com/nachoparker) for documenting this really neat technique
as part of a three-part series:

* [The real power of Linux executables](https://ownyourbits.com/2018/05/23/the-real-power-of-linux-executables/)
* [Transparently running binaries from any architecture in Linux with QEMU and binfmt_misc](https://ownyourbits.com/2018/06/13/transparently-running-binaries-from-any-architecture-in-linux-with-qemu-and-binfmt_misc/)
* [Running and building ARM Docker containers in x86](https://ownyourbits.com/2018/06/27/running-and-building-arm-docker-containers-in-x86/)
