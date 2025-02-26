Tutorial
********

This tutorial will teach you how to create and run Charliecloud images, using
both examples included with the source code as well as new ones you create
from scratch.

This tutorial assumes that: (a) Charliecloud is in your path, including
Charliecloud's fully unprivileged image builder :code:`ch-image` and (b) the
Charliecloud source code is available at :code:`/usr/local/src/charliecloud`.
Optionally, (c) :code:`ch-run` is linked with SquashFUSE to provide internal
SquashFS image mounting. (If you wish to use Docker to build images, see the
:ref:`FAQ <faq_building-with-docker>`.)

.. contents::
   :depth: 2
   :local:

.. note::

   Shell sessions throughout this documentation will use the prompt :code:`$`
   to indicate commands executed natively on the host and :code:`>` for
   commands executed in a container.


90 seconds to Charliecloud
==========================

This section is for the impatient. It shows you how to quickly build and run a
"hello world" Charliecloud container. If you like what you see, then proceed
with the rest of the tutorial to understand what is happening and how to use
Charliecloud for your own applications.

The preferred workflow uses our internal SquashFS mounting code. Your sysadmin
should be able to tell you if this is linked in.

::

  $ cd /usr/local/share/doc/charliecloud/examples/hello
  $ ch-image build --force .
  inferred image name: hello
  [...]
  grown in 4 instructions: hello
  $ ch-convert hello /var/tmp/hello.sqfs
  input:   ch-image  hello
  output:  squash    /var/tmp/hello.sqfs
  packing ...
  Parallel mksquashfs: Using 8 processors
  Creating 4.0 filesystem on /var/tmp/hello.sqfs, block size 65536.
  [=============================================|] 10411/10411 100%
  [...]
  done
  $ ch-run /var/tmp/hello.sqfs -- echo "I'm in a container"
  I'm in a container

If not, you can create image in plain directory format instead::

  $ cd /usr/local/share/doc/charliecloud/examples/hello
  $ ch-image build --force .
  inferred image name: hello
  [...]
  grown in 4 instructions: hello
  $ ch-convert hello /var/tmp/hello
  input:   ch-image  hello
  output:  dir       /var/tmp/hello
  exporting ...
  done
  $ ch-run /var/tmp/hello -- echo "I'm in a container"
  I'm in a container


Getting help
============

All the executables have decent help and can tell you what version of
Charliecloud you have (if not, please report a bug). For example::

  $ ch-run --help
  Usage: ch-run [OPTION...] NEWROOT CMD [ARG...]

  Run a command in a Charliecloud container.
  [...]
  $ ch-run --version
  0.26

A description of all commands is also collected later in this documentation; see
:doc:`command-usage`. In addition, each executable has a man page.

Your first user-defined software stack
======================================

In this section, we will create and run a simple "hello, world" image. This
uses the :code:`hello` example in the Charliecloud source code. Start with::

  $ cd examples/hello

Defining your UDSS
------------------

You must first write a Dockerfile that describes the image you would like;
consult the `Dockerfile documentation
<https://docs.docker.com/engine/reference/builder/>`_ for details on how to do
this. Note that run-time functionality such as :code:`ENTRYPOINT` is not
supported.

We will use the following simple Dockerfile:

.. literalinclude:: ../examples/hello/Dockerfile
   :language: docker

This creates a minimal AlmaLinux 8 image with :code:`ssh` installed. We
will encounter more complex Dockerfiles later in this tutorial.

Build Charliecloud image
------------------------

The three arguments here are the :code:`ch-image` subcommand :code:`build`,
the option to enable unprivileged build workarounds :code:`--force`, and the
context directory :code:`.`, which in this case is the current directory.

::

  $ ch-image build --force .
  inferred image name: hello
  2 FROM almalinux:8
  will use --force: rhel8: CentOS/RHEL 8+
  [...]
  7 COPY ['.'] -> 'hello'
  9 RUN ['/bin/sh', '-c', 'touch /usr/bin/ch-ssh']
  --force: init OK & modified 1 RUN instructions
  grown in 4 instructions: hello

.. note::

   :code:`ch-image` prints information about the build process while in
   progress. While not shown above, it uses yellow for this chatter, while
   build command output remains in the default color (e.g., white).

This image and the :code:`almalinux:8` base image used to build it are now
visible in Charliecloud's builder storage:

::

  $ ch-image list
  almalinux:8
  hello


Sharing images
--------------

Charliecloud images in internal storage can be converted to multiple formats
via :code:`ch-convert`, e.g. SquashFS (if SquashFUSE is installed)::

  $ ch-convert hello /var/tmp/hello.sqfs
  input:   ch-image  hello
  output:  squash    /var/tmp/hello.sqfs
  packing ...
  [...]
  done
  $ ls -l /var/tmp/hello.sqfs
  -rw-rw-r-- 1 heasterday heasterday 83288064 Nov 15 12:07 /var/tmp/hello.sqfs

Tarball::

  $ ch-convert hello /var/tmp/hello.tar.gz
  input:   ch-image  hello
  output:  tar       /var/tmp/hello.tar.gz
  exporting ...
  done
  $ ls -l /var/tmp/hello.tar.gz
  -rw-rw-r-- 1 heasterday heasterday 86122450 Nov 15 15:23 /var/tmp/hello.tar.gz

Directory::

  $ ch-convert hello /var/tmp/hello
  input:   ch-image  hello
  output:  dir       /var/tmp/hello
  exporting ...
  done
  $ ls /var/tmp/hello
  bin  dev  hello  lib    lost+found  mnt  proc  run   srv  tmp  var
  ch   etc  home   lib64  media       opt  root  sbin  sys  usr

