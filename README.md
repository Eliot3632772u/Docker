# The Complete Docker Guide: From Bare Metal to Compose

A from-first-principles, no-topic-skipped guide to Docker — starting from why containers exist at all, down through Linux kernel primitives, the Docker engine's internal architecture, images, networking, storage, Dockerfiles, and Docker Compose.

---

## Table of Contents

1. [Why Containers Exist](#1-why-containers-exist)
2. [The Virtualization Era](#2-the-virtualization-era)
3. [Introduction to Containers](#3-introduction-to-containers)
4. [Linux Isolation Primitives: Namespaces](#4-linux-isolation-primitives-namespaces)
5. [Linux Resource Control: cgroups](#5-linux-resource-control-cgroups)
6. [Additional Security Layers](#6-additional-security-layers)
7. [Docker Engine Architecture](#7-docker-engine-architecture)
8. [Docker Images — Concepts](#8-docker-images--concepts)
9. [Image Commands](#9-image-commands)
10. [Container Lifecycle & Core Commands](#10-container-lifecycle--core-commands)
11. [Docker Networking](#11-docker-networking)
12. [Docker Storage Engine](#12-docker-storage-engine)
13. [Docker Volumes](#13-docker-volumes)
14. [Dockerfiles — Building Images](#14-dockerfiles--building-images)
15. [Docker Compose — Fundamentals](#15-docker-compose--fundamentals)
16. [Compose Services — Full Reference](#16-compose-services--full-reference)
17. [Compose Volumes — Full Reference](#17-compose-volumes--full-reference)
18. [Compose Networks — Full Reference](#18-compose-networks--full-reference)
19. [Putting It All Together](#19-putting-it-all-together)

---

## 1. Why Containers Exist

To actually understand Docker — not just memorize its commands — you have to understand the problem it was built to solve. Docker is a *response* to a specific set of pains that predate it by decades. If you skip this part, every later design decision (why containers share a kernel, why images are layered, why namespaces exist) will feel arbitrary instead of inevitable.

### You own one physical server

Imagine you buy a single machine:

```
+--------------------------------------+
|          Physical Server             |
|--------------------------------------|
| CPU: 16 cores                        |
| RAM: 64 GB                           |
| SSD: 2 TB                            |
+--------------------------------------+
```

This is **bare metal** — real, physical hardware with no abstraction layer between your applications and the silicon.

Now suppose you need to run four things on it: a website, a database, an email server, and some monitoring software.

### Solution 1: install everything on one OS

The naive approach is to install one Linux system and run all four applications as processes on top of it:

```
Hardware
    │
Linux
 ├── Website
 ├── Database
 ├── Email
 └── Monitoring
```

This works fine — right up until it doesn't. Three categories of problems show up almost immediately.

**Dependency conflicts.** Your website might require Python 3.12, but your monitoring software was written against Python 3.8. Your database needs OpenSSL 1.1, but your website's framework needs OpenSSL 3. Both applications are installed system-wide, so there is no way for two different major versions of the same library to coexist. You are forced into version compromises that satisfy no one.

**Resource contention.** All four applications share the same CPU scheduler, the same RAM, and the same disk I/O queue. If the database crashes into a memory leak and balloons to 60 GB of RAM usage, the website, email server, and monitoring tool all slow down together, because they're all fighting over the same finite pool of resources:

```
Linux
 ├── Website  (slow)
 ├── Database (uses 60 GB RAM)
 ├── Email
 └── Monitoring
```

There is no wall between them. One badly-behaved process can degrade everything else running on the box.

**Security exposure.** If an attacker compromises the website, they don't just compromise the website — they compromise a process running on the *same operating system* as your database, your email server, and your monitoring stack. Because there is no isolation boundary between applications, a single vulnerability can become a total breach:

```
Website
    │
    ▼
Operating System
    │
    ▼
Database
Email
Monitoring
```

These three problems — dependency conflicts, resource contention, and weak security isolation — are the entire reason the rest of this guide exists. Every technology covered below, from hypervisors to namespaces to cgroups, is ultimately an attempt to solve one or more of these three problems.

---

## 2. The Virtualization Era

The first serious attempt to solve the isolation problem was **virtualization**: instead of running every application inside one shared operating system, give every application its own operating system.

### What is virtualization?

Virtualization is the process of creating multiple virtual computers out of one physical computer. One server becomes many independent-seeming computers, each of which believes it owns the hardware exclusively.

```
Physical Server

CPU
RAM
Disk

        │
        ▼
Hypervisor
```

### What is a hypervisor?

A **hypervisor** is software that creates and manages virtual machines. It sits directly between the physical hardware and the virtual machines, dividing up CPU time, memory, and disk into slices that each VM believes it owns exclusively:

```
Applications          Applications          Applications
Operating System      Operating System      Operating System
----------------      ----------------      ----------------
Virtual Machine       Virtual Machine       Virtual Machine

=====================================================
                     Hypervisor
=====================================================

                      Hardware
```

Each VM believes it owns a CPU, RAM, a disk, and a network card — even though all of that hardware is actually shared and time-sliced by the hypervisor underneath it.

For example, a single 64 GB / 16-core server could be divided by the hypervisor into four VMs of 4 CPUs and 16 GB RAM each. Each of those VMs behaves, from the inside, exactly like a standalone physical computer.

### Why VMs were revolutionary

With virtualization, every application finally gets its own complete operating system:

```
VM1 → Ubuntu   → Website
VM2 → Windows  → SQL Server
VM3 → CentOS   → Redis
```

This solves the dependency-conflict problem outright — there are no shared libraries between VMs, so there are no package conflicts, and it provides much stronger isolation than the "everything on one OS" model. A compromised VM does not automatically hand an attacker access to the other VMs.

### The problems virtual machines introduced

VMs solved the isolation problem, but they solved it at an enormous, compounding cost. This cost shows up in seven distinct ways.

**Problem 1 — every VM needs an entire operating system.** Each VM contains a full Linux kernel, drivers, system libraries, utilities, a shell, a package manager, and background services. Even if your actual application is only 20 MB, the VM still has to carry an entire Ubuntu install (roughly 2 GB) around with it:

```
Ubuntu  ≈ 2 GB
Application  ≈ 20 MB
------------------------
Total  ≈ 2.02 GB
```

Multiply that by 50 VMs and you get roughly 100 GB spent purely on duplicated operating systems — even though the applications themselves might only total 1 GB combined. The overwhelming majority of that storage is waste.

**Problem 2 — huge memory usage.** Every operating system has to be loaded fully into RAM before your application even starts. Four VMs each running a 600 MB Ubuntu kernel footprint means 2.4 GB of RAM is consumed before a single line of application code executes.

**Problem 3 — slow boot time.** Starting a VM means booting a real, complete operating system from scratch:

```
Power On → BIOS → Kernel → Drivers → Services → Login → Application
```

This routinely takes 30–90 seconds, and sometimes several minutes — a serious problem if you want to scale up capacity quickly in response to traffic.

**Problem 4 — CPU overhead.** Every VM believes it owns CPU cores outright. In reality, the hypervisor is constantly context-switching between VMs, scheduling each one's virtual CPU time onto the real, physical CPU. This scheduling and switching introduces real, measurable overhead compared to running directly on the hardware.

**Problem 5 — resource waste at scale.** Imagine running 100 VMs, each doing nothing more than printing "Hello World." Each one of those VMs still carries a full OS, kernel, drivers, and background services — meaning thousands of duplicated files exist purely to support a trivial workload.

**Problem 6 — maintenance nightmare.** If you have 300 VMs, each one independently needs OS updates, security patches, package updates, and firewall configuration. Instead of patching one operating system, you are now patching 300 of them, each of which may have drifted slightly out of sync with the others.

**Problem 7 — poor density.** If a single VM's OS overhead alone consumes 2 GB of RAM, and your server has 64 GB total, you can fit at most 32 VMs on that box — even if each application inside only actually needs 100 MB to run. Most of your expensive RAM is spent on operating system overhead, not on the workloads you actually care about.

### Why this happened

The root cause behind every one of these seven problems is the same: every VM bundles its *own, private copy* of the operating system kernel. The kernel is the expensive part — and virtualization forces you to pay for a fresh one, over and over, for every single workload you want to isolate.

This observation — "why are we copying an entire Linux installation hundreds of times when all of these Linux applications ultimately use the same kernel?" — is the exact question that led to the invention of containers.

---

## 3. Introduction to Containers

### The kernel-sharing insight

Instead of running 100 separate kernels, what if 100 workloads could share *one* kernel, while still being isolated from each other well enough to solve the original dependency-conflict, resource-contention, and security problems?

That single question is the foundation of every container technology that exists today, including Docker.

### What is a container?

A **container** is an isolated environment that bundles an application together with its dependencies, libraries, and configuration — but, critically, it does *not* bring its own kernel or operating system. It shares the host machine's kernel instead.

```
Container
─────────
Application
Libraries
Dependencies
Configuration
```

Notice what's conspicuously absent from that list: there is no kernel and no operating system inside the container itself.

```
Application       Application       Application
Libraries         Libraries         Libraries
Dependencies      Dependencies      Dependencies
─────────────     ─────────────     ─────────────
  Container         Container         Container

=========================================================
              Container Runtime (Docker)
=========================================================

                    Linux Kernel

                      Hardware
```

Every container on the box shares that single Linux kernel underneath it.

### Containers vs. virtual machines, side by side

```
Virtual Machines                       Containers

App                                    App
OS                                     Libraries
Kernel                                 ─────────
────                                    Container
 VM

App              Hypervisor            App
OS                                     Libraries
Kernel                                 ─────────
────                                    Container
 VM

  Hardware                            Docker
                                       Linux Kernel
                                       Hardware
```

Where VMs stack an entire OS (including its own kernel) on top of a hypervisor, containers stack only the application and its libraries on top of a shared kernel, managed by a much lighter container runtime rather than a full hypervisor.

### Why sharing the kernel matters

Instead of loading four separate kernels into memory — one per VM — there is exactly one kernel loaded on the host, shared by every container. This single change is responsible for almost all of the efficiency gains containers have over VMs.

**Startup time.** Booting a VM means booting an entire operating system (30–90 seconds). Starting a container means creating a process, mounting a filesystem, and running the application — usually under one second, often just milliseconds:

```
VM:         Power On → Boot OS → Load Kernel → Load Drivers → Application   (30–90s)
Container:  Create Process → Mount Filesystem → Run Application              (<1s)
```

**Disk size.** A typical VM might be 2.05 GB total (2 GB OS + 50 MB app). The equivalent container might be roughly 130 MB total (80 MB of libraries + 50 MB app) — a massive reduction, because the container isn't carrying a duplicate operating system.

**Memory usage.** 100 VMs means 100 separate kernels loaded into RAM. 100 containers means 1 kernel and 100 lightweight application processes — a dramatically smaller memory footprint.

**Runtime performance.** Containers execute applications as normal processes directly on the host OS. Because they don't emulate hardware or boot a separate operating system, they generally have much lower overhead than VMs — the CPU spends more of its time running your actual application, and less time managing virtualization machinery.

### But if they share a kernel, how are they isolated?

This is the natural next question, and it's the subject of the next two sections. Linux provides several kernel-level features that, together, make containers possible even though every container is really just a group of ordinary processes on the host:

- **Namespaces** isolate *what a process can see* — other processes, network interfaces, hostnames, mount points, users, and so on.
- **Control groups (cgroups)** limit and account for *what a process can use* — CPU, memory, and disk I/O.
- **Capabilities** reduce the privileges available to a process.
- **Seccomp, AppArmor, and SELinux** can further restrict what a container is allowed to do.
- **Union filesystems** (such as OverlayFS) allow efficient, layered filesystems, which is what makes container images small and reusable.

A container, in the end, is *not* a virtual machine. It is a group of completely ordinary operating system processes that the Linux kernel isolates from the rest of the system using the mechanisms above.

### Can containers run different operating systems?

This is one of the sharpest differences between containers and VMs. Because a VM includes its own kernel, a single physical host running a hypervisor can run an Ubuntu VM, a Windows VM, and a FreeBSD VM side by side, each with a genuinely different operating system underneath it.

A Linux container, however, shares the *host's* Linux kernel — so it cannot run a Windows kernel, and a Windows container (which shares the host's Windows kernel) cannot run a Linux kernel directly. If you want to run Linux containers on a Windows machine (or vice versa), the practical workaround is to run a lightweight virtual machine behind the scenes purely to host the correct kernel. This is exactly what Docker Desktop does on Windows and macOS: it transparently runs a small Linux VM so that Linux containers have a Linux kernel to share, even though the physical host isn't running Linux natively.

---

## 4. Linux Isolation Primitives: Namespaces

### Life before containers

On a plain Linux server with no container technology involved, every process shares everything: the same process table, the same filesystem, the same network stack, the same hostname, the same set of users, and the same kernel.

```
Linux Kernel
│
├── Process: nginx
├── Process: mysql
├── Process: redis
├── Process: sshd
├── Process: python
└── Process: java
```

Any process can, in principle, see any other process. Running `ps aux` shows *every* running process on the machine. Running `ip addr` shows *every* network interface. Running `mount` shows *every* mounted filesystem. Running `hostname` returns the one, shared machine hostname. There is no isolation between processes at all.

### Namespaces isolate what a process can see

A **namespace** isolates one particular aspect of the operating system from a process's point of view. Think of each namespace type as a different *dimension* of isolation — one for process IDs, one for the filesystem, one for the network, and so on.

Linux currently supports these namespace types:

- PID
- Mount
- Network
- UTS
- IPC
- User
- Cgroup
- Time

### Think of namespaces like separate universes

Imagine two containers, A and B, each of which believes it has processes numbered 1, 2, and 3:

```
Container A          Container B          Host
PID 1                PID 1                PID 2480
PID 2                PID 2                PID 2481
PID 3                PID 3                PID 2482
                                           PID 3120
                                           PID 3121
                                           PID 3122
```

Inside each namespace, processes believe they're alone in the universe. Underneath, the kernel is quietly performing the translation between what a process *sees* and what is *really* going on.

### PID namespace

The PID namespace isolates process IDs. Without it, running `ps aux` inside a container would show every process on the entire host — `nginx`, `mysqld`, `systemd`, `docker`, `redis`, `sshd`, and everything else. With a PID namespace in place, that same container only sees its own processes:

```
PID   COMMAND
1     nginx
12    worker
13    worker
```

**How the kernel actually does this.** Every process has a real, underlying kernel PID. Suppose that on the host, PID 4831 belongs to the `nginx` process. Inside its own PID namespace, that same process is visible as PID 1. The kernel stores *both* values for the same underlying task — conceptually:

```
Kernel Task
  Host PID = 4831
  Namespace PID = 1
```

When `nginx` calls `getpid()`, the kernel checks which namespace is asking, and returns `1` — not `4831`. The real, host-level PID never changes; only the *visible* PID changes depending on who's asking. This is why the exact same underlying process can appear as PID 1 to itself, and as some large number (e.g., 4831) to the host:

```
Host PID 5300
    ↓
Namespace A → PID 1
    ↓
Namespace B → PID 1
```

The same process can have different visible PIDs depending on which namespace is doing the asking.

### PID 1 inside a container

This detail confuses many newcomers to Docker. On a normal Linux machine, the very first process — PID 1 — is `init` or `systemd`, and every other process on the system eventually descends from it.

When Docker creates a container, it creates a brand-new, *empty* PID namespace. There are zero processes inside it at first. Whatever the *first* process happens to be that gets started inside that namespace automatically becomes PID 1 within it — not because that process is special in any way, but simply because it was first.

For example, running `docker run ubuntu sleep infinity` means that inside the container, `sleep` is PID 1 — purely because it was the first (and only) thing started in that namespace. On the host, that exact same process might show up as, say, PID 7123. Same process, different namespace, different visible identity.

### Mount namespace

The mount namespace isolates the filesystem tree that a process can see. Without it, a container would see the host's real root filesystem: `/home`, `/etc`, `/var`, `/usr`, and so on, exactly as they exist on the host.

With a mount namespace, the container instead sees what looks like its own, self-contained root filesystem — `/app`, `/bin`, `/etc`, `/usr` — even though what's "actually" mounted at that root is really a directory somewhere under `/var/lib/docker/overlay2/...` on the host. From the container's point of view, this looks and behaves exactly like a real root filesystem. In effect, the kernel lies convincingly about what `/` really is.

Docker accomplishes this using a system call called `pivot_root`, which swaps the process's root filesystem from the host's real root to the container's own root filesystem. Everything outside that new root simply disappears from view.

### Network namespace

Every container gets its own, independent networking stack. Instead of sharing the host's `eth0`, `lo`, and `docker0` interfaces, each container gets its own `lo` and `eth0`, along with its own routing table, its own firewall rules, and its own set of ports. Running `ip addr` inside a container returns only that container's interfaces — the host's real interfaces are invisible to it.

**Virtual Ethernet pairs (veth).** How does an isolated container actually reach the outside world, then? Linux creates a **veth pair** — think of it as a virtual Ethernet cable with one end plugged into the container and the other end plugged into the host:

```
Container
  eth0
   │
   │  (virtual cable)
   │
  veth1234
Host
```

Packets that enter one end of the veth pair appear instantly on the other end — it behaves exactly like a real network cable connecting two machines, except both ends happen to live on the same physical box.

### UTS namespace

UTS stands for "Unix Time Sharing." It isolates the hostname and domain name. A host might report its hostname as `server01`, while a container running on that same host reports its own, independent hostname (e.g. `nginx`) — same underlying kernel, different visible identity.

### IPC namespace

Processes communicate with each other through mechanisms like shared memory, semaphores, and message queues. The IPC namespace isolates these mechanisms per-container, so that Container A cannot reach into Container B's shared memory segments, even though both are ultimately running on the same kernel.

### User namespace

Normally, UID 0 means "root," with full privileges over the machine. User namespaces break that assumption: inside a container, UID 0 can be mapped to a completely unprivileged UID on the host — for example, host UID 100000. This means "root" inside the container is not actually root on the host at all, which significantly improves security, since even a full container compromise doesn't automatically grant real root access to the underlying machine.

### Cgroup namespace

This hides the host's control-group hierarchy from the container, so that a container only sees its own control group rather than the full tree of every cgroup on the system.

### Time namespace

This lets processes inside different namespaces see different boot times and monotonic clocks — a feature that's particularly useful for checkpointing and restoring containers, where you want the restored process to have a consistent notion of "how long it's been running."

---

## 5. Linux Resource Control: cgroups

Namespaces solve the *visibility* problem — what a process can see. They do **not** solve the *resource* problem — what a process can use.

Consider two containers running side by side: Container A running `while(true){}` in an infinite busy loop, and Container B running `nginx`. Without any resource limits, Container A can consume 100% of the CPU, and Container B simply starves. Isolation alone is not enough — you also need to cap how much of the shared machine each container is allowed to consume.

### What is a cgroup?

A **control group (cgroup)** is a kernel mechanism that groups a set of processes together and applies resource policies to that group as a whole:

```
Processes
   ↓
 Group
   ↓
 Rules
```

For example, a container's processes (PIDs 100, 101, 102) might be placed into a cgroup with rules capping it at 2 CPU cores, 2 GB of memory, and 100 MB/s of disk I/O. Every process inside that cgroup is bound by those rules collectively.

### CPU controller

If you run `docker run --cpus=2`, the kernel schedules that container's cgroup as though it owns only two CPU cores — even if the underlying machine actually has 64 cores available. The cgroup enforces the cap regardless of how much idle capacity exists elsewhere on the box.

### Memory controller

Running `docker run -m 512m` causes the kernel to track how many memory pages have been allocated to that cgroup. If usage exceeds the 512 MB limit, the kernel's OOM (Out-Of-Memory) killer steps in and terminates a process inside that specific cgroup — rather than letting the container degrade the rest of the host.

### IO controller

This limits disk bandwidth for a cgroup — for example, capping it at 100 MB/sec regardless of how aggressively the process inside tries to read or write.

### PIDs controller

This limits how many processes a cgroup is allowed to create. Running `docker run --pids-limit 100` means that if the container tries to `fork()` past that limit, the kernel simply denies the new process creation — a direct defense against fork bombs, which would otherwise be able to exhaust the entire host's process table.

### Freezer controller

This can freeze an entire cgroup, halting every process inside it from executing further, without killing them. This is particularly useful for checkpointing a container's state.

### Huge pages controller

This can limit how much "huge page" memory (a special, larger memory-page size used for performance-sensitive workloads) a cgroup is allowed to use.

### Device controller

This controls which device files a cgroup's processes are allowed to access — for example, denying access to `/dev/sda` (a raw disk device) while allowing access to a GPU device file.

### Namespaces vs. cgroups, side by side

The cleanest way to remember the distinction:

| | Question it answers |
|---|---|
| **Namespaces** | What can I *see*? |
| **cgroups** | What can I *use*? |

Namespaces hide things from a process. Cgroups limit how much of the things it *can* see it's allowed to consume. A container, put together, can only see itself (via namespaces) and can only use 2 CPUs, 1 GB of RAM, and 100 processes (via cgroups) — even though it's running on a machine with vastly more capacity than that.

---

## 6. Additional Security Layers

Namespaces and cgroups form the core of container isolation, but Docker (and the Linux kernel) layer several additional mechanisms on top:

- **Capabilities** reduce the specific privileges available to a process, breaking "root" down into a finer-grained set of individually grantable powers (e.g., the ability to bind to low-numbered ports, or to change file ownership) rather than an all-or-nothing switch.
- **Seccomp** (secure computing mode), **AppArmor**, and **SELinux** can further restrict exactly which system calls or actions a container's processes are permitted to perform, on top of whatever namespaces and cgroups already allow.
- **Union filesystems**, most commonly **OverlayFS**, allow multiple read-only directories to be layered together into a single merged view. This is the mechanism that makes container images small, shareable, and fast to build — and it's covered in full depth in the [Docker Storage Engine](#12-docker-storage-engine) section below.

---

## 7. Docker Engine Architecture

Now that the underlying Linux primitives are clear, it's time to look at how Docker itself is actually built — the chain of processes that turns a command like `docker run nginx` into a running, isolated container.

### Docker Client

When you type `docker run nginx`, the `docker` binary you're invoking is the **Docker Client**. It does almost nothing on its own. Its entire job is to parse your command, convert it into a REST API request, and send that request to the Docker daemon:

```
You
 ↓
docker CLI
 ↓
dockerd
```

Think of the CLI as a remote control — all the real work happens elsewhere.

### Docker Daemon (dockerd)

`dockerd` is the brain of Docker. It runs continuously in the background, always waiting for requests. When it receives a request like "run nginx," it performs a wide range of tasks: pulling the image if needed, creating the container's filesystem, configuring networking, allocating volumes, configuring namespaces, configuring cgroups, and finally asking `containerd` to actually create the container. `dockerd` is the orchestrator that coordinates all of this.

### Why doesn't dockerd run containers directly?

In Docker's early history, it did — the chain was simply `docker CLI → dockerd → container`. But Docker grew to handle images, networking, volumes, builds, plugins, *and* containers all within a single monolithic daemon, and that became difficult to maintain. So Docker split container management out into its own dedicated project: **containerd**.

### containerd

`containerd` is the container *runtime manager*. It knows how to create containers, start them, stop them, manage filesystem snapshots, manage images, manage storage, and manage OCI-compliant containers generally. `dockerd` simply tells `containerd`, "create this container," and `containerd` handles everything from there.

**Why does this extra layer exist?** Because Docker is not the only piece of software that needs to run containers. Kubernetes, for example, doesn't actually want or need Docker itself — it wants a container runtime, full stop. So Kubernetes talks directly to `containerd`, skipping `dockerd` entirely. This is why modern Kubernetes clusters commonly run `containerd` without `dockerd` present at all.

### runc

Even `containerd` doesn't directly create Linux processes — it understands the concept of "a container," but it's Linux that understands "a process." Something has to translate between the two, and that something is **runc**.

`runc` is a small, focused program whose entire job is to take an OCI (Open Container Initiative) specification and turn it into actual Linux system calls:

```
OCI Specification
       ↓
Linux System Calls
```

Internally, `runc` performs operations like `clone()`, `setns()`, `unshare()`, `pivot_root()`, `mount()`, `sethostname()`, `setuid()`, and `execve()` — the exact system calls that establish namespaces, mount the container's filesystem, configure cgroups, and finally hand off execution to the container's main program.

### runc is very short-lived

A common misconception is that `runc` stays running for the container's whole lifetime. It doesn't. The actual sequence is:

```
containerd
    ↓
runc starts
    ↓
create namespaces
    ↓
start container
    ↓
runc exits
```

Once the container process has been successfully launched, `runc`'s job is done, and it exits immediately.

### Then who watches the container?

If `runc` disappears the instant the container starts, who tracks whether the container is still alive? Who forwards signals to it? Who reports its exit code back up the chain? That job belongs to **containerd-shim**.

### containerd-shim

The shim is a small, long-lived monitor process. Every single container gets exactly one shim:

```
containerd
   │
   ├── shim → nginx
   ├── shim → redis
   └── shim → postgres
```

**Why does the shim exist at all?** Imagine that `containerd` itself crashes. Without a shim, the chain would simply be `containerd → container` — and if `containerd` dies, the container dies with it. That's unacceptable for a production system. With a shim in place, the chain is instead `containerd → shim → container`, so the container keeps running even if `containerd` crashes and later restarts. The shim stays alive, keeps the container's standard input/output streams open, tracks its exit status, and can reconnect with a freshly-restarted `containerd`.

### Complete flow of `docker run nginx`

Putting the whole chain together, here is what actually happens, step by step, when you run that one command:

1. The `docker` CLI sends an API request.
2. `dockerd` receives the request.
3. `dockerd` checks whether the `nginx` image already exists locally, and downloads it if not.
4. `dockerd` configures networking for the new container.
5. `dockerd` creates the container's writable filesystem layer.
6. `dockerd` calls `containerd`.
7. `containerd` launches a `containerd-shim` for this container.
8. The shim launches `runc`.
9. `runc` creates namespaces, configures cgroups, mounts the container's filesystem, and executes the container's entrypoint.
10. `runc` exits, having done its job.
11. The shim continues supervising the running container process for as long as it lives.

### Why does `docker stop` work the way it does?

Suppose the container's PID 1 is `nginx`. Running `docker stop mycontainer` follows this chain:

```
docker CLI
    ↓
dockerd
    ↓
containerd
    ↓
containerd-shim
    ↓
Send SIGTERM to container PID 1
```

The container's PID 1 receives `SIGTERM` first, which gives the application a chance to shut down gracefully — closing open connections, flushing buffers, and so on. Docker then waits, by default, 10 seconds. If the process is still running after that grace period, Docker escalates to `SIGKILL`, which the kernel enforces immediately and which cannot be caught or ignored by the application in any way.

### The entire architecture, in one diagram

```
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
      |    Docker daemon      |
      +-----------------------+
                  │
                  ▼
      +-----------------------+
      |      containerd       |
      |    Runtime manager    |
      +-----------------------+
                  │
         One shim per container
                  │
                  ▼
      +-----------------------+
      |   containerd-shim     |
      |  Supervises container |
      +-----------------------+
                  │
          Starts (then exits)
                  ▼
      +-----------------------+
      |        runc           |
      |     OCI runtime       |
      +-----------------------+
                  │
                  ▼
     Linux Kernel (namespaces,
     cgroups, mounts, syscalls)
                  │
                  ▼
      Container Process (PID 1
      inside its own PID namespace)
```

---

## 8. Docker Images — Concepts

### What is a Docker image?

A **Docker image** is an immutable, read-only filesystem that contains everything needed to run an application: operating system files (usually a minimal Linux distribution), application binaries, libraries, dependencies, configuration, environment variables, metadata, and a startup command.

Crucially, **an image is not running** — it's a package, a static template, nothing more. A `python:3.12` image, for instance, internally contains `python3`, `pip`, the standard library, SSL libraries, CA certificates, timezone files, and metadata — but none of it is executing until a container is created from it.

### Why Docker uses images

Without Docker, getting `nginx` running on a new server means: install Linux, install nginx, install its dependencies, configure it, then start it — and you have to repeat that entire sequence, by hand, on every single server. With Docker, all of that gets baked once into a single nginx image (Linux + nginx + configuration + dependencies), and every server after that simply runs `docker run nginx`. No installation, no manual configuration — everything the application needs is already packaged inside.

### Images are read-only

This is one of the single most important ideas in all of Docker: **a Docker image never changes**, ever, once it's built. When you run `docker run ubuntu`, Docker does *not* modify the Ubuntu image in place. Instead, it layers a brand-new, writable **container layer** on top of the unchanged, read-only image:

```
Image
(Read Only)

──────────────

Container Layer
(Read Write)
```

If a running container creates a new file, that file is stored *only* inside its own container layer — the original image underneath remains completely untouched, and can be reused, unmodified, by any number of other containers running simultaneously.

### Image vs. container

| | Image | Container |
|---|---|---|
| State | Static | Running |
| Access | Read-only | Read-write |
| Nature | Template | Has live processes |
| Can execute | No | Yes |

A single image can serve as the template for any number of independent containers running at once:

```
Ubuntu Image
      │
 ┌────┼─────┐
 │    │     │
 ▼    ▼     ▼
C1   C2    C3
```

### Image architecture: filesystem + metadata

Every image is made up of two parts:

**Filesystem** — the actual directory tree: `/bin`, `/usr`, `/etc`, `/home`, `/var`, and whatever the application itself contributes.

**Metadata** — information about how the image should behave when it's run: the default command, environment variables, the working directory, exposed ports, the entrypoint, the author, and labels.

For example, an image's filesystem might contain `/bin/bash`, `/usr/bin/python`, and `/lib`, while its metadata separately records `CMD ["python"]`, `ENV PATH=...`, and `WORKDIR /app`.

### Where images are stored

On Linux, Docker stores images under `/var/lib/docker/`. Image *metadata* — tags, manifests, layer hashes, repository info — lives under `/var/lib/docker/image/`, while the actual filesystem *layers* themselves live under `/var/lib/docker/overlay2/` (covered in depth in the [Docker Storage Engine](#12-docker-storage-engine) section).

### Image IDs

Every image is identified by a SHA256 hash of its contents, e.g. `sha256:6d7d3f65aafcb6...`, which Docker typically shortens for display, e.g. `6d7d3f65aafc`. This hash uniquely identifies the exact contents of the image — two images with identical content will always have the same ID, regardless of what they're named or tagged.

### Image naming: registry / namespace / repository / tag

Images have human-friendly names like `ubuntu`, `nginx`, `python`, or `redis`, but Docker internally expands these to a fully-qualified form. `ubuntu` actually means `docker.io/library/ubuntu:latest`. The full format is:

```
REGISTRY/NAMESPACE/REPOSITORY:TAG
```

For example, `ghcr.io/user/myapp:v2` breaks down as registry `ghcr.io`, namespace `user`, repository `myapp`, and tag `v2`.

### Registries

A **registry** is simply a server that stores Docker images — conceptually similar to how GitHub stores Git repositories. Popular registries include Docker Hub (`docker.io`), GitHub Container Registry (`ghcr.io`), Google's registry (`gcr.io`), AWS's public registry (`public.ecr.aws`), and Microsoft's registry (`mcr.microsoft.com`). Running `docker pull nginx` contacts `docker.io` by default, downloads the image, and stores it locally.

### Repositories

A **repository** groups multiple *versions* of the same application together. The `ubuntu` repository, for instance, contains tags like `20.04`, `22.04`, `24.04`, and `latest` — all different versions of the same underlying application, grouped under one name.

### Tags

A **tag** represents a specific version within a repository — `python:3.10`, `python:3.11`, `python:3.12`, `python:latest`, and so on. It's strongly advisable to avoid using `latest` in production, because what `latest` points to can silently change over time — today's `latest` might be a completely different, breaking version tomorrow. Prefer pinning to something explicit and reproducible, like `python:3.12.4`, `ubuntu:24.04`, or `nginx:1.27`.

### What happens during `docker pull`

Running `docker pull nginx` triggers roughly this sequence: the CLI talks to the Docker daemon, which talks to the registry, downloads the image's manifest, downloads whichever layers are missing locally, verifies each layer's SHA256 hash, and stores everything locally. If some of the required layers already exist on disk from a previous pull, Docker only downloads the layers that are actually missing — it never re-downloads layers it already has.

### Image layers

This is one of Docker's most important innovations. A Docker image is not one giant, monolithic file — it's composed of many read-only layers, stacked on top of each other:

```
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
```

Each layer contains only the *changes* introduced at that particular step. Given this Dockerfile:

```dockerfile
FROM ubuntu:24.04
RUN apt update
RUN apt install python3
COPY app.py /app/
CMD ["python3", "/app/app.py"]
```

Each instruction (with some exceptions for metadata-only instructions) creates a new layer: the base Ubuntu filesystem, then a layer for the `apt update` cache, then a layer for the Python install, then a layer for the copied `app.py`, then metadata recording the `CMD`. Stacked together, these layers form the final, complete image.

### Layer reuse across images

Suppose two separate images both start from Ubuntu, then install Python, and only diverge at the very last step — one installs a Flask app, the other a FastAPI app. Both images share their first two layers (Ubuntu, then Python) in common. Docker is smart enough to store those shared layers **only once** on disk, saving both storage space and download time for anyone pulling either image, since the common layers only ever need to be fetched a single time.

### Copy-on-write

When a container starts, Docker adds a fresh, empty writable layer on top of the image's read-only layers. If the application inside the container modifies a file — say, `/etc/config` — Docker does not touch the original image layer at all. Instead, a *new copy* of that file, with the modification applied, is written into the container's writable layer, which effectively "overrides" the original version for that specific container. This mechanism is called **copy-on-write**, and it's what allows many containers to share the exact same underlying image layers safely, even while each one is free to make its own independent changes.

---

## 9. Image Commands

| Command | Purpose |
|---|---|
| `docker images` / `docker image ls` | List images stored locally |
| `docker pull <image>` | Download an image from a registry (e.g. `docker pull nginx`, or a specific version with `docker pull ubuntu:24.04`) |
| `docker rmi <image>` / `docker image rm <image>` | Remove a local image (containers depending on it must be removed first, or the deletion must be forced) |
| `docker image inspect <image>` | Show detailed JSON metadata: image ID, parent layers, environment variables, entrypoint, default command, architecture, OS, and creation time |
| `docker history <image>` | Show the layers that make up an image and the command that created each one |
| `docker search <term>` | Search Docker Hub for images matching a term (this does not download anything) |
| `docker tag <image> <newtag>` | Assign an additional name/version to an existing image — both tags point at the same underlying image ID until one of them is rebuilt |
| `docker save -o file.tar <image>` | Export an image (with all its layers) into a portable archive file |
| `docker load -i file.tar` | Restore an image previously exported with `docker save` back into the local image store |

**A complete worked example:**

```bash
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
```

---

## 10. Container Lifecycle & Core Commands

### Images vs. containers, once more

A Docker container passes through several distinct stages over its lifetime:

```
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
```

Think of the image as a *blueprint* and the container as a *running building constructed from that blueprint*. You can build many independent containers from one single image.

### Running a container

`docker run nginx` is the single most common command in all of Docker. Internally, it: (1) downloads the image if it isn't already present locally, (2) creates a writable layer, (3) creates namespaces, (4) creates cgroups, (5) sets up networking, and (6) starts the container's PID 1 process.

### Listing containers

`docker ps` lists only *running* containers, showing the container ID, image, command, status, ports, and name. `docker ps -a` lists *every* container regardless of state — running, exited, or created.

### Interactive containers: `-i` and `-t`

Running plain `docker run ubuntu` does nothing visible and exits immediately, because Ubuntu's default command finishes instantly with no interactive shell attached. To get an actual interactive shell, run `docker run -it ubuntu bash` instead, which drops you into a `root@<id>:/#` prompt inside the container.

- **`-i`** (interactive) keeps STDIN open. Without it, your keyboard input has nowhere to go.
- **`-t`** allocates a pseudo-terminal, which is what makes the container feel like a normal Linux terminal session rather than a raw, unstyled stream. Without it, you don't get a proper shell experience.

These two flags are almost always used together as `-it`.

### Naming containers

Without an explicit name, Docker generates random ones, like `adoring_hopper` or `sleepy_panini`. You can specify your own with `docker run --name web nginx`, after which the container is referred to as `web`.

### Detached mode

By default, `docker run nginx` attaches your terminal directly to the container's output. Running `docker run -d nginx` instead returns the container's ID immediately and lets the container keep running in the background — ideal for anything server-like that you don't want tied to your terminal session.

### Publishing ports

Inside a container, `nginx` might be listening on port 80, but the host has no way to reach that port unless it's explicitly published. `docker run -p 8080:80 nginx` maps host port 8080 to container port 80, so that `localhost:8080` in a browser reaches port 80 inside the container. Multiple ports can be published at once, e.g. `-p 8080:80 -p 8443:443`.

### Environment variables

Applications frequently need runtime configuration. `docker run -e MYSQL_ROOT_PASSWORD=secret mysql` sets an environment variable that the application inside the container can read — running `echo $MYSQL_ROOT_PASSWORD` inside that container prints `secret`.

### Mounting volumes (introduction)

Without a volume, anything a container writes disappears the moment the container is deleted. `docker run -v /home/me/data:/app/data ubuntu` mounts a host directory into the container, so that both the host and the container share the same files. Volumes are covered in full depth in [section 13](#13-docker-volumes).

### Executing commands inside a running container

If a container is already running, `docker exec -it web bash` opens an interactive shell inside it *without restarting it* — it creates an additional process alongside whatever is already PID 1:

```
PID 1  nginx
   ↓
 exec
   ↓
  bash
```

You can also run a single one-off command instead of a full shell, e.g. `docker exec web ls /`, which prints the result and leaves the container running exactly as before.

### Viewing logs

Applications write to stdout/stderr, and Docker captures that output automatically. `docker logs web` shows it; `docker logs -f web` follows it live, equivalent to `tail -f`.

### Stopping, starting, restarting, and killing

- `docker stop web` sends `SIGTERM`, waits 10 seconds, then sends `SIGKILL` if the process hasn't exited on its own.
- `docker start web` starts an existing, already-created container back up — it does *not* create a new one.
- `docker restart web` is equivalent to `stop` followed by `start`.
- `docker kill web` sends `SIGKILL` immediately, with no graceful shutdown period at all.

### Removing containers and images

`docker rm web` deletes a *stopped* container's writable layer and metadata (the underlying image is untouched). `docker rm -f web` forces removal of a running container, equivalent to `kill` followed by `remove`. `docker rmi nginx` deletes an *image* — any containers still using it must be removed first.

### Inspecting, monitoring, and copying

- `docker inspect web` dumps everything Docker knows about a container as a large JSON document: network settings, mounts, IP address, PID, image, state, labels, volumes, and environment.
- `docker stats` shows real-time CPU, memory, network, and disk I/O usage, continuously updating.
- `docker top web` lists the processes running *inside* the container, as seen from the container's own process namespace — useful for understanding what your application has actually started.
- `docker cp file.txt web:/tmp/` copies a file from the host into a container; `docker cp web:/etc/nginx/nginx.conf .` copies a file the other direction, from container to host.

### `docker run` vs. `docker start` vs. `docker create` vs. `docker attach`

This distinction is one of the most common sources of confusion for beginners.

**`docker run`** creates *and* starts a brand-new container every single time it's invoked. Running `docker run ubuntu` three times in a row produces three entirely separate containers, not one reused container.

**`docker start`** starts an *existing*, previously-stopped container back up. No new container is created — it's the same container, resuming from where it left off.

**`docker create`** is used less commonly. `docker create nginx` creates a container from an image but does *not* start it — you'd later run `docker start <container>` to actually bring it up.

**`docker attach`** reconnects your terminal to a container's *original* main process's standard input/output. This is different from `docker exec`, which spins up an entirely new process inside the container — `attach` connects to the process that was already running as PID 1.

### Container states

```
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
```

| Command | Effect |
|---|---|
| `docker create` | Creates a new container but does not start it |
| `docker run` | Creates and starts a new container |
| `docker stop` | Gracefully stops a running container |
| `docker start` | Starts an existing stopped container |
| `docker restart` | Stops then starts a container |
| `docker kill` | Immediately terminates a running container |
| `docker rm` | Removes a stopped container |
| `docker rm -f` | Forces a running container to stop and removes it |

### A complete worked example

```bash
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
```

---

## 11. Docker Networking

### Why containers need networking at all

Imagine three containers: a frontend, a backend API, and a PostgreSQL database. Immediately, real questions arise: how does the frontend reach the backend? How does the backend reach PostgreSQL? Can containers reach the internet? Can your laptop reach a container? Can containers on different machines communicate with each other? Docker networking exists to answer all of these.

### Every container has its own network namespace

As covered in [section 4](#4-linux-isolation-primitives-namespaces), each container gets its own network namespace, isolating its interfaces, routing table, ARP table, firewall rules, and ports. Inside a container, `ip addr` typically shows only `lo` and `eth0`, while the host separately has `lo`, `eth0`, `docker0`, and various `vethxxxx` interfaces that the container cannot see at all.

The cleanest mental model: a network namespace behaves like a *separate physical computer*, complete with its own IP, its own routing table, its own interfaces, and its own idea of "localhost."

### localhost is private per-container

This surprises many beginners the first time they hit it. Container A's `localhost` (`127.0.0.1`), Container B's `localhost`, and the host's own `localhost` are three *completely separate* loopback interfaces — traffic on one is entirely invisible to the others.

### Virtual Ethernet pairs, revisited

Docker connects a container to the outside world using a **veth pair** — a virtual cable with one end (`eth0`) living inside the container namespace, and the other end (`vethab23` or similar) living on the host. Packets entering one side appear instantly on the other, exactly like a physical network cable.

### The Docker bridge (`docker0`)

Docker creates a virtual switch on the host called `docker0` (inspectable via `ip addr show docker0`, typically at an address like `172.17.0.1/16`). It behaves exactly like a real network switch:

```
                docker0
          +----------------+
          | Virtual Switch |
          +----------------+
          /      |       \
      veth1   veth2    veth3
        |        |        |
   Container1 Container2 Container3
```

Every container's veth pair plugs into this virtual switch.

### Packet flow between two containers

Suppose Container A (`172.17.0.2`) wants to reach Container B (`172.17.0.3`). The packet travels: out of Container A's `eth0`, across its veth pair to `vethA` on the host, through the `docker0` bridge, across Container B's veth pair (`vethB`), and finally into Container B's `eth0`. Docker itself isn't copying these packets — ordinary Linux networking forwards them; Docker's job is simply to have created this topology in the first place.

### Internet access via NAT

If a container runs `curl google.com`, the traffic flows out through `docker0`, onto the host, out the host's own `eth0`, and finally onto the internet. Docker configures NAT (Network Address Translation) using `iptables` (or the system's equivalent firewall backend) so that outbound traffic originating from a container's internal IP (e.g. `172.17.0.2`) gets translated to the host's real IP (e.g. `192.168.1.50`) before it ever leaves the machine. Replies are translated back to the originating container automatically. From the outside world's perspective, only the host's IP is ever visible — the container's internal address is never exposed externally.

### Container IP addresses

Every container is automatically assigned an IP address by Docker — for example, three containers might receive `172.17.0.2`, `172.17.0.3`, and `172.17.0.4` respectively.

### The default bridge network, and why it isn't ideal

`docker network ls` typically shows three built-in networks out of the box: `bridge`, `host`, and `none`. Containers on the *default* `bridge` network can reach each other by raw IP address, but they do **not** get automatic DNS-based name resolution — meaning a container name like `db` or `backend` simply won't resolve on the default bridge. Because of this limitation, Docker recommends creating your own, user-defined bridge network for real applications.

### User-defined bridge networks and Docker DNS

```bash
docker network create my-network
docker run -d --network my-network --name db postgres
docker run -d --network my-network --name api my-api
```

On a **user-defined** bridge network, Docker runs an embedded DNS service automatically. The `api` container can now simply connect to `db` by name — no IP address required at all. Internally, when `api` asks "where is `db`?", Docker's DNS resolves it to the container's actual internal IP (e.g. `172.20.0.2`) transparently. This means application connection strings can use readable names, like `jdbc:postgresql://db:5432/app`, instead of fragile, hardcoded IP addresses.

### Multiple networks per container

A single container can belong to more than one network simultaneously. For example, a "frontend" network might connect only the frontend and backend, while a separate "backend" network connects the backend and the database — the backend container, being attached to both, acts as the bridge between the two tiers, while the frontend has no direct route to the database at all.

### Published ports, revisited

Containers are isolated by default — without explicitly publishing a port, `localhost:8080` on the host has no way to reach `container:8080`. `docker run -p 8080:80 nginx` maps host port 8080 to container port 80, so a browser hitting `localhost:8080` is routed, via Docker's NAT layer, through to port 80 inside the container. Only explicitly published ports are reachable from *outside* the Docker host.

### `EXPOSE` vs. publishing

Writing `EXPOSE 8080` in a Dockerfile does **not** publish anything to the host — it's purely documentation, recording "this application listens on port 8080" as image metadata. Actually publishing a port to the host requires the `-p` flag at run time.

### Docker network drivers

Network **drivers** define how a given network actually behaves under the hood. Docker supports several:

**1. Bridge** — the most common driver, and Docker's default for local development. `docker network create mynet` creates a Linux bridge (a virtual switch), and containers attach to it much like the `docker0` example above. Ideal for typical multi-service local setups: a web app, a database, a cache, a backend.

**2. Host** — `docker run --network host nginx` removes network namespace isolation entirely; the container uses the host's network stack directly, with no bridge and no NAT. If `nginx` listens on port 80 inside the container, the host itself is now listening on port 80. Advantages: fastest possible networking, no translation overhead, low latency. Disadvantages: significantly weaker isolation, potential port conflicts with other processes on the host, and behavior that's Linux-specific in the traditional sense (Docker Desktop implements this differently on macOS/Windows).

**3. None** — `docker run --network none` gives the container only a loopback interface (`lo`) and nothing else: no bridge, no internet, no DNS, no communication with anything. Useful for highly isolated workloads, security experiments, or cases where you intend to configure networking entirely by hand.

**4. Overlay** — designed for Docker Swarm or multi-host container networking, allowing containers running on entirely different physical machines to behave as though they're on one single, logical network.

**5. Macvlan** — gives a container its own MAC address, making it appear as a genuinely separate physical device directly on the LAN, each with its own MAC and its own IP drawn from the physical network. Useful for legacy applications that expect to be directly reachable as their own device on the network.

**6. IPvlan** — similar in spirit to Macvlan, but shares the host's MAC address while still assigning each container a distinct IP address. Useful in environments where having many distinct MAC addresses on the network is undesirable.

### Network commands

| Command | Purpose |
|---|---|
| `docker network ls` | List networks |
| `docker network inspect <network>` | Show subnet, gateway, driver, connected containers, and options |
| `docker network create <name>` | Create a network (optionally with `--driver bridge --subnet 172.30.0.0/16`) |
| `docker network rm <name>` | Remove a network (must have no attached containers) |
| `docker network connect <network> <container>` | Attach a running container to another network (it gains an additional interface) |
| `docker network disconnect <network> <container>` | Detach a container from a network |
| `docker run --network <name>` | Run a new container attached to a specific network |
| `docker inspect <container>` (look under `NetworkSettings`) | View a container's IP address, gateway, MAC address, networks, and published ports |

---

## 12. Docker Storage Engine

### Why Docker needs its own storage system

Imagine running 100 Ubuntu containers, and each one had a completely independent, full copy of the Ubuntu filesystem: 100 × 600 MB = 60 GB, the vast majority of which would be byte-for-byte identical between containers. Docker avoids this enormous waste by sharing the read-only image between every container that uses it, and only ever storing the *differences* introduced by each individual container. This approach is called a **copy-on-write layered filesystem**.

### Docker's storage architecture

A container's filesystem is made up of multiple stacked layers:

```
                 Container

           Writable Layer
                 ▲
                 │
         --------------------
         Image Layer 3
         Image Layer 2
         Image Layer 1
         Base OS Layer
```

Everything below the writable layer is strictly read-only; only the very top layer ever changes. When a container starts, Docker adds a fresh writable layer on top of the image's existing layers, and the container sees the combination of all of them merged together as one seamless filesystem.

### Where Docker stores everything

On Linux, nearly everything Docker manages lives under `/var/lib/docker/`:

```
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
```

- **`containers/`** holds per-container runtime metadata (`config.v2.json`, `hostconfig.json`, hostname, hosts, resolv.conf) — but *not* the container's actual filesystem contents.
- **`image/`** stores image metadata: tags, manifests, layer hashes, and repository information.
- **`network/`** stores network configuration: bridge networks, overlay networks, IP allocation records.
- **`volumes/`** stores Docker-managed volumes (covered fully in [section 13](#13-docker-volumes)).
- **`overlay2/`** is where almost all actual image and container filesystem *data* lives — this is the true heart of Docker's storage engine.

### What is OverlayFS?

Docker's default storage driver is a Linux filesystem called **OverlayFS**, implemented as `overlay2`. OverlayFS merges multiple separate directories into what *looks* like one single, unified filesystem. Given a lower directory containing `/etc`, `/usr`, `/bin`, another lower directory containing `/home`, and an upper directory `tmp/`, OverlayFS combines all of them into one apparent, merged filesystem containing `/etc`, `/usr`, `/bin`, `/home`, and `tmp` all at once — the application simply sees one coherent tree, with no awareness that it's actually assembled from several separate directories underneath.

### Inside the `overlay2/` directory

After pulling an image, `/var/lib/docker/overlay2/` fills with directories named by long hash IDs, each one representing a single filesystem layer. Each such directory typically contains:

- **`diff/`** — the actual files *introduced* by that specific layer. If Layer 3 adds `/etc/nginx/nginx.conf`, that file physically exists only inside that layer's `diff/` directory.
- **`lower`** — a pointer listing the parent layers beneath this one, which OverlayFS uses to know exactly which layers need to be stacked together.
- **`merged/`** — the actual mounted, combined filesystem. This is what a running container's process tree *actually* sees when it looks at `/` — running `docker exec ... ls /` is, underneath, looking at this `merged/` directory.
- **`work/`** — an internal OverlayFS workspace directory required by the kernel; users never interact with it directly.
- **`link`** — a short internal identifier used by Docker.

For a Dockerfile like:

```dockerfile
FROM ubuntu
RUN apt update
RUN apt install nginx
COPY index.html /var/www/html
```

Docker creates a separate layer — and a separate `overlay2/` folder — for the base Ubuntu filesystem, for the `apt update`, for the `nginx` install, and for the copied `index.html`.

### Creating a container: the writable layer

Running `docker run ubuntu` causes Docker to create one more layer on top of the existing image layers — the container's own writable layer:

```
Container

Writable Layer
     ↓
Ubuntu Layer(s)
```

This writable layer is stored inside `overlay2/` exactly like the read-only image layers beneath it, just marked as read-write instead.

### Copy-on-write, in detail

Suppose the image's `/etc/file.txt` contains the text `Hello`. When a fresh container starts, no such file exists yet in its own writable layer — reading it means falling through to the image layer below, which returns `Hello`.

Now suppose the container runs `echo Hi > /etc/file.txt`. Docker does **not** modify the original image. Instead, the *writable layer* gets its own copy of `/etc/file.txt` containing `Hi`, which effectively hides the original `Hello` version underneath it — the image itself is completely unaffected and still contains `Hello` for any other container built from it.

**Reading** a file follows a fallthrough search: the application checks the writable layer first, then Image Layer 3, then Layer 2, then Layer 1, stopping as soon as the file is found anywhere in the stack.

**Writing** a file always goes to the writable layer, and only ever the writable layer — never directly to any image layer underneath.

### What happens when a container is deleted

If a container runs `touch data.txt`, that file exists *only* inside that specific container's writable layer. The moment you run `docker rm` on that container, its writable layer is deleted in its entirety — `data.txt` is gone permanently. This surprises a lot of newcomers, and it's precisely the problem that motivates Docker volumes, covered next.

---

## 13. Docker Volumes

### Why volumes exist

Containers are, by design, disposable. Applications, and the data they generate, generally are not. Consider a MySQL container storing customer records, orders, and payments. If that container is removed with `docker rm mysql` and there's no persistent storage in place, the entire database is lost the instant the writable layer disappears. This is exactly the gap that Docker volumes are built to close.

### What is a Docker volume?

A **volume** is a directory stored *outside* of any container's writable layer. Instead of a database file living inside the disposable writable layer, it lives inside a separate volume:

```
Container
   ↓
Volume
```

Deleting the container leaves the volume completely untouched, ready to be reattached to a brand-new container later.

### Where volumes live on disk

By default, Docker stores volumes under `/var/lib/docker/volumes/`. Creating a volume with `docker volume create dbdata` produces a directory at `/var/lib/docker/volumes/dbdata/_data/`. Running `docker run -v dbdata:/var/lib/mysql mysql` means that everything MySQL writes into `/var/lib/mysql` inside the container is, in reality, being written into `dbdata/_data` on the host.

### Volume mount process

```
Host
/var/lib/docker/volumes/dbdata/_data
      ↓
  Mounted
      ↓
Container
/var/lib/mysql
```

The application inside the container has no idea any of this redirection is happening — it simply writes to `/var/lib/mysql` as usual.

### Why volumes are faster than the writable layer

Writing to the ordinary writable layer requires going through OverlayFS, which has to check layers, perform copy-on-write, and maintain layer metadata for every write. A volume, by contrast, writes directly to the host filesystem, with substantially less overhead involved.

### Types of Docker mounts

**1. Named volumes.** Docker manages the entire lifecycle. `docker volume create mydata` followed by `docker run -v mydata:/app/data` stores data under `/var/lib/docker/volumes/mydata/_data`. Advantages: fully Docker-managed, portable across environments, easy to back up, and the generally preferred choice for databases and application data.

**2. Anonymous volumes.** Created automatically whenever a container path is mounted *without* a name, e.g. `docker run -v /app/data nginx`. Docker assigns a random name (e.g. `8f6e9d4c...`). These are useful when an image already declares a `VOLUME` and you don't particularly care what the resulting volume is called — but they're easy to forget about and can silently accumulate over time if not cleaned up. `docker volume ls` shows them, and `docker volume prune` removes unused ones.

**3. Bind mounts.** A bind mount maps an *existing* host directory or file directly into the container, e.g. `docker run -v /home/user/project:/app`, or, in the more explicit modern syntax, `docker run --mount type=bind,source=/home/user/project,target=/app`. Advantages: live editing of files from the host is immediately reflected inside the container, which makes bind mounts ideal for local development, and the files remain easy to inspect with ordinary host tools. Disadvantages: the container becomes tied to a specific host path, which makes it less portable, and containers can accidentally modify or delete host files unless the mount is made explicitly read-only.

### Modern `--mount` syntax

Although `-v` is shorter to type, Docker recommends `--mount` because it's more explicit about exactly what's being mounted and how:

```bash
# Named volume
docker run --mount type=volume,source=mydata,target=/data

# Bind mount
docker run --mount type=bind,source=/home/user/project,target=/app

# Read-only bind mount
docker run --mount type=bind,source=/etc/config,target=/config,readonly
```

### Comparison: writable layer vs. named volume vs. anonymous volume vs. bind mount

| Feature | Writable Layer | Named Volume | Anonymous Volume | Bind Mount |
|---|---|---|---|---|
| Persists after container removal | ❌ | ✅ | ✅ (until removed) | ✅ |
| Docker-managed | N/A | ✅ | ✅ | ❌ |
| Stored under `/var/lib/docker/volumes` | ❌ | ✅ | ✅ | ❌ |
| Shares data with host | Indirect | Indirect | Indirect | Direct |
| Best for | Temporary container changes | Databases, application data | Temporary persistent data | Development, configuration, logs |
| Performance | Good, but has OverlayFS overhead | Excellent | Excellent | Excellent |

### Volume lifecycle

```bash
docker volume create mydata      # create
docker volume ls                 # list
docker volume inspect mydata     # inspect
docker run -v mydata:/data alpine  # use
docker volume rm mydata          # remove
docker volume prune              # remove all unused volumes
```

A volume can outlive many successive containers — you can delete a container, create a brand-new one, mount that same volume into it, and every bit of the previous data will still be exactly where it was left.

---

## 14. Dockerfiles — Building Images

### What is a Dockerfile?

A **Dockerfile** is a plain text file containing an ordered list of instructions that Docker reads and executes, line by line, to produce a new image:

```
Application Source Code
        │
        ▼
   Dockerfile (Recipe)
        │
        ▼
 docker build
        │
        ▼
 Docker Image (Blueprint)
        │
        ▼
 docker run
        │
        ▼
 Running Container
```

The clearest analogy: a Dockerfile is a recipe. A cooking recipe says "take flour, add eggs, bake" and produces a cake; a Dockerfile says `FROM ubuntu`, `RUN apt install nginx`, `COPY app`, and produces a Docker image. The Dockerfile itself is never an image — it only describes, step by step, how to build one.

### Dockerfile vs. image vs. container

```
Dockerfile
      │  docker build
      ▼
Docker Image
      │  docker run
      ▼
Container
```

The Dockerfile is a text file of instructions; the image is a read-only template containing an actual filesystem; the container is a running instance of that image with its own writable layer.

### Why Dockerfiles exist

Building an image manually — running a container, installing packages by hand, copying files in, and then committing the result — is impossible to reproduce reliably, undocumented, and different every single time you do it, which makes it effectively impossible to version control. A Dockerfile turns the entire build process into code:

```dockerfile
FROM ubuntu
RUN apt install nginx
COPY . .
```

Anyone, anywhere, can rebuild the exact same image from that file.

### What happens during `docker build`

Given a project containing a `Dockerfile`, `app.py`, and `requirements.txt`, running `docker build -t myapp .` triggers roughly this sequence: Docker reads the Dockerfile, reads the build context, executes `FROM`, creates a temporary filesystem, runs each `RUN` instruction and commits a new layer after each one, runs `COPY` and commits another layer, records the `CMD` as metadata, and finally produces the completed image. The critical thing to notice: **Docker builds the image instruction by instruction**, one layer at a time.

### `docker build` syntax

```bash
docker build [OPTIONS] PATH
docker build -t myapp .
```

The trailing `.` is extremely important — it tells Docker to send the *current directory* as the build context.

### What `docker build` actually does, internally

The current folder is compressed and sent to the Docker daemon as the build context, the daemon reads the Dockerfile, executes every instruction in order, creates a layer per relevant instruction, and produces the final image. It's worth remembering explicitly: **the Docker daemon does the building — the CLI only sends the instructions along**.

### The build context and `.dockerignore`

This is one of the most commonly misunderstood parts of Docker. Suppose a project folder contains `Dockerfile`, `app.py`, `requirements.txt`, `README.md`, and `secret.txt`. Running `docker build .` sends *everything* inside that directory to the daemon as the build context — including files you never explicitly `COPY`, such as `README.md`, `secret.txt`, `.git`, log files, `node_modules`, or build artifacts, unless they're explicitly excluded.

**Why does this happen?** The Docker daemon might be running somewhere entirely separate from your local filesystem, so it has no way to reach out and grab your files directly — instead, Docker sends the whole context up front, and the `COPY` instruction pulls from that already-uploaded context rather than reaching back out to your laptop.

Since the *entire* directory gets sent regardless of what's actually used, it's standard practice to exclude unnecessary files with a `.dockerignore` file:

```
node_modules
.git
.env
*.log
target
```

This reduces build time, reduces network traffic to the daemon, indirectly reduces image size, and — importantly — helps prevent accidental secrets from ever being included in the build context in the first place.

### Image layers during a build

Every meaningful instruction produces a new layer. For:

```dockerfile
FROM ubuntu
RUN apt update
RUN apt install nginx
COPY . .
RUN make
CMD ["./server"]
```

the resulting stack is: base Ubuntu, then a layer for `apt update`, then a layer for installing nginx, then a layer for the copied files, then a layer for the compile step, then metadata recording the `CMD` — all stacked together to form the final image.

### Intermediate containers (conceptual model)

Older Docker documentation describes the build process as creating **intermediate containers**: conceptually, for each `RUN` instruction, Docker starts a temporary container from the current image state, executes the command inside it, commits the resulting filesystem changes into a new image layer, and then removes that temporary container. Given:

```dockerfile
FROM ubuntu
RUN touch hello.txt
RUN mkdir app
```

the conceptual flow is base image → temporary container → `touch hello.txt` → commit → new image → temporary container → `mkdir app` → commit → final image. These temporary containers are never your actual application containers — they exist purely during the build process itself. Modern Docker uses **BuildKit** by default, which builds more efficiently and may not literally create visible intermediate containers in the same way — but the mental model of "each step starts from the result of the previous step and produces a new layer" remains a useful and accurate way to reason about builds.

### Build cache

Docker does not rebuild everything from scratch on every single build. Given the Dockerfile above, if only `main.cpp` has changed since the last build, Docker recognizes that `FROM`, `RUN apt update`, and `RUN apt install` are all unchanged and reuses their cached layers instantly, only re-executing the `COPY` and `RUN make` steps that actually depend on the changed file. What might take 15 seconds on a first build can become nearly instantaneous on subsequent builds, purely because of caching.

### Optimizing instruction order for caching

This has real, practical consequences for how Dockerfiles should be written. A naive ordering like:

```dockerfile
COPY . .
RUN pip install -r requirements.txt
```

invalidates the cache — and therefore forces a full reinstall of dependencies — on *any* source code change at all, even one totally unrelated to `requirements.txt`. A better ordering separates the two:

```dockerfile
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
```

Now Docker only reinstalls dependencies when `requirements.txt` itself actually changes, and ordinary source code edits skip straight past the (often slow) dependency-install step entirely.

### Build-time instructions vs. runtime instructions

This is one of the biggest conceptual splits in the entire Dockerfile format.

**Build-time instructions** execute *while the image is being built*: `FROM`, `RUN`, `COPY`, `ADD`, `WORKDIR`, `ENV`, `ARG`, `USER`, `EXPOSE`, `LABEL`. Most of these modify the image's filesystem or metadata during the build itself.

**Runtime instructions** — primarily `CMD` and `ENTRYPOINT` — are not executed during `docker build` at all. They're simply stored as metadata inside the image, and are only actually acted on later, whenever `docker run` creates a container from that image.

For example, `RUN echo hello` runs during `docker build`, exactly once, as part of producing the image. `CMD echo hello`, by contrast, runs during `docker run`, every single time a new container starts from that image.

```
RUN   →  docker build  →  Image
CMD   →  docker run     →  Container
```

### Every Dockerfile instruction

**`FROM`** is the first instruction in almost every Dockerfile — `FROM ubuntu:24.04` tells Docker "start from this existing image," and everything that follows builds on top of it.

**`RUN`** executes a command during image creation, e.g. `RUN apt update` or `RUN apt install -y nginx`. Whatever filesystem changes result get saved into a new layer.

**`COPY`** copies files from the build context (your local project) into the image, e.g. `COPY app.py /app/`.

**`ADD`** is similar to `COPY`, but with extra behaviors: it can automatically extract local tar archives, and it can download remote URLs (though the latter is generally discouraged in favor of explicit, visible download commands). In general, most Dockerfiles should default to `COPY` and reach for `ADD` only when one of its special behaviors is genuinely needed.

**`WORKDIR`** sets the working directory for every instruction that follows it, e.g. `WORKDIR /app`, equivalent to running `cd /app` both for subsequent build steps and for the container's default working directory at runtime.

**`ENV`** sets environment variables that persist in the image and remain available when the container actually runs, e.g. `ENV PORT=8080` — an application calling `os.getenv("PORT")` will see `8080` unless it's explicitly overridden at run time.

**`ARG`** defines build-time-only variables, e.g. `ARG VERSION=1.0`, which are available only during the build (unless deliberately copied into an `ENV` variable so they persist into the running image). Build-time values are supplied with `docker build --build-arg VERSION=2.0 .`.

**`EXPOSE`** documents which ports the application listens on, e.g. `EXPOSE 8080` — but, as covered in the networking section, it does **not** actually publish the port; publishing only happens at run time via `-p`.

**`USER`** changes the default user the container runs as, e.g. `USER appuser`, instead of running everything as root.

**`CMD`** specifies the default command executed when the container starts, e.g. `CMD ["python","app.py"]`. It can be overridden entirely at run time, e.g. `docker run image bash`.

**`ENTRYPOINT`** defines the container's fixed, main executable, e.g. `ENTRYPOINT ["python"]`. When combined with a `CMD` supplying default arguments, e.g. `CMD ["app.py"]`, the resulting default command is `python app.py`. If a user instead runs `docker run image test.py`, Docker executes `python test.py` — the `ENTRYPOINT` stays fixed while `CMD` (or an argument passed at run time) supplies the variable part. `ENTRYPOINT` is best used for defining the fixed executable, while `CMD` is best used for supplying default arguments to it.

### A complete, annotated Dockerfile

```dockerfile
FROM python:3.12-slim

LABEL maintainer="alice@example.com"

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV PORT=5000

EXPOSE 5000

USER nobody

CMD ["python", "app.py"]
```

---

## 15. Docker Compose — Fundamentals

### What is Docker Compose?

**Docker Compose** is a tool that lets you define, configure, and manage multiple Docker containers as a single, unified application. Instead of running many long, error-prone `docker run` commands by hand, you describe your entire application in one YAML file (`compose.yaml`), and a single command — `docker compose up` — brings the whole thing to life.

Compose is, in short, **infrastructure as code for local Docker applications**. It lets you describe containers, images, networks, volumes, environment variables, port mappings, startup order, health checks, secrets, and resource limits, all inside one configuration file.

### The pain Compose was built to solve

Imagine a simple web application made of a frontend, a backend API, a MySQL database, and a Redis cache. Without Compose, you'd need to manually create a network, create a volume, and then run each service by hand:

```bash
docker network create app-network
docker volume create mysql-data

docker run -d --name mysql --network app-network \
  -v mysql-data:/var/lib/mysql \
  -e MYSQL_ROOT_PASSWORD=root \
  mysql

docker run -d --name redis --network app-network redis

docker run -d --network app-network -p 8080:8080 \
  -e DB_HOST=mysql -e REDIS_HOST=redis backend-image

docker run -d -p 3000:80 --network app-network frontend-image
```

And then, to tear it all down again, you'd need to stop and remove each container individually, remove the network, and remove the volumes — remembering the exact right sequence every single time you want to recreate or update the environment. This becomes painful very quickly as the number of services grows.

### What problems Compose actually solves

**Multiple `docker run` commands** collapse into a single `docker compose up`.

**Remembering configuration** — ports, volumes, environment variables, restart policy, networks, container names, mounts — is no longer something you have to hold in your head; it all lives, explicitly, in one file.

**Version control** becomes trivial: instead of documentation that says "run this command, then this command, then this command," you simply commit `compose.yaml`, and anyone can clone the project and run `docker compose up`.

**Reproducibility** is guaranteed — everyone who runs the file gets the exact same containers, ports, volumes, environment, images, and networks.

**Container communication** is handled automatically. Instead of hardcoding raw IPs like `172.18.0.4`, containers communicate with each other purely by service name — a backend service simply connects to `mysql`, with no IP address involved at all.

### What is a Compose file?

A Compose file is simply a YAML document, conventionally named `compose.yaml` (the current recommended name; `docker-compose.yml` is the older, still-supported convention). YAML is a human-readable configuration format that uses indentation to express structure — instead of JSON's `{"image":"nginx"}`, Compose simply writes `image: nginx`.

### Top-level structure

```yaml
services:

volumes:

networks:

configs:

secrets:
```

`services` is, by far, the most important section, and the one nearly every Compose file revolves around.

### What is a service?

A **service** is a description of a container. Given:

```yaml
services:
  mysql:
    image: mysql
  redis:
    image: redis
  backend:
    image: backend
  frontend:
    image: frontend
```

Compose reads this and creates four separate containers, one per service. It's worth being precise about the distinction here: **the service is not the container** — the service is the *configuration* that describes how the container should be created:

```
Service
   │
   ▼
Configuration
   │
   ▼
Container
```

The service is the blueprint; the container is the actual, running instance produced from it.

### Automatic DNS / service discovery

This is one of Compose's most valuable features. Given:

```yaml
services:
  mysql:
  backend:
```

Compose automatically creates DNS records for each service, so `backend` can simply connect to `mysql` by name, rather than needing to look up or hardcode `172.20.0.5`.

### Worked example 1 — a simple nginx service

```yaml
services:
  web:
    image: nginx
    ports:
      - "8080:80"
```

Running `docker compose up` and visiting `localhost:8080` in a browser reaches this container.

### Worked example 2 — MySQL + PHP

```yaml
services:
  db:
    image: mysql:8
    environment:
      MYSQL_ROOT_PASSWORD: root

  php:
    image: php:8
    depends_on:
      - db
```

The PHP service connects to the database using the hostname `db`, not `localhost`, because both containers share a Compose-created network and are reachable by service name.

### Worked example 3 — building from a local Dockerfile

Given a project containing `Dockerfile` and `compose.yaml` side by side:

```yaml
services:
  app:
    build: .
    ports:
      - "8080:8080"
```

Running `docker compose up` causes Compose to build the image (`docker build .`), create a container from it, and start it — automatically.

### Worked example 4 — persisting database data

```yaml
services:
  mysql:
    image: mysql
    volumes:
      - mysql-data:/var/lib/mysql

volumes:
  mysql-data:
```

Even after this container is removed, the `mysql-data` volume itself continues to exist, ready to be reattached to a new container later.

### Common Docker Compose commands

| Command | Description |
|---|---|
| `docker compose up` | Create and start services |
| `docker compose up -d` | Run in detached (background) mode |
| `docker compose down` | Stop and remove containers and the default network |
| `docker compose ps` | List Compose-managed containers |
| `docker compose logs` | Show logs from all services |
| `docker compose logs -f` | Follow logs in real time |
| `docker compose exec <service> sh` | Open a shell in a running service |
| `docker compose stop` | Stop services without removing them |
| `docker compose start` | Start previously stopped services |
| `docker compose restart` | Restart services |
| `docker compose build` | Build images defined with `build:` |
| `docker compose pull` | Pull the latest images |
| `docker compose push` | Push images to a registry (when configured) |
| `docker compose config` | Validate and print the fully resolved configuration |

---

## 16. Compose Services — Full Reference

Think of a Compose project like a small city: **services** are the buildings, **networks** are the roads connecting them, and **volumes** are the storage warehouses that survive even if a building is torn down and rebuilt. These three sections make up the overwhelming majority of every real Compose file.

A service consists of many possible options:

```yaml
services:
  web:
    image: nginx
    container_name: my-nginx
    ports:
      - "8080:80"
    environment:
      ENV=production
    volumes:
      - ./html:/usr/share/nginx/html
    restart: always
    networks:
      - frontend
```

**`image`** specifies which image to use to create the container, e.g. `image: nginx` or `image: mysql:8.4`. Compose pulls it if necessary, then creates the container from it — equivalent to `docker pull` followed by `docker create`.

**`build`** builds an image instead of downloading one. `build: .` means: look in the current directory for a `Dockerfile` and run `docker build .` against it. You can also be explicit:

```yaml
build:
  context: .
  dockerfile: Dockerfile.dev
```

meaning "use the current folder as the build context, but use `Dockerfile.dev` instead of the default `Dockerfile`." If your project separates services into subfolders, e.g. `backend/` and `frontend/`, you can scope the build context accordingly:

```yaml
build:
  context: backend
  dockerfile: Dockerfile
```

so that only the `backend/` directory is actually sent to the Docker engine as the build context for that service.

**`container_name`** overrides Compose's normally auto-generated container name (e.g. `project-backend-1`) with an explicit one, e.g. `container_name: backend`. It's generally recommended *not* to set this unless you have a specific need — auto-generated names avoid naming conflicts and make it easier to scale a service to multiple instances.

**`command`** overrides the image's Dockerfile-defined `CMD`. If the Dockerfile specifies `CMD ["npm","start"]`, setting `command: npm run dev` in Compose runs `npm run dev` inside the container instead.

**`entrypoint`** overrides the image's `ENTRYPOINT`. For example, `entrypoint: sleep` combined with `command: infinity` causes the container to run `sleep infinity` rather than the image's original entrypoint.

**`ports`** publishes container ports to the host, using `HOST_PORT:CONTAINER_PORT` syntax, e.g. `- "8080:80"` maps host port 8080 to container port 80. Multiple mappings are allowed, and you can also bind to a specific host IP, e.g. `- "127.0.0.1:8080:80"`, restricting access to `localhost` only.

**`expose`** is frequently confused with `ports`. `expose: - "8080"` does *not* publish the port to the host at all — it only documents (and, in some setups, restricts) that other *containers* can reach this port; the host itself cannot. In practice, containers on the same Docker network can generally communicate regardless of `expose`, so its main practical role is documentation and metadata about the service's intended internal ports.

**`environment`** defines environment variables, either as a mapping (`MYSQL_ROOT_PASSWORD: root`) or as a list (`- MYSQL_ROOT_PASSWORD=root`) — both forms are valid, and the application inside reads them via whatever mechanism is standard for its language (`getenv()`, `System.getenv()`, `process.env`, etc.).

**`env_file`** loads environment variables from an external file instead of writing them inline, e.g. `env_file: - .env`, where `.env` might contain lines like `MYSQL_PASSWORD=root`.

**`depends_on`** controls startup *order*: `depends_on: - mysql` on the `backend` service guarantees MySQL's container is started before the backend's. Critically, it does **not** guarantee MySQL is actually *ready* to accept connections by the time the backend starts — it only guarantees the container process was launched first. For genuine readiness, combine it with a `healthcheck` and the `condition: service_healthy` form:

```yaml
services:
  db:
    image: mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      retries: 5

  backend:
    depends_on:
      db:
        condition: service_healthy
```

**`restart`** sets the restart policy, e.g. `restart: always`, meaning that if the container crashes, Docker restarts it automatically. Valid values are `no`, `always`, `unless-stopped`, and `on-failure`.

**`healthcheck`** lets Compose determine whether a container is actually healthy, not merely running:

```yaml
healthcheck:
  test: ["CMD","curl","-f","http://localhost"]
  interval: 30s
  timeout: 5s
  retries: 3
```

Docker periodically runs the given command; if it fails repeatedly past the retry count, the container is marked `unhealthy`.

**`tty`** allocates a terminal for the container, equivalent to `docker run -t` — useful for interactive containers.

**`stdin_open`** keeps STDIN open, equivalent to `docker run -i` — useful for shells and debugging sessions.

**`user`** runs the container as a specific user, e.g. `user: "1000:1000"`, instead of the default (often root).

**`working_dir`** sets the runtime working directory, equivalent to a Dockerfile's `WORKDIR`, e.g. `working_dir: /app`.

**`hostname`** sets the container's hostname, e.g. `hostname: backend`, so that running `hostname` inside the container returns `backend`.

**`dns`** specifies custom DNS servers for the container to use, e.g. `dns: - 8.8.8.8 - 1.1.1.1`.

---

## 17. Compose Volumes — Full Reference

Volumes exist in Compose to solve exactly the same problem covered in [section 13](#13-docker-volumes): containers are disposable, but the data an application generates — a MySQL database's tables, for instance — usually isn't. Without persistent storage, removing a container means losing everything it wrote.

There are three common storage patterns available inside Compose: named volumes (managed by Docker), bind mounts (a host directory), and anonymous volumes (Docker-managed but unnamed).

### Named volumes

```yaml
services:
  mysql:
    image: mysql
    volumes:
      - mysql-data:/var/lib/mysql

volumes:
  mysql-data:
```

The named volume `mysql-data` is mounted into `/var/lib/mysql` inside the container. Deleting the container leaves the volume — and therefore the database — intact.

### Bind mounts

```yaml
volumes:
  - ./app:/usr/src/app
```

This maps the host folder `./app` directly into `/usr/src/app` inside the container. Editing files on the host is reflected immediately inside the running container — this is exactly why bind mounts are so heavily used during local development.

### Anonymous volumes

```yaml
volumes:
  - /var/lib/mysql
```

Docker creates a volume with a randomly generated name automatically. These are typically used only when an image's own documentation specifically recommends declaring a volume at that path without needing to name it explicitly yourself.

### The long syntax

Instead of the short form:

```yaml
volumes:
  - ./app:/code
```

you can write the more explicit long form, which also unlocks extra options:

```yaml
volumes:
  - type: bind
    source: ./app
    target: /code
    read_only: true
```

Valid `type` values include `bind`, `volume`, and `tmpfs`.

### Top-level `volumes:` configuration

The bottom-level `volumes:` block declares reusable named volumes for the whole project:

```yaml
volumes:
  mysql-data:
  redis-data:
```

You can additionally configure drivers and driver-specific options:

```yaml
volumes:
  mysql-data:
    driver: local

  shared-data:
    driver_opts:
      type: none
      device: /mnt/shared
      o: bind
```

Other useful top-level volume options include `driver`, `driver_opts`, `external` (use an *existing* Docker volume rather than creating a new one), `labels`, and `name` (override the auto-generated volume name).

---

## 18. Compose Networks — Full Reference

### The default network

Without any explicit network configuration, Compose automatically creates one network — conventionally named `<project>_default` — and joins every service in the file to it automatically. Given three services (`backend`, `frontend`, `mysql`), Compose creates the shared network and attaches all three, and each service becomes reachable by every other service purely via its service name.

### Custom networks

```yaml
networks:
  backend:

services:
  mysql:
    networks:
      - backend
```

This explicitly places the `mysql` service onto a network named `backend`, rather than relying on the implicit default.

### Multi-network topologies

```yaml
services:
  frontend:
    networks:
      - public

  backend:
    networks:
      - public
      - private

  mysql:
    networks:
      - private
```

```
             public
        +----------------+
        | frontend       |
        | backend        |
        +----------------+

               │

        +----------------+
        | private        |
        | backend        |
        | mysql          |
        +----------------+
```

Here, `frontend` cannot directly reach `mysql`, because the two share no network in common. `backend`, being attached to both `public` and `private`, is the only service that bridges the two tiers — a common and deliberate pattern for isolating a database from anything that shouldn't be able to reach it directly.

### Network drivers in Compose

```yaml
networks:
  backend:
    driver: bridge
```

The most common drivers are `bridge` (Compose's default for local projects), `host`, `none`, and `overlay` — matching the driver concepts covered in full in [section 11](#11-docker-networking).

### Additional network options

```yaml
networks:
  backend:
    driver: bridge
    internal: true
    attachable: true
    labels:
      app: demo
```

- **`internal: true`** prevents containers on that network from reaching anything outside it through Docker's default gateway — useful for a network that should never have outbound internet access at all.
- **`attachable: true`** allows standalone containers (started outside of Compose) to join the network — mainly relevant with overlay networks under Docker Swarm.
- **`external: true`** tells Compose to use an already-existing Docker network instead of creating a brand-new one.
- **`name`** lets you override Compose's auto-generated network name with an explicit one.

---

## 19. Putting It All Together

A realistic, complete `compose.yaml` combining nearly everything covered above — building from a local Dockerfile, a health-checked database, `depends_on` with a readiness condition, a persistent named volume, and a two-tier network topology that isolates the database from the frontend:

```yaml
services:
  frontend:
    build: ./frontend
    ports:
      - "3000:80"
    networks:
      - public

  backend:
    build: ./backend
    environment:
      DB_HOST: mysql
    depends_on:
      db:
        condition: service_healthy
    networks:
      - public
      - private

  db:
    image: mysql:8
    environment:
      MYSQL_ROOT_PASSWORD: root
    volumes:
      - mysql-data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      retries: 5
    networks:
      - private

volumes:
  mysql-data:

networks:
  public:
  private:
```

Running `docker compose up` against this file causes Compose to: build the `frontend` and `backend` images from their local Dockerfiles, pull the `mysql:8` image, create the `public` and `private` networks, create the `mysql-data` named volume, start `db` first and wait until its healthcheck reports healthy, then start `backend` (attached to both networks, so it can reach both `frontend`'s tier and `db`'s tier), and finally start `frontend` — all from a single command, fully reproducible, and fully committable to version control.