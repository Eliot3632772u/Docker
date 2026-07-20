# Docker

To understand why containers exist, we first need to understand the problems they were designed to solve.

We'll start from the beginning.

Imagine You Own One Physical Server

Suppose you buy a server with:

16 CPU cores
64 GB RAM
2 TB SSD

This is called physical hardware (bare metal).

+--------------------------------------+
|          Physical Server             |
|--------------------------------------|
| CPU: 16 cores                        |
| RAM: 64 GB                           |
| SSD: 2 TB                            |
+--------------------------------------+

Now imagine you need to run:

Website
Database
Email server
Monitoring software
Solution 1: Install Everything on One OS
Hardware
    │
Linux
 ├── Website
 ├── Database
 ├── Email
 └── Monitoring

This works...

Until one application causes problems.

Example:

Your website requires

Python 3.12

Your monitoring software requires

Python 3.8

Now they conflict.

Or:

Your database requires OpenSSL version 1.1

Your website requires OpenSSL version 3.

Again, conflict.

This is called dependency conflicts.

Another Problem

Suppose the database crashes.

Sometimes it may consume all memory.

Linux
 ├── Website  (slow)
 ├── Database (uses 60 GB RAM)
 ├── Email
 └── Monitoring

Everything becomes slow because they all share the same operating system.

Security Problem

Suppose someone hacks the website.

Since all applications are on the same OS:

Website
    │
    ▼
Operating System
    │
    ▼
Database
Email
Monitoring

The attacker might access everything.

Applications are poorly isolated.

The Idea of Virtualization

Instead of running everything inside one operating system...

People asked:

What if every application had its own operating system?

This led to Virtual Machines.

What is Virtualization?

Virtualization is the process of creating multiple virtual computers from one physical computer.

One server becomes many independent computers.

Example:

Physical Server

CPU
RAM
Disk

        │
        ▼
Hypervisor

The hypervisor divides hardware into multiple virtual machines.

What is a Hypervisor?

A hypervisor is software that creates and manages virtual machines.

It sits between hardware and virtual machines.

Applications
Operating System
----------------
Virtual Machine

Applications
Operating System
----------------
Virtual Machine

Applications
Operating System
----------------
Virtual Machine

=====================
Hypervisor
=====================

Hardware

Each VM believes it owns:

CPU
RAM
Disk
Network card

Even though they're shared.

Example

One physical server:

64 GB RAM
16 CPU

Hypervisor creates

VM1
4 CPU
16 GB

VM2
4 CPU
16 GB

VM3
4 CPU
16 GB

VM4
4 CPU
16 GB

Each VM behaves like a real computer.

Why Virtual Machines Were Revolutionary

Now every application has its own OS.

VM1
Ubuntu
Website

VM2
Windows
SQL Server

VM3
CentOS
Redis

No dependency conflicts.

No shared libraries.

No package conflicts.

Much better isolation.

Problems with Virtual Machines

Virtual machines solved many issues...

But introduced new ones.

Problem 1 — Every VM Needs an Entire Operating System

Each VM contains:

Linux Kernel
Drivers
System Libraries
Utilities
Shell
Package Manager
Services

Even if your application is only

20 MB

the VM still needs:

Ubuntu
≈ 2 GB

Application
20 MB

Total:

2.02 GB

Imagine 50 VMs.

50 × 2 GB

= 100 GB

just operating systems

Your applications may only total 1 GB.

Most storage is wasted.

Problem 2 — Huge Memory Usage

Each operating system loads into RAM.

Example:

VM1 Ubuntu
600 MB

VM2 Ubuntu
600 MB

VM3 Ubuntu
600 MB

VM4 Ubuntu
600 MB

Before your applications even start:

2.4 GB RAM

just for operating systems.

Problem 3 — Slow Boot Time

Booting a VM means booting a real operating system.

Sequence:

Power On

↓

BIOS

↓

Kernel

↓

Drivers

↓

Services

↓

Login

↓

Application

Boot time:

Often

30-90 seconds

Sometimes several minutes.

Problem 4 — CPU Overhead

Every VM thinks it owns CPUs.

The hypervisor constantly switches between VMs.

VM1
VM2
VM3
VM4

↓

Hypervisor Scheduler

↓

Physical CPU

This introduces overhead.

Problem 5 — Resource Waste

Imagine:

100 VMs

each running

Hello World

Each VM still contains

OS
Drivers
Services
Kernel

Thousands of duplicated files.

Problem 6 — Maintenance Nightmare

Suppose you have

300 VMs

Every VM needs:

OS updates
Security patches
Package updates
Firewall configuration

Instead of updating one OS...

You update 300.

Problem 7 — Poor Density

Suppose one VM uses

2 GB RAM

Your server has

64 GB

Maximum:

32 VMs

Even if every application needs only

100 MB

Most RAM is consumed by operating systems.

Why This Happened

Because every VM contains:

Application

Operating System

Kernel

The kernel is the expensive part.

Enter Containers

Someone asked:

Why are we copying Linux hundreds of times?

All Linux applications ultimately use the same kernel.

Instead of

100 kernels

What if we shared

1 kernel

This became the foundation of containers.

What is a Container?

A container is an isolated environment that contains:

Application
Dependencies
Libraries
Configuration

But shares the host operating system's kernel instead of bringing its own.

Container

Application

Libraries

Dependencies

Configuration

Notice what's missing:

Kernel
Operating System
Container Architecture
Application
Libraries
Dependencies
--------------------
Container

Application
Libraries
Dependencies
--------------------
Container

Application
Libraries
Dependencies
--------------------
Container

=======================
Container Runtime
(Docker)
=======================

Linux Kernel

Hardware

Every container shares:

Linux Kernel
Visual Comparison

Virtual Machines

App
OS
Kernel
--------
VM

App
OS
Kernel
--------
VM

Hypervisor

Hardware

Containers

App
Libraries
--------
Container

App
Libraries
--------
Container

Docker

Linux Kernel

Hardware

Huge difference.

Why Sharing the Kernel Helps

Instead of

Kernel 1

Kernel 2

Kernel 3

Kernel 4

There is only

One Linux Kernel

Memory usage drops dramatically.

Container Startup

VM

Power On

↓

Boot OS

↓

Load Kernel

↓

Load Drivers

↓

Application

30–90 seconds.

Container

Create Process

↓

Mount Filesystem

↓

Run Application

Usually:

< 1 second

Often milliseconds.

Size Comparison

Typical VM

Ubuntu
2 GB

Application
50 MB

Total

2.05 GB

