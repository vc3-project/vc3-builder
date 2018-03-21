VC3 Builder
==========

NAME
----

**vc3-builder** - Deploy software environments in clusters without administrator priviliges

SYNOPSIS
--------

**vc3-builder** [options] --require package[:min_version[:max_version]] --require ... [-- command-and-args]

DESCRIPTION
-----------

The **vc3-builder** is a tool to manage software stacks without administrator
priviliges. Its primary application comes in deploying software dependencies in
cloud, grid, and opportunistic computing, where deployment must be performed
together with a batch job execution. 

**vc3-builder** is a self-contained program (including the repository of
dependencies recipes). If desired, it can be compiled to a truly static binary
([see below](#compiling-the-builder-as-a-static-binary)).

From the end-user perspective, **vc3-builder** is invoked as a command line
tool which states the desired dependencies.  The builder will perform whatever
work is necessary to deliver those dependencies, then start a shell with the
software activated. For example, assume the original environment is a RHEL7, but we need to run the bioinformatics tool [NCBI BLAST](https://blast.ncbi.nlm.nih.gov/Blast.cgi) using RHEL6:

```
$ cat /etc/redhat-release 
Red Hat Enterprise Linux Server release 7.4 (Maipo)
$ ./vc3-builder --install ~/tmp/my-vc3 --require-os redhat6 --require ncbi-blast
OS trying:         redhat6 os-native
OS fail prereq:    redhat6 os-native
OS trying:         redhat6 singularity
..Plan:    ncbi-blast => [, ]
..Try:     ncbi-blast => v2.2.28
..Refining version: ncbi-blast v2.2.28 => [, ]
..Success: ncbi-blast v2.2.28 => [, ]
processing for ncbi-blast-v2.2.28
downloading 'ncbi-blast-2.2.28+-x64-linux.tar.gz' from http://download.virtualclusters.org/builder-files
preparing 'ncbi-blast' for x86_64/redhat6.9
details: /opt/vc3-root/x86_64/redhat6.9/ncbi-blast/v2.2.28/ncbi-blast-build-log
sh-4.1$ cat /etc/redhat-release 
CentOS release 6.9 (Final)
sh-4.1$ which blastn
/opt/vc3-root/x86_64/redhat6.9/ncbi-blast/v2.2.28/bin/blastn
sh-4.1$ exit
$ ls -d ~/tmp/my-vc3
/home/btovar/tmp/my-vc3
```

In the first stage, the builder verifies the operating system requirement.
Since the native environment is not RHEL6, it tries to fulfill the requirement
using a container image. If the native environment would not support
containers, the builder terminates indicating that the operating system
requirement cannot be fulfilled.

In the second stage, the builder checks if ncbi-blast is already installed.
Since it is not, it downloads it and sets it up accordingly. As requested, all
the installation was done in `/home/btovar/tmp/my-vc3`, a directory that was
available as `/opt/vc3-root` inside the container.

The builder installs dependencies as needed. Using [cvmfs](https://cernvm.cern.ch/portal/filesystem), a filesystem, as an example:

```
$ stat -t /cvmfs/cms.cern.ch
stat: cannot stat '/cvmfs/cms.cern.ch': No such file or directory
$ ./vc3-builder --require cvmfs
./vc3-builder --require cvmfs
..Plan:    cvmfs => [, ]
..Try:     cvmfs => v2.4.0
..Refining version: cvmfs v2.4.0 => [, ]
....Plan:    cvmfs-parrot-libcvmfs => [v2.4.0, ]
....Try:     cvmfs-parrot-libcvmfs => v2.4.0
....Refining version: cvmfs-parrot-libcvmfs v2.4.0 => [v2.4.0, ]
......Plan:    parrot-wrapper => [v6.0.0, ]
......Try:     parrot-wrapper => v6.0.0
......Refining version: parrot-wrapper v6.0.0 => [v6.0.0, ]
........Plan:    cctools => [v6.0.0, ]
........Try:     cctools => v6.2.5
........Refining version: cctools v6.2.5 => [v6.0.0, ]
..........Plan:    cctools-binary => [v6.2.5, ]

... etc ...

sh-4.1$ stat -t /cvmfs/cms.cern.ch 
/cvmfs/cms.cern.ch 4096 9 41ed 0 0 1 256 1 0 1 1409299789 1409299789 1409299789 0 65336
```

In this case, the filesystem cvmfs is not provided natively and the builder tries to fulfill the requirement using the [parrot virtual file system](http://ccl.cse.nd.edu/software/parrot).

The *vc3-builder* includes a repository of recipes


OPTIONS
-------

Option                        | Description                                                      
----------------------------- | ------------
command-and-args              |  defaults to an interactive shell.
--database=\<catalog\>        |  defaults to \<internal\> if available, otherwise to `./vc3-catalog.json.` May be specified several times, with latter package recipes overwriting previous ones.
--install=\<root\>            |  Install with base \<root\>. Default is `vc3-root`.
--home=\<home\>               |  Set \${HOME} to \<root\>/\<home\> if \<home\> is a relative path, otherwise to \<home\> if it is an absolute path. Default is `vc3-home`.
--distfiles=\<dir\>           |  Directory to cache unbuilt packages locally. Default is `vc3_distfiles`
--repository=\<url\>          |  Site to fetch packages if needed. Default is the vc3 repository.
--require-os=\<name\>         |  Ensure the operating system is \<name\>. May use a container to fulfill the requirement. May be specified several times, but only the last occurance is honored. Use --list=os for a list of available operating systems.
--mount=/\<x\>                |  Ensure that path /\<x\> is exists inside the execution environment. If using --require-os with a non-native operating system, it is equivalent to --mount /\<x\>:/\<x\>
--mount=/\<x\>:/\<y\>         |  Mount path \<x\> into path \<y\> inside the execution environment. When executing in a native operating system, \<x\> and \<y\> cannot be different paths.
--force                       |  Reinstall the packages named with --require and the packages they depend on.
--make-jobs=\<n\>             |  Concurrent make jobs. Default is 4.
--sh-on-error                 |  On building error, run $shell on the partially-built environment.
--sys=package:version=\<dir\> |  Assume \<dir\> to be the installation location of package:version in the system. (e.g. --sys python:2.7=/opt/local/)
--no-sys=\<package\>          |  Do not use host system version of \<package\>. If package is 'ALL', do not use system versions at all. (Ignored if package specified with --sys.)
--var=NAME=VALUE              |  Add environment variable NAME with VALUE. May be specified several times.
--revar=PATTERN               |  All environment variables matching the regular expression PATTERN are preserved. (E.g. --revar "SGE.\*", --revar NAME is equivalent to -var NAME=\$NAME)
--interactive                 |  Treat command-and-args as an interactive terminal.
--silent                      |  Do not print dependency information.
--no-run                      |  Set up environment, but do not execute any payload.
--timeout=SECONDS             |  Terminate after SECONDS have elapased. If 0, then the timeout is not activated (default).
--env-to=\<file\>             |  Write environment script to \<file\>.{,env,payload}, but do not execute command-and-args. To execute command-and-args, run ./\<file\>.
--dot=\<file\>                |  Write a dependency graph of the requirements to \<file\>.
--parallel=\<dir\>            |  Write specifications for a parallel build to \<dir\>.
--list                        |  List general packages available.
--list=section                |  List general packages available, classified by sections.
--list=all                    |  List all the packages available, even vc3-internals.


COMPILING THE BUILDER AS A STATIC BINARY
----------------------------------------

```
git clone https://github.com/vc3-project/vc3-builder.git
cd vc3-builder
make vc3-builder-static
```

The static version will be available at **vc3-builder-static**. 
The steps above set a local [musl-libc](https://www.musl-libc.org) installation that compile **vc3-builder** into a [static perl](http://software.schmorp.de/pkg/App-Staticperl.html) interpreter.







WRITING RECIPES
---------------

REFERENCE
---------

Benjamin Tovar, Nicholas Hazekamp, Nathaniel Kremer-Herman, and Douglas Thain.
**Automatic Dependency Management for Scientific Applications on Clusters,**
IEEE International Conference on Cloud Engineering (IC2E), April, 2018. 