:code:`ch-convert` can also convert images between any two supported formats,
e.g. SquashFS to tarball::

  $ ch-convert hello.sqfs hello.tar.gz
  input:   tar       hello.tar.gz
  output:  squash    hello.sqfs
  unpacking ...
  [...]
  done

Tarball to directory::

  $ ch-convert /var/tmp/hello.tar.gz /var/tmp/hello
  input:   tar       /var/tmp/hello.tar.gz
  output:  dir       /var/tmp/hello
  unpacking ...
  [...]
  done

Charliecloud also supports "pushing" images from its internal storage to a
registry using :code:`ch-image push` and "pulling" images in the reverse
direction with :code:`ch-image pull`.


Distributing images
-------------------

Thus far, the workflow has taken place on the build system. The next step is
to copy the built image to the run system. This can use any appropriate method
for moving files: :code:`scp`, :code:`rsync`, something integrated with the
scheduler, etc. (The purpose of the tarball image format is to put images in a
single file that's easy to move around with traditional UNIX commands.)

If the build and run systems are the same, then no copy is needed. This is a
typical use case for development and testing.

If you are using the SquashFS workflow, copy the :code:`.sqfs` file you
created above to the run system; otherwise, copy the :code:`.tar.gz`, then
unpack it on the run system using :code:`ch-convert` as above.

.. warning::

   Generally, you should avoid directory-format images on shared filesystems
   such as NFS and Lustre, in favor of local storage such as :code:`tmpfs` and
   local hard disks. This will yield better performance for you and anyone
   else on the shared filesystem. In contrast, SquashFS images should work
   fine on shared filesystems.


Running images
--------------

We are now ready to run programs inside a Charliecloud container. This is done
with the :code:`ch-run` command::

  $ ch-run /var/tmp/hello.sqfs -- echo hello
  hello

or::

  $ ch-run /var/tmp/hello -- echo hello
  hello


.. note::

   You can run perfectly well out of :code:`/tmp`, but because it is
   bind-mounted automatically, the image root will then appear in multiple
   locations in the container's filesystem tree. This can cause confusion for
   both users and programs.

Symbolic links in :code:`/proc` tell us the current namespaces, which are
identified by long ID numbers::

  $ ls -l /proc/self/ns
  total 0
  lrwxrwxrwx 1 reidpr reidpr 0 Sep 28 11:24 ipc -> ipc:[4026531839]
  lrwxrwxrwx 1 reidpr reidpr 0 Sep 28 11:24 mnt -> mnt:[4026531840]
  lrwxrwxrwx 1 reidpr reidpr 0 Sep 28 11:24 net -> net:[4026531969]
  lrwxrwxrwx 1 reidpr reidpr 0 Sep 28 11:24 pid -> pid:[4026531836]
  lrwxrwxrwx 1 reidpr reidpr 0 Sep 28 11:24 user -> user:[4026531837]
  lrwxrwxrwx 1 reidpr reidpr 0 Sep 28 11:24 uts -> uts:[4026531838]
  $ ch-run /var/tmp/hello -- ls -l /proc/self/ns
  total 0
  lrwxrwxrwx 1 reidpr reidpr 0 Sep 28 17:34 ipc -> ipc:[4026531839]
  lrwxrwxrwx 1 reidpr reidpr 0 Sep 28 17:34 mnt -> mnt:[4026532257]
  lrwxrwxrwx 1 reidpr reidpr 0 Sep 28 17:34 net -> net:[4026531969]
  lrwxrwxrwx 1 reidpr reidpr 0 Sep 28 17:34 pid -> pid:[4026531836]
  lrwxrwxrwx 1 reidpr reidpr 0 Sep 28 17:34 user -> user:[4026532256]
  lrwxrwxrwx 1 reidpr reidpr 0 Sep 28 17:34 uts -> uts:[4026531838]

Notice that the container has different mount (:code:`mnt`) and user
(:code:`user`) namespaces, but the rest of the namespaces are shared with the
host. This highlights Charliecloud's focus on functionality (make your UDSS
run), rather than isolation (protect the host from your UDSS).

Normally, each invocation of :code:`ch-run` creates a new container, so if you
have multiple simultaneous invocations, they will not share containers. In
some cases this can cause problems with MPI programs. However, there is an
option :code:`--join` that can solve them; see the :ref:`FAQ <faq_join>` for
details.

.. note::

   The :code:`--` in the :code:`ch-run` command line is a standard argument
   that separates options from non-option arguments. Without it,
   :code:`ch-run` would try (and fail) to interpret :code:`ls`’s :code:`-l`
   argument.

These IDs are available both in the symlink target as well as its inode
number::

  $ stat -L --format='%i' /proc/self/ns/user
  4026531837
  $ ch-run /var/tmp/hello -- stat -L --format='%i' /proc/self/ns/user
  4026532256

You can also run interactive commands, such as a shell::

  $ ch-run /var/tmp/hello.sqfs -- /bin/bash
  > stat -L --format='%i' /proc/self/ns/user
  4026532256
  > exit

Be aware that wildcards in the :code:`ch-run` command are interpreted by the
host, not the container, unless protected. One workaround is to use a
sub-shell. For example::

  $ ls /usr/bin/oldfind
  ls: cannot access '/usr/bin/oldfind': No such file or directory
  $ ch-run /var/tmp/hello.sqfs -- ls /usr/bin/oldfind
  /usr/bin/oldfind
  $ ls /usr/bin/oldf*
  ls: cannot access '/usr/bin/oldf*': No such file or directory
  $ ch-run /var/tmp/hello.sqfs -- ls /usr/bin/oldf*
  ls: cannot access /usr/bin/oldf*: No such file or directory
  $ ch-run /var/tmp/hello.sqfs -- sh -c 'ls /usr/bin/oldf*'
  /usr/bin/oldfind