Container

Libraries
80 MB

Application
50 MB

Total

130 MB

Massive difference.

Memory Comparison

100 Virtual Machines

100 × OS

100 × Kernel

Very expensive.

100 Containers

1 Kernel

100 Applications

Much smaller memory footprint.

Performance

Containers execute applications as normal processes on the host OS. Because they don't emulate hardware or boot a separate operating system, they typically have much lower overhead than virtual machines. The CPU spends more time running your application and less time managing virtualization.

But Wait...

If containers share the same kernel...

How are they isolated?

Linux provides several kernel features that make containers possible:

Namespaces isolate what a process can see (processes, network interfaces, hostnames, mount points, users, etc.).
Control groups (cgroups) limit and account for resource usage (CPU, memory, disk I/O).
Capabilities reduce the privileges available to processes.
Seccomp, AppArmor, and SELinux can further restrict what a container is allowed to do.
Union filesystems (such as OverlayFS) allow efficient layered filesystems, which makes container images small and reusable.

A container is therefore not a virtual machine. It is a group of regular OS processes that the Linux kernel isolates from the rest of the system.

Can Containers Run Different Operating Systems?

This is one of the biggest differences between containers and VMs.

A VM includes its own kernel, so you can run different operating systems on the same host:

Physical Machine

↓

Hypervisor

↓

Ubuntu VM

↓

Windows VM

↓

FreeBSD VM

A Linux container shares the Linux kernel, so it cannot run a Windows kernel. Likewise, a Windows container shares the Windows kernel and cannot run a Linux kernel directly.

If you want to run Linux containers on Windows (or vice versa), a lightweight virtual machine is typically used behind the scenes. For example, Docker Desktop uses a small Linux VM to run Linux containers on Windows.


Docker Architecture

Now let's understand every Docker component.

Docker Client

When you type

docker run nginx

you're using

docker

This is the Docker Client.

It does almost nothing.

Its only job is:

Parse your command
Convert it into an API request
Send it to Docker daemon

Think of it like a remote control.

You

↓

docker CLI

↓

dockerd
Docker Daemon (dockerd)

This is the brain of Docker.

It runs in the background.

dockerd

is always waiting.

When it receives

docker run nginx

it performs many tasks:

Pull image
Create filesystem
Configure networking
Allocate volumes
Configure namespaces
Configure cgroups
Ask containerd to create container

It is the orchestrator.

Why Doesn't dockerd Run Containers Directly?

Originally it did.

Years ago

docker CLI

↓

dockerd

↓

container

But Docker became huge.

It handled

images
networking
volumes
builds
plugins
containers

Everything.

It became difficult to maintain.

So Docker separated container management into another project.

containerd

containerd is the container runtime manager.

It knows how to

create containers
start containers
stop containers
manage snapshots
manage images
manage storage
manage OCI containers

dockerd tells containerd

Create this container.

containerd handles the rest.

Why Another Layer?

Because other software also needs containers.

For example

Kubernetes.

Kubernetes doesn't want Docker.

It wants a container runtime.

So Kubernetes talks directly to

containerd

This is why modern Kubernetes clusters commonly use containerd without dockerd.

But containerd Still Doesn't Create Processes

containerd knows containers.

Linux knows processes.

Someone must translate.

That's where

runc

comes in.

What Is runc?

runc is a very small program.

Its job is

OCI Specification

↓

Linux System Calls

It literally creates the container.

Internally it performs operations such as:

clone()
setns()
unshare()
pivot_root()
mount()
sethostname()
setuid()
execve()

These are Linux system calls that establish namespaces, mount the container filesystem, configure cgroups, and finally execute the container's main program.

runc Is Very Short-Lived

People often think

runc

stays alive.

It doesn't.

Sequence

containerd

↓

runc starts

↓

create namespaces

↓

start container

↓

runc exits

After this

runc

is gone.

Then Who Watches the Container?

If runc disappears...

Who knows when the container exits?

Who forwards signals?

Who reports exit codes?

That's the job of

containerd-shim
What Is containerd-shim?

It is a small monitor process.

Each container gets one shim.

Example

containerd

│

├── shim
│      │
│      └── nginx

├── shim
│      │
│      └── redis

├── shim
       │
       └── postgres

One shim per container.

Why Does the Shim Exist?

Imagine

containerd

crashes.

Without shim

containerd

↓

container

If containerd dies...

Container dies.

Bad.

Instead

containerd

↓

shim

↓

container

Now

Container continues running.

Even if

containerd

is restarted.

The shim stays alive, keeps the container's standard input/output streams open, tracks its exit status, and can reconnect with a restarted containerd.

Complete Flow of docker run nginx

Step 1

docker run nginx

CLI sends API request.

↓

Step 2

dockerd

receives request.

↓

Step 3

Checks image.

Downloads if missing.

↓

Step 4

Configures networking.

↓

Step 5

Creates writable layer.

↓

Step 6

Calls

containerd

↓

Step 7

containerd launches

containerd-shim

↓

Step 8

shim launches

runc

↓

Step 9

runc creates namespaces, cgroups, mounts the container filesystem, and executes the container's entrypoint.

↓

Step 10

runc exits.

↓

Step 11

shim continues supervising the container process.

Why Does docker stop Work?

Suppose inside the container

PID 1

nginx

You run

docker stop mycontainer

The flow is:

docker CLI
      │
      ▼
dockerd
      │
      ▼
containerd
      │
      ▼
containerd-shim
      │
      ▼
Send SIGTERM to container PID 1

The container's PID 1 receives SIGTERM first, giving it a chance to shut down gracefully. Docker then waits (10 seconds by default). If the process is still running, Docker sends SIGKILL, which the kernel enforces immediately and cannot be caught or ignored.

The Entire Docker Architecture
                 You
                  │
                  ▼
          docker CLI (Client)
                  │
          REST API over Unix socket
                  │
                  ▼
      +-----------------------+
      |      dockerd          |
      | Docker daemon         |
      +-----------------------+
                  │
                  ▼
      +-----------------------+
      |      containerd       |
      | Runtime manager        |
      +-----------------------+
                  │
         One shim per container
                  │
                  ▼
      +-----------------------+
      |   containerd-shim     |
      | Supervises container  |
      +-----------------------+
                  │
          Starts (then exits)
                  ▼
      +-----------------------+
      |        runc           |
      | OCI runtime           |
      +-----------------------+
                  │
                  ▼
     Linux Kernel (namespaces,
     cgroups, mounts, syscalls)
                  │
                  ▼
      Container Process (PID 1
      inside its PID namespace)

      Before Containers

