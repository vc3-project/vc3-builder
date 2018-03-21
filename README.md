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

**vc3-builder** is a self-contained program that if desired, can be compiled to
a truly static binary (see below).

EXAMPLES
--------

```
    vc3-builder --require cvmfs -- ls /cvmfs/atlas.cern.ch
    vc3-builder --require-os redhat6 --mount /var/scratch:/work
```


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

Benjamin Tovar, Nicholas Hazekamp, Nathaniel Kremer-Herman, and Douglas Thain

**Automatic Dependency Management for Scientific Applications on Clusters,**

IEEE International Conference on Cloud Engineering (IC2E), April, 2018. 