You have now successfully run commands within a single-node Charliecloud
container. Next, we explore how Charliecloud accesses host resources.


Interacting with the host
=========================

Charliecloud is not an isolation layer, so containers have full access to host
resources, with a few quirks. This section demonstrates how this works.

Filesystems
-----------

Charliecloud makes host directories available inside the container using bind
mounts, which is somewhat like a hard link in that it causes a file or
directory to appear in multiple places in the filesystem tree, but it is a
property of the running kernel rather than the filesystem.

Several host directories are always bind-mounted into the container. These
include system directories such as :code:`/dev`, :code:`/proc`, and
:code:`/sys`; :code:`/tmp`; Charliecloud's :code:`ch-ssh` command in
:code:`/usr/bin`; and the invoking user's home directory (for dotfiles),
unless :code:`--no-home` is specified.

Charliecloud uses recursive bind mounts, so for example if the host has a
variety of sub-filesystems under :code:`/sys`, as Ubuntu does, these will be
available in the container as well.

In addition to the default bind mounts, arbitrary user-specified directories
can be added using the :code:`--bind` or :code:`-b` switch. By default, mounts
use the same path as provided from the host. In the case of directory images,
which are writeable, the target mount directory will be automatically created
before the container is started::

  $ mkdir /var/tmp/foo0
  $ echo hello > /var/tmp/foo0/bar
  $ mkdir /var/tmp/foo1
  $ echo world > /var/tmp/foo1/bar
  $ ch-run -b /var/tmp/foo0 -b /var/tmp/foo1 /var/tmp/hello -- bash
  > cat /var/tmp/foo0/bar
  hello
  > cat /var/tmp/foo1/bar
  world

However, as SquashFS filesystems are read-only, in this case you must provide
a destination that already exists, like those created under :code:`/mnt`::

  $ mkdir /var/tmp/foo0
  $ echo hello > /var/tmp/foo0/bar
  $ mkdir /var/tmp/foo1
  $ echo world > /var/tmp/foo1/bar
  $ ch-run -b /var/tmp/foo0 -b /var/tmp/foo1 /var/tmp/hello -- bash
  ch-run[1184427]: error: can't mkdir: /var/tmp/hello/var/tmp/foo0: Read-only file system (ch_misc.c:142 30)
  $ ch-run -b /var/tmp/foo0:/mnt/0 -b /var/tmp/foo1:/mnt/1 /var/tmp/hello -- bash
  > ls /mnt
  0  1  2  3  4  5  6  7  8  9
  > cat /mnt/0/bar
  hello
  > cat /mnt/1/bar
  world



Network
-------

Charliecloud containers share the host's network namespace, so most network
things should be the same.

However, SSH is not aware of Charliecloud containers. If you SSH to a node
where Charliecloud is installed, you will get a shell on the host, not in a
container, even if :code:`ssh` was initiated from a container::

  $ stat -L --format='%i' /proc/self/ns/user
  4026531837
  $ ssh localhost stat -L --format='%i' /proc/self/ns/user
  4026531837
  $ ch-run /var/tmp/hello.sqfs -- /bin/bash
  > stat -L --format='%i' /proc/self/ns/user
  4026532256
  > ssh localhost stat -L --format='%i' /proc/self/ns/user
  4026531837

There are several ways to SSH to a remote node and run commands inside a
container. The simplest is to manually invoke :code:`ch-run` in the
:code:`ssh` command::

  $ ssh localhost ch-run /var/tmp/hello.sqfs -- stat -L --format='%i' /proc/self/ns/user
  4026532256

.. note::

   Recall that each :code:`ch-run` invocation creates a new container. That
   is, the :code:`ssh` command above has not entered an existing user
   namespace :code:`’2256`; rather, it has re-used the namespace ID
   :code:`’2256`.

Another is to use the :code:`ch-ssh` wrapper program, which adds
:code:`ch-run` to the :code:`ssh` command implicitly. It takes the
:code:`ch-run` arguments from the environment variable :code:`CH_RUN_ARGS`,
making it mostly a drop-in replacement for :code:`ssh`. For example::

  $ export CH_RUN_ARGS="/var/tmp/hello.sqfs --"
  $ ch-ssh localhost stat -L --format='%i' /proc/self/ns/user
  4026532256
  $ ch-ssh -t localhost /bin/bash
  > stat -L --format='%i' /proc/self/ns/user
  4026532256

:code:`ch-ssh` is available inside containers as well (in :code:`/usr/bin` via
bind-mount)::

  $ export CH_RUN_ARGS="/var/tmp/hello.sqfs --"
  $ ch-run /var/tmp/hello.sqfs -- /bin/bash
  > stat -L --format='%i' /proc/self/ns/user
  4026532256
  > ch-ssh localhost stat -L --format='%i' /proc/self/ns/user
  4026532258

This also demonstrates that :code:`ch-run` does not alter most environment
variables.

.. warning::

   1. :code:`CH_RUN_ARGS` is interpreted very simply; the sole delimiter is
      spaces. It is not shell syntax. In particular, quotes and backslashes
      are not interpreted.

   2. Argument :code:`-t` is required for SSH to allocate a pseudo-TTY and
      thus convince your shell to be interactive. In the case of Bash,
      otherwise you'll get a shell that accepts commands but doesn't print
      prompts, among other other issues. (`Issue #2
      <https://github.com/hpc/charliecloud/issues/2>`_.)