Imagine a Linux server.

Linux Kernel
│
├── Process: nginx
├── Process: mysql
├── Process: redis
├── Process: sshd
├── Process: python
└── Process: java

Everything shares:

same process table
same filesystem
same network
same hostname
same users
same kernel

Every process can potentially see every other process.

For example

ps aux

shows every running process.

Network interfaces

ip addr

shows every interface.

Mounts

mount

shows every filesystem.

Hostname

hostname

returns the machine hostname.

There is no isolation.

Traditional Virtual Machines

VMs solved this by virtualizing hardware.

Physical Machine
        │
   Hypervisor
        │
 ┌──────┴────────┐
 │               │
VM1             VM2
 │               │
Kernel          Kernel
 │               │
Processes      Processes

Each VM has

its own kernel
own scheduler
own drivers
own memory manager

Very isolated.

But expensive.

Starting a VM means booting Linux.

That may take

10 seconds
30 seconds
1 minute

Memory usage:

Host

VM1
Kernel 150MB

VM2
Kernel 150MB

VM3
Kernel 150MB

Three kernels.

Containers

Containers don't virtualize hardware.

They virtualize the operating system.

Instead of

App
Kernel
Hardware

they do

App
│
Namespaces
cgroups
│
Host Kernel
│
Hardware

Everyone shares one kernel.

Container A

nginx

Container B

mysql

Container C

redis

↓

One Linux Kernel

The kernel creates the illusion that each application owns the machine.

That illusion is created by namespaces.

Namespaces

A namespace isolates one aspect of the operating system.

Think of them as different dimensions of isolation.

Linux currently supports namespaces like

PID
Mount
Network
UTS
IPC
User
Cgroup
Time

Each namespace isolates something different.

Think of Namespaces Like Separate Universes

Imagine two containers.

Container A

PID 1
PID 2
PID 3

Container B

PID 1
PID 2
PID 3

Host

PID 2480
PID 2481
PID 2482
PID 3120
PID 3121
PID 3122

Inside each namespace, processes think they are alone.

The kernel performs the translation.

PID Namespace

The PID namespace isolates process IDs.

Without it

ps aux

shows

nginx
mysqld
systemd
docker
redis
sshd
...

With PID namespace

Container

PID COMMAND

1 nginx
12 worker
13 worker

That's all.

The process cannot see host processes.

How the Kernel Does This

Every process has a real kernel PID.

Suppose

Host

PID 4831

belongs to nginx.

Inside namespace

PID 1

The kernel stores both.

Something conceptually like

Kernel Task

Host PID = 4831

Namespace PID = 1

When nginx asks

getpid()

the kernel checks

"What namespace is this process in?"

Then returns

1

not

4831

The real PID never changes.

Only the visible PID changes.

Multiple PID Namespaces
Host

PID 5300

↓

Namespace A

PID 1

↓

Namespace B

PID 1

The same process may have different visible PIDs depending on who is asking.

Mount Namespace

Mount namespace isolates the filesystem tree.

Without it

/
├── home
├── etc
├── var
└── usr

Container

/
├── app
├── bin
├── etc
└── usr

The container believes

/

is the real root.

Actually

/var/lib/docker/overlay2/...

is mounted there.

The kernel lies.

pivot_root

Docker changes the process root.

Instead of

/

becoming host root,

it becomes

container root filesystem

Everything outside disappears.

Network Namespace

Every container gets its own networking stack.

Instead of sharing

eth0
lo
docker0

each container has

lo
eth0

Different

routing table
firewall
interfaces
ports

Inside

ip addr

returns only container interfaces.

Host cannot be seen.

Virtual Ethernet (veth)

How does the container communicate?

Linux creates

veth pair

Think of it like a virtual Ethernet cable.

Container
eth0
│
│
veth
│
│
Host
vethXXXX
│
docker0 bridge
│
Internet

Packets travel through this virtual cable.

UTS Namespace

UTS = Unix Time Sharing

It isolates

hostname
domain name

Host

hostname

server01

Container

hostname

nginx

Different hostname.

Same kernel.

IPC Namespace

Processes communicate using

shared memory
semaphores
message queues

IPC namespace isolates them.

Container A cannot access

Container B's shared memory.

User Namespace

Normally

UID 0

means root.

User namespaces change that.

Container

UID 0

maps to

Host

UID 100000

So container root is not real host root.

This greatly improves security.

Cgroup Namespace

Hides the host cgroup hierarchy.

The container sees only its own control group.

Time Namespace

Processes can see different

boot times
monotonic clocks

Useful for checkpointing and restoring containers.

What are cgroups?

Namespaces isolate.

They do not limit resources.

Suppose two containers.

Container A

while(true){}

Container B

nginx

Without limits

Container A uses

100% CPU

Container B starves.

Isolation alone isn't enough.

Control Groups

A cgroup is a kernel mechanism that groups processes and applies resource policies.

Think

Processes
↓

Group

↓

Rules

Example

Container

PID 100
PID 101
PID 102

↓

Cgroup

CPU 2 cores

Memory 2GB

IO 100MB/s

Every process inside obeys those limits.

CPU Controller

Suppose

docker run --cpus=2

The kernel schedules that cgroup as if it owns only two CPUs.

Even on a 64-core machine.

Memory Controller
docker run -m 512m

Kernel tracks

allocated pages

When memory exceeds

512 MB

OOM Killer terminates a process in that cgroup.

IO Controller

Limits disk bandwidth.

Example

100 MB/sec

No matter how much the process requests.

PIDs Controller

Limits process creation.

docker run --pids-limit 100

If process 101 is created

fork()

↓

Kernel

↓

Denied

Prevents fork bombs.

Freezer Controller

Can freeze an entire cgroup.

All processes stop executing.

Useful for checkpointing.

Huge Pages

Can limit huge page usage.

Device Controller

Controls which device files are accessible.

Example

/dev/sda

Denied

GPU

Allowed

The Combination

Namespaces

What can I SEE?

cgroups

What can I USE?

Namespaces hide.

cgroups limit.

Example

Container

Can only see itself.

Can only use

2 CPUs

1GB RAM

100 PIDs
PID 1 Inside a Container

This confuses many people.

Inside Linux,

the first process is

init

Host

PID 1

systemd

or

init

Every process eventually descends from PID 1.

Docker Creates a New PID Namespace

When Docker creates a container

it creates

PID Namespace

(empty)

There are zero processes.

The first process started becomes

PID 1

Example

docker run ubuntu sleep infinity