A third may be to edit one's shell initialization scripts to check the command
line and :code:`exec(1)` :code:`ch-run` if appropriate. This is brittle but
avoids wrapping :code:`ssh` or altering its command line.

User and group IDs
------------------

Unlike Docker and some other container systems, Charliecloud tries to make the
container's users and groups look the same as the host's. (This is
accomplished by bind-mounting a custom :code:`/etc/passwd` and
:code:`/etc/group` into the container.) For example::

  $ id -u
  901
  $ whoami
  reidpr
  $ ch-run /var/tmp/hello.sqfs -- bash
  > id -u
  901
  > whoami
  reidpr

More specifically, the user namespace, when created without privileges as
Charliecloud does, lets you map any container UID to your host UID.
:code:`ch-run` implements this with the :code:`--uid` switch. So, for example,
you can tell Charliecloud you want to be root, and it will tell you that
you're root::

  $ ch-run --uid 0 /var/tmp/hello.sqfs -- bash
  > id -u
  0
  > whoami
  root

But, this doesn't get you anything useful, because the container UID is mapped
back to your UID on the host before permission checks are applied::

  > dd if=/dev/mem of=/tmp/pwned
  dd: failed to open '/dev/mem': Permission denied

This mapping also affects how users are displayed. For example, if a file is
owned by you, your host UID will be mapped to your container UID, which is
then looked up in :code:`/etc/passwd` to determine the display name. In
typical usage without :code:`--uid`, this mapping is a no-op, so everything
looks normal::

  $ ls -nd ~
  drwxr-xr-x 87 901 901 4096 Sep 28 12:12 /home/reidpr
  $ ls -ld ~
  drwxr-xr-x 87 reidpr reidpr 4096 Sep 28 12:12 /home/reidpr
  $ ch-run /var/tmp/hello.sqfs -- bash
  > ls -nd ~
  drwxr-xr-x 87 901 901 4096 Sep 28 18:12 /home/reidpr
  > ls -ld ~
  drwxr-xr-x 87 reidpr reidpr 4096 Sep 28 18:12 /home/reidpr

But if :code:`--uid` is provided, things can seem odd. For example::

  $ ch-run --uid 0 /var/tmp/hello.sqfs -- bash
  > ls -nd /home/reidpr
  drwxr-xr-x 87 0 901 4096 Sep 28 18:12 /home/reidpr
  > ls -ld /home/reidpr
  drwxr-xr-x 87 root reidpr 4096 Sep 28 18:12 /home/reidpr

This UID mapping can contain only one pair: an arbitrary container UID to your
effective UID on the host. Thus, all other users are unmapped, and they show
up as :code:`nobody`::

  $ ls -n /tmp/foo
  -rw-rw---- 1 902 902 0 Sep 28 15:40 /tmp/foo
  $ ls -l /tmp/foo
  -rw-rw---- 1 sig sig 0 Sep 28 15:40 /tmp/foo
  $ ch-run /var/tmp/hello.sqfs -- bash
  > ls -n /tmp/foo
  -rw-rw---- 1 65534 65534 843 Sep 28 21:40 /tmp/foo
  > ls -l /tmp/foo
  -rw-rw---- 1 nobody nogroup 843 Sep 28 21:40 /tmp/foo

User namespaces have a similar mapping for GIDs, with the same limitation ---
exactly one arbitrary container GID maps to your effective *primary* GID. This
can lead to some strange-looking results, because only one of your GIDs can be
mapped in any given container. All the rest become :code:`nogroup`::

  $ id
  uid=901(reidpr) gid=901(reidpr) groups=901(reidpr),903(nerds),904(losers)
  $ ch-run /var/tmp/hello.sqfs -- id
  uid=901(reidpr) gid=901(reidpr) groups=901(reidpr),65534(nogroup)
  $ ch-run --gid 903 /var/tmp/hello.sqfs -- id
  uid=901(reidpr) gid=903(nerds) groups=903(nerds),65534(nogroup)

However, this doesn't affect access. The container process retains the same
GIDs from the host perspective, and as always, the host IDs are what control
access::

  $ ls -l /tmp/primary /tmp/supplemental
  -rw-rw---- 1 sig reidpr 0 Sep 28 15:47 /tmp/primary
  -rw-rw---- 1 sig nerds  0 Sep 28 15:48 /tmp/supplemental
  $ ch-run /var/tmp/hello.sqfs -- bash
  > cat /tmp/primary > /dev/null
  > cat /tmp/supplemental > /dev/null

One area where functionality *is* reduced is that :code:`chgrp(1)` becomes
useless. Using an unmapped group or :code:`nogroup` fails, and using a mapped
group is a no-op because it's mapped back to the host GID::

  $ ls -l /tmp/bar
  rw-rw---- 1 reidpr reidpr 0 Sep 28 16:12 /tmp/bar
  $ ch-run /var/tmp/hello.sqfs -- chgrp nerds /tmp/bar
  chgrp: changing group of '/tmp/bar': Invalid argument
  $ ch-run /var/tmp/hello.sqfs -- chgrp nogroup /tmp/bar
  chgrp: changing group of '/tmp/bar': Invalid argument
  $ ch-run --gid 903 /var/tmp/hello.sqfs -- chgrp nerds /tmp/bar
  $ ls -l /tmp/bar
  -rw-rw---- 1 reidpr reidpr 0 Sep 28 16:12 /tmp/bar