Inside

sleep

PID 1

Not because sleep is special.

It was simply first.

Host View

Host

PID 7123

sleep infinity

Container

PID 1

sleep infinity

Same process.

Different namespace.



The Docker Workflow

A Docker container goes through several stages.

Docker Image
      │
      ▼
docker run
      │
      ▼
Container Created
      │
      ▼
Container Running
      │
      ▼
Stopped Container
      │
      ▼
Removed Container

Notice that an image and a container are different things.

Think of them like this:

Image
=====
Blueprint

Container
=========
Running building made from the blueprint

You can create many containers from one image.

Ubuntu Image
      │
 ┌────┼─────┐
 │    │     │
 ▼    ▼     ▼
C1   C2    C3
Finding Images

Docker images are usually downloaded from Docker Hub.

Search for one:

docker search nginx

Example:

NAME             DESCRIPTION
nginx            Official nginx image
nginxinc/nginx
bitnami/nginx

This does not download anything.

It only searches.

Pulling an Image

Download an image:

docker pull nginx

Output:

Using default tag: latest

latest:
Pulling from library/nginx

Digest:
...

Status:
Downloaded newer image

Now the image exists locally.

Listing Images
docker images

or

docker image ls

Example

REPOSITORY   TAG      IMAGE ID      SIZE

nginx        latest   e4d...        187MB

ubuntu       24.04    a23...         78MB

Columns

Repository

Image name

Tag

Version

Image ID

Unique identifier

Size

Compressed image size
Running a Container

The most common command in Docker.

docker run nginx

Internally Docker does:

1 Download image if needed

↓

2 Create writable layer

↓

3 Create namespaces

↓

4 Create cgroups

↓

5 Setup networking

↓

6 Start PID 1

↓

7 Container running
What Happens?

Suppose

docker run nginx

Docker checks

Do I have nginx?

If not

Download image

Then

Create container

Then

Start nginx
List Running Containers
docker ps

Example

CONTAINER ID

IMAGE

COMMAND

STATUS

PORTS

NAMES

Example

42b31...

nginx

"/docker-entry..."

Up 2 minutes

80/tcp

happy_morse

Only running containers appear.

List All Containers
docker ps -a

Now you'll see

Running

Exited

Created

containers.

Interactive Containers

Suppose you want Ubuntu as a shell.

docker run ubuntu

Nothing happens.

Why?

Ubuntu's default command finishes immediately.

Container exits.

Instead

docker run -it ubuntu bash

Now

root@f31d:/#

appears.

You are inside the container.

What do -i and -t Mean?
-i

Interactive mode.

Keeps STDIN open.

Without it

keyboard

↓

closed
-t

Allocates a pseudo terminal.

Without it

No shell experience

With it

Looks like a normal Linux terminal

Usually

-it

are used together.

Naming Containers

Without a name

adoring_hopper

happy_cat

sleepy_panini

Docker generates random names.

Specify one

docker run --name web nginx

Now

web

is the container name.

Detached Mode

Normally

docker run nginx

attaches your terminal.

Instead

docker run -d nginx

returns

c324f712...

That's the container ID.

The container runs in the background.

Why Detached Mode?

Instead of

Terminal

↓

Container

it becomes

Terminal

↓

Returns immediately

↓

Container keeps running

Perfect for servers.

Publishing Ports

Inside the container

nginx

Port 80

Host cannot access it.

Publish it.

docker run -p 8080:80 nginx

Meaning

Host

8080

↓

Container

80

Browser

localhost:8080

goes to

container:80
Multiple Port Examples
-p 3000:3000
Host 3000

↓

Container 3000
-p 8080:80
Host 8080

↓

Container 80

Publish multiple ports

docker run \
-p 8080:80 \
-p 8443:443 \
nginx
Running with Environment Variables

Applications often need configuration.

Example

docker run \
-e MYSQL_ROOT_PASSWORD=secret \
mysql

Inside container

echo $MYSQL_ROOT_PASSWORD

prints

secret
Mounting Volumes

Without a volume

Container

↓

Writes file

↓

Container deleted

↓

File gone

Instead

docker run \
-v /home/me/data:/app/data \
ubuntu

Now

Host

/home/me/data

↓

Container

/app/data

Both share files.

Executing Commands Inside a Running Container

Container already running.

Enter it.

docker exec -it web bash

Now

root@container#

appears.

This does NOT restart the container.

It creates another process.

PID1 nginx

↓

exec

↓

bash
Running One Command

Instead of

bash

run

docker exec web ls /

Output

bin

etc

usr

var

Container keeps running.

Viewing Logs

Applications write to stdout/stderr.

Docker captures them.

docker logs web

Follow live

docker logs -f web

Equivalent to

tail -f
Stopping Containers

Graceful stop

docker stop web

Internally

SIGTERM

↓

wait 10 sec

↓

SIGKILL if needed
Starting Again
docker start web

Starts existing container.

No recreation.

Restart
docker restart web

Equivalent

stop

↓

start
Killing Immediately
docker kill web

Sends

SIGKILL

No cleanup.

Removing Containers

Container must be stopped.

docker rm web

Deletes

writable layer
metadata

Image stays.

Remove Running Container

Force removal

docker rm -f web

Equivalent

kill

↓

remove
Remove Images
docker rmi nginx

Deletes image.

Containers using it must be removed first.

Inspecting Containers

Everything Docker knows

docker inspect web

Huge JSON

Contains

Network

Mounts

IP

PID

Image

State

Labels

Volumes

Environment
Container Statistics

Real-time usage

docker stats

Shows

CPU

Memory

Network

Disk IO

continuously.

Viewing Processes
docker top web

Example

PID

USER

COMMAND

1 nginx

22 worker

23 worker