Workarounds include :code:`chgrp(1)` on the host or fastidious use of setgid
directories::

  $ mkdir /tmp/baz
  $ chgrp nerds /tmp/baz
  $ chmod 2770 /tmp/baz
  $ ls -ld /tmp/baz
  drwxrws--- 2 reidpr nerds 40 Sep 28 16:19 /tmp/baz
  $ ch-run /var/tmp/hello.sqfs -- touch /tmp/baz/foo
  $ ls -l /tmp/baz/foo
  -rw-rw---- 1 reidpr nerds 0 Sep 28 16:21 /tmp/baz/foo

This concludes our discussion of how a Charliecloud container interacts with
its host and principal Charliecloud quirks. We next move on to installing
software.


Installing your own software
============================

This section covers four situations for making software available inside a
Charliecloud container:

  1. Third-party software installed into the image using a package manager.
  2. Third-party software compiled from source into the image.
  3. Your software installed into the image.
  4. Your software stored on the host but compiled in the container.

Many of Docker's `Best practices for writing Dockerfiles
<https://docs.docker.com/engine/userguide/eng-image/dockerfile_best-practices>`_
apply to Charliecloud images as well, so you should be familiar with that
document.

.. note::

   Maybe you don't have to install the software at all. Is there already a
   trustworthy image on Docker Hub you can use as a base?

Third-party software via package manager
----------------------------------------

This approach is the simplest and fastest way to install stuff in your image.
The :code:`examples/hello` Dockerfile also seen above does this to install the
package :code:`openssh-client`:

.. literalinclude:: ../examples/hello/Dockerfile
   :language: docker
   :lines: 3-7

You can use distribution package managers such as :code:`dnf`, as
demonstrated above, or others, such as :code:`pip` for Python packages.

Be aware that the software will be downloaded anew each time you build the
image, unless you add an HTTP cache, which is out of scope of this tutorial.

Third-party software compiled from source
-----------------------------------------

Under this method, one uses :code:`RUN` commands to fetch the desired software
using :code:`curl` or :code:`wget`, compile it, and install. Our example does
this with two chained Dockerfiles. First, we build a basic CentOS image
(:code:`examples/Dockerfile.almalinux8`):

.. literalinclude:: ../examples/Dockerfile.almalinux8
   :language: docker
   :lines: 2-

Then, we add OpenMPI with :code:`examples/Dockerfile.openmpi`. This is a complex
Dockerfile that compiles several dependencies in addition to OpenMPI. For the
purposes of this tutorial, you can skip most of it, but we felt it would be
useful to show a real example.

.. literalinclude:: ../examples/Dockerfile.openmpi
   :language: docker
   :lines: 2-

So what is going on here?

1. Use the latest AlmaLinux 8 as the base image.

2. Install a basic build system using the OS package manager.

3. For a few dependencies and then OpenMPI itself:

   1. Download and untar. Note the use of variables to make adjusting the URL
      and versions easier, as well as the explanation of why we're not using
      :code:`dnf`, given that several of these packages are included in
      CentOS.

   2. Build and install OpenMPI. Note the :code:`getconf` trick to guess at an
      appropriate parallel build.

4. Clean up, in order to reduce the size of layers as well as the resulting
   Charliecloud image (:code:`rm -Rf`).

.. Finally, because it's a container image, you can be less tidy than you
   might be on a normal system. For example, the above downloads and builds in
   :code:`/` rather than :code:`/usr/local/src`, and it installs MPI into
   :code:`/usr` rather than :code:`/usr/local`.

Your software stored in the image
---------------------------------

This method covers software provided by you that is included in the image.
This is recommended when your software is relatively stable or is not easily
available to users of your image, for example a library rather than simulation
code under active development.

The general approach is the same as installing third-party software from
source, but you use the :code:`COPY` instruction to transfer files from the
host filesystem (rather than the network via HTTP) to the image. For example,
:code:`examples/mpihello/Dockerfile.openmpi` uses this approach:

.. literalinclude:: ../examples/mpihello/Dockerfile.openmpi
   :language: docker

These Dockerfile instructions:

1. Copy the host directory :code:`examples/mpihello` to the image at path
   :code:`/hello`. The host path is relative to the *context directory*, which
   is tarred up and sent to the Docker daemon. Docker builds have no access to
   the host filesystem outside the context directory.

   (Unlike the HPC custom, Docker comes from a world without network
   filesystems. This tar-based approach lets the Docker daemon run on a
   different node from the client without needing any shared filesystems.)

   The convention for Charliecloud tests and examples is that the context is
   the directory containing the Dockerfile in question, and a common pattern,
   used here, is to copy in the entire context.

2. :code:`cd` to :code:`/hello`.

3. Compile our example. We include :code:`make clean` to remove any leftover
   build files, since they would be inappropriate inside the container.