These are the processes running inside the container (as seen from the container's process namespace), making it useful for understanding what your application has started.

Copying Files

Host → Container

docker cp file.txt web:/tmp/

Container → Host

docker cp web:/etc/nginx/nginx.conf .
Docker Run vs Docker Start

This is one of the most common beginner mistakes.

docker run

Creates and starts a new container.

Image

↓

Create Container

↓

Start

Every execution creates another container.

docker run ubuntu
docker run ubuntu
docker run ubuntu

Three different containers.

docker start

Starts an existing stopped container.

Stopped Container

↓

Running

No new container is created.

Docker Create

Less commonly used.

docker create nginx

Creates

Image

↓

Container

But does not start it.

Later

docker start <container>

starts it.

Docker Attach

Reconnect to the main process's terminal.

docker attach web

Different from

docker exec

because attach connects to the original process's standard input/output, while exec starts an entirely new process inside the container.

Understanding Container States
Created
   │
   ▼
Running
   │
   ▼
Paused
   │
   ▼
Running
   │
   ▼
Exited
   │
   ▼
Removed

Commands move containers between these states:

Command	Effect
docker create	Creates a new container but does not start it
docker run	Creates and starts a new container
docker stop	Gracefully stops a running container
docker start	Starts an existing stopped container
docker restart	Stops then starts a container
docker kill	Immediately terminates a running container
docker rm	Removes a stopped container
docker rm -f	Forces a running container to stop and removes it
A Complete Example

Suppose you want to run an Nginx web server.

# Download the image
docker pull nginx

# Verify it's available
docker images

# Run it in the background with a name and published port
docker run -d --name my-nginx -p 8080:80 nginx

# Verify it's running
docker ps

# View its logs
docker logs my-nginx

# Open a shell inside the container
docker exec -it my-nginx bash

# Exit the shell (the container keeps running)
exit

# Monitor resource usage
docker stats

# Stop the container
docker stop my-nginx

# Start it again
docker start my-nginx

# Remove it when you're finished
docker stop my-nginx
docker rm my-nginx


What is a Docker Image?

A Docker image is an immutable, read-only filesystem that contains everything needed to run an application.

It includes:

Operating system files (usually a minimal Linux distribution)
Application binaries
Libraries
Dependencies
Configuration
Environment variables
Metadata
Startup command

An image is not running.

It is simply a package.

For example:

Ubuntu Image

/
├── bin/
├── usr/
├── lib/
├── etc/
├── home/
└── ...

Another image:

Nginx Image

/
├── nginx binary
├── nginx.conf
├── HTML files
├── libraries
└── startup script

Another:

Python Image

/
├── python3
├── pip
├── standard library
├── SSL libraries
└── ...

The image is nothing more than a filesystem plus metadata.

Why Docker Uses Images

Suppose you want to run nginx.

Without Docker:

Install Linux
↓

Install nginx

↓

Install dependencies

↓

Configure nginx

↓

Start nginx

Repeat this on every server.

Instead Docker creates one image:

Nginx Image

Contains

Linux
+
nginx
+
configuration
+
dependencies

Now every server simply downloads it.

docker run nginx

Done.

No installation.

No configuration.

Everything is already inside.

Images are Read-Only

One of the most important concepts.

A Docker image never changes.

Imagine:

Ubuntu Image

/bin
/usr
/etc

You run

docker run ubuntu

Docker does NOT modify the image.

Instead it creates

Ubuntu Image
      +
Writable Container Layer
Image
(Read Only)

──────────────

Container Layer
(Read Write)

If you create a file

touch hello.txt

it is stored only inside

Container Layer

The original image remains untouched.

Image vs Container

Image

Static

Read-only

Template

Cannot execute

Container

Running

Read-write

Has processes

Can be modified

Example

Ubuntu Image

↓

Container 1

↓

Container 2

↓

Container 3

Three containers can use the same image simultaneously.

What's Actually Inside an Image?

Example:

python:3.12

Internally

/

bin/
usr/
lib/
etc/

python

pip

ssl libraries

ca certificates

timezone files

Python stdlib

metadata

startup command

Nothing magical.

Just files.

Image Architecture

Every image consists of two parts

Filesystem

+

Metadata

Filesystem:

/

bin

usr

etc

home

var

application

Metadata:

Default command

Environment variables

Working directory

Exposed ports

Entrypoint

Author

Labels

Example

Image

Filesystem

/bin/bash

/usr/bin/python

/lib

...

Metadata

CMD ["python"]

ENV PATH=...

WORKDIR /app
Where Images are Stored

Docker stores images locally.

Linux:

/var/lib/docker/

Inside you'll find

overlay2/

image/

containers/

volumes/

The image files are stored under

/var/lib/docker/image/

while the actual filesystem layers are stored in

overlay2/
Image IDs

Every image has a SHA256 hash.

Example

sha256:

6d7d3f65aafcb6...


Docker shortens it

6d7d3f65aafc

Example

docker images
REPOSITORY TAG IMAGE ID

ubuntu latest 6d7d3f65aafc
nginx latest 2c7a2d1d22dd
python 3.12 91f7a0f8a13d

The Image ID uniquely identifies the image contents.

Image Naming

Images have names like

ubuntu

nginx

python

redis

But internally Docker expands them.

Example

ubuntu

actually means

docker.io/library/ubuntu:latest

Let's break this down.

Full Image Name Format
REGISTRY/REPOSITORY:TAG

Example

docker.io/library/ubuntu:latest

Pieces

docker.io

Registry

library

Namespace

ubuntu

Repository

latest

Tag

Example

ghcr.io/user/myapp:v2

Registry

ghcr.io

Namespace

user

Repository

myapp

Tag

v2
Registry

A registry is simply a server that stores Docker images.

Like GitHub stores Git repositories.

Registry

GitHub

↓

Repositories

Docker Registry

Docker Hub

↓

Image repositories

Popular registries

Docker Hub

docker.io

GitHub Container Registry

ghcr.io

Google

gcr.io

AWS

public.ecr.aws

Azure

mcr.microsoft.com

Example

docker pull nginx

Docker contacts

docker.io

Downloads image

Stores locally.

Repository

Repository groups multiple versions of one application.

Example

ubuntu

Contains

20.04

22.04

24.04

latest

Think

Repository

ubuntu

├──22.04
├──24.04
├──latest
Tags

A tag represents a version.

Examples

python:3.10

python:3.11

python:3.12

python:latest

Repository

python

Tags

3.10

3.11

3.12

latest

Avoid using

latest

in production.

Because tomorrow

latest

might point to a completely different version.

Instead use

python:3.12.4

ubuntu:24.04

nginx:1.27
What Happens During docker pull

Suppose

docker pull nginx

Docker performs roughly these steps:

CLI

↓

Docker Daemon

↓

Registry

↓

Download manifest

↓

Download missing layers

↓

Verify SHA256 hashes

↓

Store locally

If some layers already exist locally, Docker downloads only the missing ones.

Image Layers

This is one of Docker's greatest innovations.

A Docker image is not one giant file.

Instead it is composed of many read-only layers stacked together.

Imagine:

Image

──────────────
Layer 5

──────────────
Layer 4

──────────────
Layer 3

──────────────
Layer 2

──────────────
Layer 1

Each layer contains only the changes introduced at that step.

Example: Building an Image

Suppose this Dockerfile:

FROM ubuntu:24.04
RUN apt update
RUN apt install python3
COPY app.py /app/
CMD ["python3", "/app/app.py"]

Each instruction creates a new layer (except some metadata-only instructions):

Layer 5
CMD

────────────

Layer 4
COPY app.py

────────────

Layer 3
Install Python

────────────

Layer 2
apt update cache

────────────

Layer 1
Ubuntu filesystem

Together they form the final image.

Layer Reuse

Imagine two images:

Image A

Ubuntu

↓

Python

↓

Flask App

Image B

Ubuntu

↓

Python

↓

FastAPI App

Both share the first two layers.

Ubuntu

↓

Python

↓

App A

App B

Docker stores the shared layers only once, saving both disk space and download time.

Copy-on-Write

When you start a container:

Image Layers

(Read Only)

↓

Writable Layer

If the application modifies a file:

Image

/etc/config

↓

Writable Layer

Modified version

The original image layer remains unchanged. The writable layer "overrides" the file for that container. This mechanism is called copy-on-write.

Basic Commands to Work with Images
List local images
docker images

or

docker image ls

Example:

REPOSITORY   TAG      IMAGE ID       CREATED       SIZE
ubuntu       24.04    abc123def456   2 weeks ago   78MB
nginx        latest   def456abc789   3 days ago    193MB
Download an image
docker pull ubuntu

Specific version:

docker pull ubuntu:24.04
Remove an image
docker rmi ubuntu:24.04

or

docker image rm ubuntu:24.04

If a container still depends on the image, Docker will prevent its removal unless you remove the container first (or force the deletion).

Inspect an image
docker image inspect ubuntu:24.04

Shows detailed JSON metadata, including:

Image ID
Parent layers
Environment variables
Entrypoint
Default command (CMD)
Architecture
Operating system
Creation time
Show image history
docker history ubuntu:24.04

Example:

IMAGE          CREATED        CREATED BY
abc123         2 weeks ago    /bin/sh -c #(nop) CMD ["bash"]
def456         2 weeks ago    /bin/sh -c apt-get update
ghi789         2 weeks ago    FROM scratch

This reveals the layers that make up the image and how they were created.

Search for images
docker search nginx

Example output:

NAME          DESCRIPTION
nginx         Official nginx image
bitnami/nginx Bitnami nginx image
linuxserver/nginx Community image
Tag an image

Tags let you assign another name or version to an existing image.

docker tag myapp:latest myapp:v1

Both tags point to the same image ID until one is rebuilt.

Save an image to a file
docker save -o ubuntu.tar ubuntu:24.04

This creates a portable archive containing the image and all its layers.

Load an image from a file
docker load -i ubuntu.tar

This restores the saved image into your local Docker image store.

A Complete Example
# Download Ubuntu
docker pull ubuntu:24.04

# Verify it exists locally
docker images

# Inspect its metadata
docker image inspect ubuntu:24.04

# View the image's layers
docker history ubuntu:24.04

# Start a container from the image
docker run -it ubuntu:24.04 bash

# Exit the container
exit

# Remove the stopped container (replace <container_id>)
docker rm <container_id>

# Remove the image
docker rmi ubuntu:24.04


Why Containers Need Networking

Imagine you have three containers:

+----------------+
| Frontend       |
+----------------+

+----------------+
| Backend API    |
+----------------+

+----------------+
| PostgreSQL     |
+----------------+

Questions immediately arise:

How does the frontend contact the backend?
How does the backend contact PostgreSQL?
Can containers access the Internet?
Can your laptop access a container?
Can containers communicate across machines?

Docker networking answers all of these.

Every Container Has Its Own Network Namespace

Earlier we discussed Linux namespaces.

A container gets its own:

PID namespace
Mount namespace
User namespace
Network namespace

The network namespace isolates:

interfaces
routing table
ARP table
firewall rules
ports

Inside a container:

ip addr

might show

lo
eth0

while the host has

lo
eth0
docker0
vethxxxx

The container cannot see the host interfaces.

It only sees its own.

Think of a Network Namespace Like a Separate Computer

Imagine three physical computers.

Computer A

eth0
192.168.1.10

-------------------

Computer B

eth0
192.168.1.11

-------------------

Computer C

eth0
192.168.1.12

A container looks exactly like this.

Each container believes:

"I own this network stack."

It has

its own IP
routing table
interfaces
localhost
localhost is Private

This surprises many beginners.

Container A:

localhost
127.0.0.1

Container B:

localhost
127.0.0.1

Host:

localhost
127.0.0.1

These are three different localhost interfaces.

Host localhost
        |
        X

Container A localhost

Container B localhost

They are isolated.

How Docker Connects Containers

Docker creates a virtual Ethernet pair.

This is called a veth pair.

Imagine a cable.

Container
     |
   eth0
     |
===========
Virtual cable
===========
     |
veth1234
Host

One end lives inside the container.

The other stays on the host.

Virtual Ethernet Pair

Think of it like this:

Container

eth0
|
|
=========================
Virtual Ethernet Pair
=========================
|
|
vethab23

Host

Packets entering one side appear instantly on the other.

It behaves like a network cable.

Docker Bridge

Docker creates a virtual switch called

docker0

You can inspect it:

ip addr show docker0

Example:

docker0

172.17.0.1/16

It acts exactly like a network switch.

                docker0

          +----------------+
          | Virtual Switch  |
          +----------------+

          /      |      \

      veth1   veth2   veth3

        |        |       |

     Container1 Container2 Container3

Every container plugs into this switch.

Packet Flow

Suppose

Container A

172.17.0.2

wants to reach

Container B

172.17.0.3

Packet path:

Container A

eth0

↓

vethA

↓

docker0 bridge

↓

vethB

↓

eth0

↓

Container B

Docker isn't copying packets itself.

Linux networking forwards them.

Docker simply creates the topology.

Internet Access

Suppose Container A wants Google.

curl google.com

Flow:

Container

↓

docker0

↓

Host

↓

Host eth0

↓

Internet

Docker configures NAT (Network Address Translation) using iptables (or the system's firewall backend) so that outbound traffic from container IPs is translated to the host's IP before leaving the machine. Replies are translated back to the originating container.

Container

172.17.0.2

↓

Host NAT

↓

192.168.1.50

↓

Internet

The outside world only sees the host.

Container IP Addresses

Every container gets an IP.

Example:

Container A

172.17.0.2

Container B

172.17.0.3

Container C

172.17.0.4

Docker automatically allocates them.

The Default Bridge Network

Run

docker network ls

You might see

NETWORK ID      NAME      DRIVER

bridge          bridge    bridge

host            host

none            null

The default bridge already exists.

Why the Default Bridge Isn't Ideal

Containers on the default bridge network can communicate by IP address, but they do not automatically get DNS-based name resolution for one another. That means using container names like db or backend won't work automatically on the default bridge.

Docker recommends creating your own bridge network.

User-Defined Bridge

Create one:

docker network create my-network

Run containers:

docker run -d --network my-network --name db postgres
docker run -d --network my-network --name api my-api

Now

api

can simply connect to

db

No IP address needed.

Docker DNS

This is one of Docker's best features.

Inside a user-defined bridge network Docker runs an embedded DNS service.

api

asks:

Where is db?

↓

Docker DNS

↓

172.20.0.2

Applications use names instead of IPs.

Example:

jdbc:postgresql://db:5432/app

instead of

jdbc:postgresql://172.20.0.2:5432/app
Multiple Networks

A container can belong to multiple networks.

              frontend-net

Frontend ------------+

                      |

                    Backend

                      |

Database ------------+

             backend-net

Backend acts as the bridge.

Frontend cannot access Database directly.

Published Ports

Containers are isolated.

Without publishing,

localhost:8080

on your host cannot reach

Container:8080

Publish a port:

docker run -p 8080:80 nginx

Meaning:

Host Port

8080

↓

Container Port

80

Browser:

localhost:8080

↓

Container:80
Port Mapping
Host

8080

↓

Docker NAT

↓

Container

80

Only published ports are reachable from outside the Docker host.

Expose vs Publish

Dockerfile

EXPOSE 8080

This

does NOT

publish the port.

It simply documents

"This application listens on 8080."

Publishing is

-p
Docker Network Drivers

Drivers define how networking behaves.

Bridge

Host

None

Overlay

Macvlan

Ipvlan

Each serves a different purpose.

1. Bridge Driver

Most common.

docker network create mynet

Creates

Linux Bridge

↓

Virtual Switch

↓

Containers

Perfect for:

Web app
Database
Redis
Backend
Local development
Bridge Example
        docker bridge

      +--------------+

      |              |

API               PostgreSQL

      |              |

172.20.0.2      172.20.0.3
2. Host Driver
docker run --network host nginx

No network namespace isolation.

Container uses host network directly.

Host

eth0

↓

Container

same network

No bridge.

No NAT.

No port publishing.

If nginx listens on

80

Host now listens on

80

Advantages:

Fastest
No translation
Low latency

Disadvantages:

Less isolation
Port conflicts
Linux-only in the traditional sense (Docker Desktop behaves differently)
3. None Driver
docker run --network none

Container has

lo

only.

No Internet.

No bridge.

No DNS.

No communication.

Useful for:

Highly isolated workloads
Security experiments
Manually configuring networking
4. Overlay Driver

For Docker Swarm or multi-host container networking.

Machine A

API

↓

Overlay Network

↓

Machine B

Database

Containers behave as though they are on one logical network even when running on different hosts.

5. Macvlan Driver

Container receives its own MAC address and appears as a separate physical device on the LAN.

Router

|

Switch

|

---------------------

Host

Container A

Container B

Container C

Each container has

its own MAC
its own IP from the LAN

Useful for legacy applications that expect to be directly reachable on the physical network.

6. IPvlan Driver

Similar to Macvlan but shares the host's MAC address while assigning different IP addresses.

Useful in environments where many MAC addresses are undesirable.

Docker Network Commands
List networks
docker network ls
Inspect a network
docker network inspect bridge

Shows:

subnet
gateway
driver
connected containers
options
Create network
docker network create mynet

Specify a subnet if needed:

docker network create \
  --driver bridge \
  --subnet 172.30.0.0/16 \
  mynet
Remove network
docker network rm mynet

The network must not have attached containers.

Connect a running container
docker network connect mynet api

The container gains another network interface.

Disconnect
docker network disconnect mynet api
Run on a network
docker run --network mynet nginx
View container networking
docker inspect container_name

Look under:

NetworkSettings

You will find:

IP address
Gateway
MAC address
Networks
Published ports

Part 1: Why Docker Needs a Storage System

Imagine running Ubuntu normally.

Ubuntu
│
├── /etc
├── /usr
├── /var
├── /home
└── ...

Everything is stored directly on the disk.

Now imagine Docker.

You may have

100 Ubuntu containers

If every container had its own complete filesystem:

Ubuntu #1 -> 600 MB
Ubuntu #2 -> 600 MB
Ubuntu #3 -> 600 MB
...
Ubuntu #100 -> 600 MB

Total:

60 GB

Most of those files are identical.

Docker avoids this enormous waste.

Instead it shares the read-only image between containers and only stores the differences.

This is called a copy-on-write layered filesystem.

Part 2: Docker's Storage Architecture

A container filesystem consists of multiple layers.

                 Container

           Writable Layer
                 ▲
                 │
         --------------------
         Image Layer 3
         Image Layer 2
         Image Layer 1
         Base OS Layer

Everything below the writable layer is read-only.

Only the top layer changes.

For example

Ubuntu image

Layer 1
--------

/

Layer 2
--------

/bin

Layer 3
--------

/etc

Layer 4
--------

/usr

When a container starts, Docker adds

Writable Layer

on top.

So the container sees

Writable
↑
Layer 4
↑
Layer 3
↑
Layer 2
↑
Layer 1

as one filesystem.

Part 3: Where Docker Stores Everything

On Linux Docker stores nearly everything inside

/var/lib/docker/

Example

/var/lib/docker

├── containers/
├── image/
├── network/
├── overlay2/
├── plugins/
├── swarm/
├── tmp/
├── volumes/
└── buildkit/

Each directory has a different responsibility.

containers/

Contains runtime information.

Example

containers/

    abc123/
        config.v2.json
        hostconfig.json
        hostname
        hosts
        resolv.conf

This is NOT where the container filesystem lives.

Only metadata.

image/

Stores image metadata.

Things like

ubuntu:24.04

↓

Layer A
Layer B
Layer C

Docker needs to remember

tags
manifests
layer hashes
repositories
network/

Stores network configuration.

Bridge networks

Overlay networks

IP allocation

volumes/

Stores Docker managed volumes.

We'll cover these later.

overlay2/

This is where almost all image and container filesystem data lives.

This is the heart of Docker storage.

Part 4: What is OverlayFS?

Docker uses a Linux filesystem called

OverlayFS

Docker's implementation is

overlay2

OverlayFS merges multiple directories into one filesystem.

Imagine

Lower Directory A

/etc
/usr
/bin

Another

Lower Directory B

/home

Upper directory

tmp/

OverlayFS combines them into

Merged

/etc
/usr
/bin
/home
tmp

Applications think it's one filesystem.

Actually it's multiple directories merged together.

Part 5: overlay2 Directory

Suppose we pull Ubuntu.

docker pull ubuntu

Docker creates

/var/lib/docker/overlay2/

Inside you'll see directories with long IDs.

Example

overlay2/

a3f98f...

bb281c...

f6d77...


Each directory represents one filesystem layer.

Each layer contains things like

diff/
link
lower
merged
work

Let's explain each.

diff/

Contains the actual files introduced by that layer.

Example

diff/

bin/
etc/
usr/
var/

Suppose Layer 3 adds

/etc/nginx/nginx.conf

That file exists only inside

diff/
lower

Lists parent layers.

Example

lower

↓

layerA
layerB
layerC

OverlayFS uses this to know which layers to stack.

merged/

This is the mounted filesystem.

The container actually sees

merged/

If you

docker exec

ls /

you're looking at

merged/
work/

Internal OverlayFS workspace.

Linux requires it.

Users never interact with it.

link

Short identifier used internally.

Example of Image Layers

Suppose Dockerfile

FROM ubuntu

RUN apt update

RUN apt install nginx

COPY index.html /var/www/html

Docker creates

Layer 1

Ubuntu
Layer 2

apt update
Layer 3

nginx
Layer 4

index.html

Each one has its own folder inside overlay2.

Part 6: Creating a Container

Run

docker run ubuntu

Docker creates another layer.

Ubuntu Layer
↓

Writable Layer

Container

Container

Writable Layer

↓

Ubuntu Layer

The writable layer is also stored inside overlay2.

Part 7: Copy-on-Write

Suppose

Image

/etc/file.txt

contains

Hello

Container starts.

No file exists in writable layer.

Filesystem

Writable

(empty)

↓

Image

Hello

Application reads

Hello

Now edit

echo Hi > /etc/file.txt

Docker does NOT modify image.

Instead

Writable Layer

/etc/file.txt

Hi

Image still contains

Hello

The writable layer hides the original.

This is Copy-on-Write.

Reading

Read sequence

Application

↓

Writable layer

↓

Image Layer 3

↓

Image Layer 2

↓

Image Layer 1

Stops when file is found.

Writing

Write sequence

Application

↓

Writable layer

Always.

Never directly to image layers.

Part 8: What Happens When Container is Deleted?

Suppose

touch data.txt

inside container.

That file exists only in writable layer.

Remove container

docker rm

Writable layer deleted.

data.txt

gone forever.

This surprises many beginners.

Part 9: Why Volumes Exist

Containers are disposable.

Applications often are not.

Example

MySQL

stores

customers

orders

payments

If container removed

docker rm mysql

Without persistent storage

All database lost

This is why Docker volumes exist.

Part 10: Docker Volumes

A Docker volume is a directory stored outside the container's writable layer.

Instead of

Container Writable Layer

database.db

we have

Volume

database.db

Container

Container

↓

Volume

Deleting the container leaves the volume untouched.

Where Volumes Live

By default

/var/lib/docker/volumes/

Example

volumes/

myvolume/

    _data/

Your files are inside

_data
Example

Create

docker volume create dbdata

Directory

/var/lib/docker/volumes/

dbdata/

    _data/

Run

docker run \
-v dbdata:/var/lib/mysql \
mysql

Everything written into

/var/lib/mysql

actually goes into

dbdata/_data
Volume Mount Process
Host

/var/lib/docker/volumes/dbdata/_data

↓

Mounted

↓

Container

/var/lib/mysql

The application never knows.

Why Volumes are Faster

Writing to

Writable Layer

requires OverlayFS.

OverlayFS must

check layers
perform copy-on-write
maintain metadata

Volumes write directly to the host filesystem.

Less overhead.

Part 11: Types of Docker Mounts

Docker supports three primary mount types.

1. Named Volumes

Docker manages everything.

Example

docker volume create mydata

docker run \
-v mydata:/app/data

Host

/var/lib/docker/volumes/mydata/_data

Advantages

Docker-managed
Portable
Easy backups
Preferred for databases and application data
2. Anonymous Volumes

Created automatically when you mount a container path without a name.

Example:

docker run -v /app/data nginx

Docker creates a volume with a random name, such as:

8f6e9d4c...

These are useful when an image declares a VOLUME and you don't care about the volume's name. The downside is they are easy to forget and can accumulate over time if not cleaned up.

Inspect them with:

docker volume ls

Remove unused anonymous volumes with:

docker volume prune
3. Bind Mounts

A bind mount maps an existing host directory or file directly into the container.

Example

docker run \
-v /home/user/project:/app

or the modern syntax:

docker run \
--mount type=bind,source=/home/user/project,target=/app
Host

/home/user/project

↓

Container

/app

Advantages

Live editing of files from the host.
Ideal for development.
Easy to inspect with normal host tools.

Disadvantages

Ties the container to a specific host path.
Less portable.
Containers can accidentally modify or delete host files unless mounted read-only.
Modern --mount Syntax

Although -v is shorter, Docker recommends --mount because it's more explicit.

Named volume:

docker run \
--mount type=volume,source=mydata,target=/data

Bind mount:

docker run \
--mount type=bind,source=/home/user/project,target=/app

Read-only bind mount:

docker run \
--mount type=bind,source=/etc/config,target=/config,readonly
Part 12: Volumes vs Bind Mounts vs Writable Layer
Feature	Writable Layer	Named Volume	Anonymous Volume	Bind Mount
Persists after container removal	❌	✅	✅ (until removed)	✅
Docker-managed	N/A	✅	✅	❌
Stored under /var/lib/docker/volumes	❌	✅	✅	❌
Shares data with host	Indirect	Indirect	Indirect	Direct
Best for	Temporary container changes	Databases, application data	Temporary persistent data	Development, configuration, logs
Performance	Good, but OverlayFS overhead	Excellent	Excellent	Excellent
Part 13: Volume Lifecycle

Create:

docker volume create mydata

List:

docker volume ls

Inspect:

docker volume inspect mydata

Use:

docker run -v mydata:/data alpine

Remove:

docker volume rm mydata

Remove all unused volumes:

docker volume prune

A volume can outlive many containers. You can delete a container, create a new one, mount the same volume, and all the previous data will still be there.