Once the image is built, we can see the results. (Install the image into
:code:`/var/tmp` as outlined above, if you haven't already.)

::

  $ ch-run /var/tmp/mpihello-openmpi.sqfs -- ls -lh /hello
  total 32K
  -rw-rw---- 1 reidpr reidpr  908 Oct  4 15:52 Dockerfile
  -rw-rw---- 1 reidpr reidpr  157 Aug  5 22:37 Makefile
  -rw-rw---- 1 reidpr reidpr 1.2K Aug  5 22:37 README
  -rwxr-x--- 1 reidpr reidpr 9.5K Oct  4 15:58 hello
  -rw-rw---- 1 reidpr reidpr 1.4K Aug  5 22:37 hello.c
  -rwxrwx--- 1 reidpr reidpr  441 Aug  5 22:37 test.sh

We will revisit this image later.

Your software stored on the host
--------------------------------

This method leaves your software on the host but compiles it in the image.
This is recommended when your software is volatile or each image user needs a
different version, for example a simulation code under active development.

The general approach is to bind-mount the appropriate directory and then run
the build inside the container. We can re-use the :code:`mpihello` image to
demonstrate this.

::

  $ cd examples/mpihello
  $ ls -l
  total 20
  -rw-rw---- 1 reidpr reidpr  908 Oct  4 09:52 Dockerfile
  -rw-rw---- 1 reidpr reidpr 1431 Aug  5 16:37 hello.c
  -rw-rw---- 1 reidpr reidpr  157 Aug  5 16:37 Makefile
  -rw-rw---- 1 reidpr reidpr 1172 Aug  5 16:37 README
  $ ch-run -b .:/mnt/0 --cd /mnt/0 /var/tmp/mpihello.sqfs -- make
  mpicc -std=gnu11 -Wall hello.c -o hello
  $ ls -l
  total 32
  -rw-rw---- 1 reidpr reidpr  908 Oct  4 09:52 Dockerfile
  -rwxrwx--- 1 reidpr reidpr 9632 Oct  4 10:43 hello
  -rw-rw---- 1 reidpr reidpr 1431 Aug  5 16:37 hello.c
  -rw-rw---- 1 reidpr reidpr  157 Aug  5 16:37 Makefile
  -rw-rw---- 1 reidpr reidpr 1172 Aug  5 16:37 README

A common use case is to leave a container shell open in one terminal for
building, and then run using a separate container invoked from a different
terminal.


Your first single-node, multi-process jobs
==========================================

This is an important use case even for large-scale codes, when testing and
development happens at small scale but need to use an environment comparable
to large-scale runs.

This tutorial covers three approaches:

1. Processes are coordinated by the host, i.e., one process per container.

2. Processes are coordinated by the container, i.e., one container with
   multiple processes, using configuration files from the container.

3. Processes are coordinated by the container using configuration files from
   the host.

In order to test approach 1, you must install OpenMPI 2.1.2 on the host.
In our experience, we have had success compiling from source with the same
options as in the Dockerfile, but there is probably more nuance to the match
than we've discovered.

Processes coordinated by host
-----------------------------

This approach does the forking and process coordination on the host. Each
process is spawned in its own container, and because Charliecloud introduces
minimal isolation, they can communicate as if they were running directly on
the host.

For example, using Slurm :code:`srun` and the :code:`mpihello` example above::

  $ stat -L --format='%i' /proc/self/ns/user
  4026531837
  $ ch-run /var/tmp/mpihello-openmpi.sqfs -- mpirun --version
  mpirun (Open MPI) 2.1.5
  $ srun -n4 ch-run /var/tmp/mpihello-openmpi.sqfs -- /hello/hello
  0: init ok cn001, 4 ranks, userns 4026554650
  1: init ok cn001, 4 ranks, userns 4026554652
  3: init ok cn002, 4 ranks, userns 4026554652
  2: init ok cn002, 4 ranks, userns 4026554650
  0: send/receive ok
  0: finalize ok

We recommend this approach because it lets you take advantage of difficult
things already done by your site admins, such as configuring Slurm.

If you don't have Slurm, you can use :code:`mpirun -np 4` instead of
:code:`srun -n4`. However, this requires that the host have a compatible
version of OpenMPI installed on the host. Which versions are compatible seems
to be a moving target, but having the same versions inside and outside the
container *usually* works.

Processes coordinated by container
----------------------------------

This approach starts a single container process, which then forks and
coordinates the parallel work. The advantage is that this approach is
completely independent of the host for dependency configuration and
installation; the disadvantage is that it cannot take advantage of host things
such as Slurm configuration.

For example::

  $ ch-run /var/tmp/mpihello-openmpi.sqfs -- mpirun -np 4 /hello/hello
  0: init ok cn001, 4 ranks, userns 4026532256
  1: init ok cn001, 4 ranks, userns 4026532256
  2: init ok cn001, 4 ranks, userns 4026532256
  3: init ok cn001, 4 ranks, userns 4026532256
  0: send/receive ok
  0: finalize ok

Note that in this case, we use :code:`mpirun` rather than :code:`srun` because
the Slurm client programs are not installed inside the container, and we don't
want the host's Slurm coordinating processes anyway.


Your first multi-node jobs
==========================

This section assumes that you are using a Slurm cluster and some type of
node-local storage. A :code:`tmpfs` will suffice, and we use :code:`/var/tmp`
for this tutorial. (Using :code:`/tmp` often works but can cause confusion
because it's shared by the container and host, yielding cycles in the
directory tree.)

We cover three cases:

1. The MPI hello world example above, run interactively, with the host
   coordinating.

2. Same, non-interactive.

3. An Apache Spark example, run interactively.

4. Same, non-interactive.

We think that container-coordinated MPI jobs will also work, but we haven't
worked out how to do this yet. (See `issue #5
<https://github.com/hpc/charliecloud/issues/5>`_.)

.. note::

   The image directory is mounted read-only by default so it can be shared by
   multiple Charliecloud containers in the same or different jobs. It can be
   mounted read-write with :code:`ch-run -w` if you are not using SquashFS.

.. warning::

   The image can reside on most filesystems, but be aware of metadata impact.
   A non-trivial Charliecloud job may overwhelm a network filesystem, earning
   you the ire of your sysadmins and colleagues.

Interactive MPI hello world
---------------------------

First, obtain an interactive allocation of nodes. This tutorial assumes an
allocation of 4 nodes (but any number should work) and an interactive shell on
one of those nodes. For example::

  $ salloc -N4

The next step is to distribute the image to the compute nodes. For SquashFS
images, this is handled by the internal mounting process; for tarballs, we run
one instance of :code:`ch-convert` on each node using :code:`srun`::

  $ srun ch-convert mpihello-openmpi.tar.gz /var/tmp/mpihello-openmpi
  input:   tar       mpihello-openmpi.tar.gz
  output:  dir       /var/tmp/mpihello-openmpi
  unpacking ...
  input:   tar       mpihello-openmpi.tar.gz
  output:  dir       /var/tmp/mpihello-openmpi
  unpacking ...
  input:   tar       mpihello-openmpi.tar.gz
  output:  dir       /var/tmp/mpihello-openmpi
  unpacking ...
  input:   tar       mpihello-openmpi.tar.gz
  output:  dir       /var/tmp/mpihello-openmpi
  unpacking ...
  done
  done
  done
  done

We can now activate the image and run our program::

  $ srun --cpus-per-task=1 ch-run /var/tmp/mpihello-openmpi.sqfs -- /hello/hello
  2: init ok cn001, 64 ranks, userns 4026532567
  4: init ok cn001, 64 ranks, userns 4026532571
  8: init ok cn001, 64 ranks, userns 4026532579
  [...]
  45: init ok cn003, 64 ranks, userns 4026532589
  17: init ok cn002, 64 ranks, userns 4026532565
  55: init ok cn004, 64 ranks, userns 4026532577
  0: send/receive ok
  0: finalize ok

Success!

Non-interactive MPI hello world
-------------------------------

Production jobs are normally run non-interactively, via submission of a job
script that runs when resources are available, placing output into a file.

The MPI hello world example includes such a script,
:code:`examples/mpi/mpihello/slurm.sh`:

.. literalinclude:: ../examples/mpihello/slurm.sh
   :language: bash

Note that this script both unpacks the image and runs it.

Submit it with something like::

  $ sbatch -N4 slurm.sh ~/mpihello-openmpi.tar.gz /var/tmp
  207745

When the job is complete, look at the output::

  $ cat slurm-207745.out
  tarball:   /home/reidpr/mpihello-openmpi.tar.gz
  image:     /var/tmp/mpihello-openmpi
  creating new image /var/tmp/mpihello-openmpi
  creating new image /var/tmp/mpihello-openmpi
  [...]
  /var/tmp/mpihello-openmpi unpacked ok
  /var/tmp/mpihello-openmpi unpacked ok
  container: mpirun (Open MPI) 2.1.5
  0: init ok cn001.localdomain, 144 ranks, userns 4026554766
  37: init ok cn002.localdomain, 144 ranks, userns 4026554800
  [...]
  96: init ok cn003.localdomain, 144 ranks, userns 4026554803
  86: init ok cn003.localdomain, 144 ranks, userns 4026554793
  0: send/receive ok
  0: finalize ok

Success!

Interactive Apache Spark
------------------------

This example is in :code:`examples/spark`. Build a tarball or SquashFS and
upload it to your cluster.

Once you have an interactive job, prepare the image. Recall that for the
SquashFS workflow this is handled by the internal mounting process.

tarball:
::

  $ srun ch-convert spark.tar.gz /var/tmp/spark
  input:   tar       spark.tar.gz
  output:  dir       /var/tmp/spark
  unpacking ...
  input:   tar       spark.tar.gz
  output:  dir       /var/tmp/spark
  unpacking ...
  done
  done


We need to first create a basic configuration for Spark, as the defaults in
the Dockerfile are insufficient. (For real jobs, you'll want to also configure
performance parameters such as memory use; see `the documentation
<http://spark.apache.org/docs/latest/configuration.html>`_.) First::

  $ mkdir -p ~/sparkconf
  $ chmod 700 ~/sparkconf

We'll want to use the cluster's high-speed network. For this example, we'll
find the Spark master's IP manually::

  $ ip -o -f inet addr show | cut -d/ -f1
  1: lo    inet 127.0.0.1
  2: eth0  inet 192.168.8.3
  8: eth1  inet 10.8.8.3

Your site support can tell you which to use. In this case, we'll use 10.8.8.3.

Create some configuration files. Replace :code:`[MYSECRET]` with a string only
you know. Edit to match your system; in particular, use local disks instead of
:code:`/tmp` if you have them::

  $ cat > ~/sparkconf/spark-env.sh
  SPARK_LOCAL_DIRS=/tmp/spark
  SPARK_LOG_DIR=/tmp/spark/log
  SPARK_WORKER_DIR=/tmp/spark
  SPARK_LOCAL_IP=127.0.0.1
  SPARK_MASTER_HOST=10.8.8.3
  $ cat > ~/sparkconf/spark-defaults.conf
  spark.authenticate true
  spark.authenticate.secret [MYSECRET]

We can now start the Spark master::

  $ ch-run -b ~/sparkconf /var/tmp/spark.sqfs -- /spark/sbin/start-master.sh

Look at the log in :code:`/tmp/spark/log` to see that the master started
correctly::

  $ tail -7 /tmp/spark/log/*master*.out
  17/02/24 22:37:21 INFO Master: Starting Spark master at spark://10.8.8.3:7077
  17/02/24 22:37:21 INFO Master: Running Spark version 2.0.2
  17/02/24 22:37:22 INFO Utils: Successfully started service 'MasterUI' on port 8080.
  17/02/24 22:37:22 INFO MasterWebUI: Bound MasterWebUI to 127.0.0.1, and started at http://127.0.0.1:8080
  17/02/24 22:37:22 INFO Utils: Successfully started service on port 6066.
  17/02/24 22:37:22 INFO StandaloneRestServer: Started REST server for submitting applications on port 6066
  17/02/24 22:37:22 INFO Master: I have been elected leader! New state: ALIVE

If you can run a web browser on the node, browse to
:code:`http://localhost:8080` for the Spark master web interface. Because this
capability varies, the tutorial does not depend on it, but it can be
informative. Refresh after each key step below.

The Spark workers need to know how to reach the master. This is via a URL; you
can get it from the log excerpt above, or consult the web interface. For
example::

  $ MASTER_URL=spark://10.8.8.3:7077

Next, start one worker on each compute node.

In this tutorial, we start the workers using :code:`srun` in a way that
prevents any subsequent :code:`srun` invocations from running until the Spark
workers exit. For our purposes here, that's OK, but it's a big limitation for
some jobs. (See `issue #230
<https://github.com/hpc/charliecloud/issues/230>`_.)

Alternatives include :code:`pdsh`, which is the approach we use for the Spark
tests (:code:`examples/other/spark/test.bats`), or a simple for loop of
:code:`ssh` calls. Both of these are also quite clunky and do not scale well.

::

  $ srun sh -c "   ch-run -b ~/sparkconf /var/tmp/spark.sqfs -- \
                          spark/sbin/start-slave.sh $MASTER_URL \
                && sleep infinity" &

One of the advantages of Spark is that it's resilient: if a worker becomes
unavailable, the computation simply proceeds without it. However, this can
mask issues as well. For example, this example will run perfectly fine with
just one worker, or all four workers on the same node, which aren't what we
want.

Check the master log to see that the right number of workers registered::

  $  fgrep worker /tmp/spark/log/*master*.out
  17/02/24 22:52:24 INFO Master: Registering worker 127.0.0.1:39890 with 16 cores, 187.8 GB RAM
  17/02/24 22:52:24 INFO Master: Registering worker 127.0.0.1:44735 with 16 cores, 187.8 GB RAM
  17/02/24 22:52:24 INFO Master: Registering worker 127.0.0.1:22445 with 16 cores, 187.8 GB RAM
  17/02/24 22:52:24 INFO Master: Registering worker 127.0.0.1:29473 with 16 cores, 187.8 GB RAM

Despite the workers calling themselves 127.0.0.1, they really are running
across the allocation. (The confusion happens because of our
:code:`$SPARK_LOCAL_IP` setting above.) This can be verified by examining logs
on each compute node. For example (note single quotes)::

  $ ssh 10.8.8.4 -- tail -3 '/tmp/spark/log/*worker*.out'
  17/02/24 22:52:24 INFO Worker: Connecting to master 10.8.8.3:7077...
  17/02/24 22:52:24 INFO TransportClientFactory: Successfully created connection to /10.8.8.3:7077 after 263 ms (216 ms spent in bootstraps)
  17/02/24 22:52:24 INFO Worker: Successfully registered with master spark://10.8.8.3:7077

We can now start an interactive shell to do some Spark computing::

  $ ch-run -b ~/sparkconf /var/tmp/spark.sqfs -- /spark/bin/pyspark --master $MASTER_URL

Let's use this shell to estimate 𝜋 (this is adapted from one of the Spark
`examples <http://spark.apache.org/examples.html>`_):

.. code-block:: pycon

  >>> import operator
  >>> import random
  >>>
  >>> def sample(p):
  ...    (x, y) = (random.random(), random.random())
  ...    return 1 if x*x + y*y < 1 else 0
  ...
  >>> SAMPLE_CT = int(2e8)
  >>> ct = sc.parallelize(xrange(0, SAMPLE_CT)) \
  ...        .map(sample) \
  ...        .reduce(operator.add)
  >>> 4.0*ct/SAMPLE_CT
  3.14109824

(Type Control-D to exit.)

We can also submit jobs to the Spark cluster. This one runs the same example
as included with the Spark source code. (The voluminous logging output is
omitted.)

::

  $ ch-run -b ~/sparkconf /var/tmp/spark.sqfs -- \
           /spark/bin/spark-submit --master $MASTER_URL \
           /spark/examples/src/main/python/pi.py 1024
  [...]
  Pi is roughly 3.141211
  [...]

Exit your allocation. Slurm will clean up the Spark daemons.

Success! Next, we'll run a similar job non-interactively.

Non-interactive Apache Spark
----------------------------

We'll re-use much of the above to run the same computation non-interactively.
For brevity, the Slurm script at :code:`examples/other/spark/slurm.sh` is not
reproduced here.

Submit it as follows. It requires three arguments: the tarball, the image
directory to unpack into, and the high-speed network interface. Again, consult
your site administrators for the latter.

::

  $ sbatch -N4 slurm.sh spark.tar.gz /var/tmp ib0
  Submitted batch job 86754

Output::

  $ fgrep 'Pi is' slurm-86754.out
  Pi is roughly 3.141393

Success! (to four significant digits)

..  LocalWords:  NEWROOT rhel oldfind oldf mem drwxr xr sig drwxrws mpihello
..  LocalWords:  openmpi rwxr rwxrwx cn cpus sparkconf MasterWebUI MasterUI
..  LocalWords:  StandaloneRestServer MYSECRET TransportClientFactory sc
