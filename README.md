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

As another example, the builder provides support for [cvmfs](https://cernvm.cern.ch/portal/filesystem):

```
$ stat -t /cvmfs/cms.cern.ch
stat: cannot stat '/cvmfs/cms.cern.ch': No such file or directory
$ ./vc3-builder --require cvmfs
./vc3-builder --require cvmfs
..Plan:    cvmfs => [, ]
..Try:     cvmfs => v2.4.0
..Refining version: cvmfs v2.4.0 => [, ]
....Plan:    cvmfs-parrot-libcvmfs => [v2.4.0, ]

... etc ...

sh-4.1$ stat -t /cvmfs/cms.cern.ch 
/cvmfs/cms.cern.ch 4096 9 41ed 0 0 1 256 1 0 1 1409299789 1409299789 1409299789 0 65336
```

In this case, the filesystem `cvmfs is not provided natively and the builder
tries to fulfill the requirement using the [parrot virtual file system](http://ccl.cse.nd.edu/software/parrot).


The builder installs dependencies as needed. For example, simply requiring
`python` most likely will provide a python installation already in the system:

```
$ ./vc3-builder --require python                             
..Plan:    python => [, ]
..Try:     python => v2.7.5
..Refining version: python 2.7.5 => [, ]
..Success: python v2.7.5 => [, ]
processing for python-v2.7.5
sh-4.2$ which python
/bin/python
sh-4.2$ 
```

However, if we require the specific version:

```
$ ./vc3-builder --require python:2.7.12
..Plan:    python => [2.7.12, ]
..Try:     python => v2.7.5
..Incorrect version: v2.7.5 => [v2.7.12,]
..Try:     python => v2.7.12
..Refining version: python v2.7.12 => [v2.7.12, ]
....Plan:    libffi => [v3.2.1, ]
....Try:     libffi => v3.2.1
....Refining version: libffi v3.2.1 => [v3.2.1, ]
....Success: libffi v3.2.1 => [v3.2.1, ]

... etc ...

sh-4.2$ which python
/home/btovar/vc3-root/x86_64/redhat7.4/python/v2.7.12/bin/python
```

Use `./vc3-builder --list` to obtain the current list of packages available.

HOME
----

By default, the HOME variable is to a directory created by the builder. This
can be changed using the `--home` option.

MOUNTING FILESYSTEMS
--------------------

The builder provides the `--mount` argument to optionally mount directories. It has two forms `--mount /x` and `--mount /x:/y`

#### --mount /x

If executing in the native host environment, the builder simply ensured that the directory `/x` is accessible. If not, it terminates with an error.

If providing the environment with a container, the host environment path `/x` is mounted inside the container as `/x`.

#### --mount /x:/y

If executing in the native host environment, and `/x` and `/y` are
different, the builder reports an error, otherwise it works as `--mount /x`.

When executing inside a container, the host environment path `/x` is mounted
inside the container as `/y`.

Even when the host operating system fulfills the `--require-os` argument, a
container may still be used to fulfill a `--mount` requirement:

```
$ ./vc3-builder --require-os redhat7 --mount /var/scratch/btovar:/madeuppath -- stat -t /madeuppath
OS trying:         redhat7 os-native
Mount source '/var/scratch/btovar' and target '/madeuppath' are different.
OS fail mounts:    redhat7 os-native
OS trying:         redhat7 singularity
/madeuppath 4096 8 41ed 196886 0 805 5111810 5 0 0 1520946165 1517595650 1517595650 0 4096
$
```

PARALLEL BUILD MODE
-------------------

If a shared filesystem is available, the builder can be instructed to execute
builds in parallel.  Only steps that can be executed concurrently, and for
which their dependencies are already fulfilled are queued for execution.

For parallel build installations, use the `--parallel` option. It receives one
argument, a directory to create the parallel build sandbox inside the builder's
home dir. For example, to build the bioinformatics pipeline `maker` in parallel
mode using SLURM:

```
$ ./vc3-builder --require maker --install /scratch365/b/btovar/my-shared-dir --parallel my-parallel-build --parallel-mode slurm

(... clipped build information...)

Parallel build mode complete. To run type:

VC3_ROOT=/scratch365/b/btovar/my-shared-dir
VC3_DB=/scratch365/b/btovar/my-shared-dir/my-parallel-build/recipes

./vc3-builder --database ${VC3_DB} --install ${VC3_ROOT} --require maker

```

In addition to SLURM, other batch systems available are `condor`, `slurm`,
`sge`, `torque`, `moab`, `amazon`, `workqueue` and `local`. If a mode is not
specified, `local` is used.  `local` may also be used.


RECIPES
-------

The **vc3-builder** includes a repository of recipes. To list the packages available for the `--require` option, use:

```
./vc3-builder --list
atlas-local-root-base-environment:v1.0
augustus:v2.4
cctools:v6.2.5
cctools-unstable:v7.0.0
charm:v6.7.1
cmake:auto
cmake:v3.10.2
... etc ...
```

For operating systems accepted by the `--require-os` option use:

```
./vc3-builder --list=os    
debian9:auto
debian9:v9.2
opensuse42:auto
opensuse42:v42.3
redhat6:auto
redhat6:v6.9
redhat7:auto
redhat7:v7.4
ubuntu16:auto
ubuntu16:v16
```

When a version appears as **auto**, it means that the builder knows how to
recognize that the correspoding requirement is already supplied by the host
system.


### WRITING RECIPES

The builder can be provided with additional package recipes using the
--database=\<catalog\> option. The option can be specified several times, with
latter package recipes overwriting previous ones. 

The --database option accepts directory or file names. If a directory, it is
searched recursevely for files with the `.json` extension. Files are read in
lexicographical order.

A recipe catalog is a JSON encoded object, in which the keys of the object are
the names of the packages. Each package is a JSON object that, among other
fields, specifies a list of versions of the package and a recipe to fulfill
that version.

#### Recipes that provide packages

As an example, we will write the recipes for `wget`. First as a generic recipe,
and then with different specific support that builder provides.

##### A generic recipe:

```json
$ cat my-wget-recipe.json
{
    "wget":{
        "versions":[
            {
                "version":"v1.19.4",
                "source":{
                    "type":"generic",
                    "files":[ "wget-1.19.4.tar.gz" ],
                    "recipe":[
                        "tar xf wget-1.19.4.tar.gz",
                        "./configure --prefix=${VC3_PREFIX} --with-zlib --with-ssl=openssl --with-libssl-prefix=${VC3_ROOT_OPENSSL} --with-libuuid",
                        "make",
                        "make install"
                    ],
                    "dependencies":{
                        "zlib":[ "v1.2" ],
                        "openssl":[ "v1.0.2" ],
                        "uuid":[ "v1.0" ],
                        "libssh2":[ "v1.8.0" ]
                    }
                }
            }
        ],
        "environment-variables":[
               {
                "name":"PATH",
                "value":"bin"
               }
        ]
    }
}
```

The field `versions` inside the package definition is a list of JSON objects,
with each object providing the recipe for a version. The files listed in
`files` are automatically downloaded from the site pointed by the --repository
option. The lines in the `recipe` field are executed one by one inside a shell.

Dependencies list the name of the package and a range of acceptable versions.
If only one version is provided, it is taken as a minimum acceptable version.
Dependencies can be specified per version, as in this case, or per package, in
which case they are applied to all the versions.

During the recipe execution, several environment variables are available. For
example, VC3_PREFIX, which points to the package installation directory. Each
package is installed into its own directory. Also, for each of the
dependencies, a VC3_ROOT_dependency variable points to the dependency
installation directory.

When `wget` is set as a requirement, the value of `$VC3_ROOT_WGET/bin` is added
to the `PATH`.

##### A tarball recipe:

We can refine the recipe above by using the `tarball` source type, which automatically untars the first file listed in `files`:

```json
{
    "wget":{
        "versions":[
            {
                "version":"v1.19.4",
                "source":{
                    "type":"tarball",
                    "files":[ "wget-1.19.4.tar.gz" ],
                    "recipe":[
                        "./configure --prefix=${VC3_PREFIX} --with-zlib --with-ssl=openssl --with-libssl-prefix=${VC3_ROOT_OPENSSL} --with-libuuid",
                        "make",
                        "make install"
                    ]
                }
            }
        ],
 "... etc ..."
```

##### A configure recipe:

Further, we can do without the recipe using the `configure` type:

```json
{
    "wget":{
        "versions":[
            {
                "version":"v1.19.4",
                "source":{
                    "type":"configure",
                    "files":[ "wget-1.19.4.tar.gz" ],
                    "options":"--with-zlib --with-ssl=openssl --with-libssl-prefix=${VC3_ROOT_OPENSSL} --with-libuuid",
                }
            }
        ],
 "... etc ..."
```

For the `configure` type, there are also the `preface` and `postface` fields.
They are lists of shell commands (as `recipe`), that execute before and after,
respectively, of the `configure; make; make install` step.

##### Adding a binary distribution

```json
 "wget":{
        "versions":[
            {
               "version":"v1.81",
                "source":{
                    "type":"binary",
                    "native":"x86_64",
                    "files":[
                        "wget-1.18-1.tar.gz"
                    ]
                }
            },
            {
                "version":"v1.19.4",
                "source":{
                    "type":"configure",
 "... etc ..."
```

We include the `binary` version before the `configure` version as they are
tried sequentially, and we would prefer not to build `wget` if it is not
necessary. The tarball provided includes a statically linked version of `wget`,
and the architecture requirement is specified with the `native` field.

Tarballs of binaries should have the file hierarchy: `dir/{bin,etc}`.

##### Adding auto-detection:

```json
 "wget":{
        "versions":[
            {
                "version":"auto",
                "source":{
                    "type":"system",
                    "executable":"wget"
                }
            },
            {
               "version":"v1.81",
                "source":{
                    "type":"binary",
 "... etc ..."
```

In this case, we simply provide the name of the executable to test, and the
builder will try to get the version number out of the first line of the output
from `executable --version`.

If an system executable does not provide version information in such manner,
`source` needs to provide an `auto-version` field that provides a recipe that
eventually prints to standard output a line such as:

```
VC3_VERSION_SYSTEM: xxx.yyy.zzz
```

For example, in `perl` the version information is provided by the `$^V`
variable, and the `auto-version` field would look like:

```json
...

        "auto-version":[
            "perl -e  'print(\"VC3_VERSION_SYSTEM: $^V\\n\");'"
        ],
...
```

Note that quotes and backslashes need to be escaped so that they are not
interpreted as part of the JSON structure.

##### The complete recipe

```json
{
    "wget":{
        "tags":["data transfer tools"],
        "show-in-list":1,
        "versions":[
            {
                "version":"auto",
                "source":{
                    "type":"system",
                    "executable":"wget"
                }
            },
            {
                "version":"v7.51",
                "source":{
                    "type":"binary",
                    "native":"x86_64",
                    "files":[
                        "wget-1.18-1.tar.gz"
                    ]
                }
            },
            {
                "version":"v1.19.4",
                "source":{
                    "type":"configure",
                    "files":[ "wget-1.19.4.tar.gz" ],
                    "options":"--with-zlib --with-ssl=openssl --with-libssl-prefix=${VC3_ROOT_OPENSSL} --with-libuuid",
                },
                "dependencies":{
                    "zlib":[
                        "v1.2"
                    ],
                    "openssl":[
                        "v1.0.2"
                    ],
                    "uuid":[
                        "v1.0"
                    ],
                    "libssh2":[
                        "v1.8.0"
                    ]
                }
            }
        ],
        "environment-autovars":[
            "PATH"
        ]
    },
}
```

We made three changes: 

- Added the `tags` field to classify the package. Listing of packages by tags is available with the `--list=section` option.
- Added `show-in-list` field, which allows the package to be displayed by `--list`.
- Since adding `${VC3_ROOT_package}/bin` to the `PATH` is a common operation,
the builder provides the "environment-autovars" field, which automatically
constructs common patterns for the variables `PATH`, `LD_LIBRARY_PATH`,
`PKG_CONFIG_PATH`, `LIBRARY_PATH`, `C_INCLUDE_PATH`, `CPLUS_INCLUDE_PATH`, and
`PERL5LIB`.  Support for `PYTHONPATH` is not provided, as there is not an easy
way to handle concurrent `python2` and `python3` installations.


#### Recipes that provide environments


##### Environment prologues 

It is sometimes required to run a command to complete setting the environment.
For example, a script containing evinronment variables may need to be sourced
before execution. For such cases, the `prologue` field can be used. The
following is an example for setting the [OSG
oasis](http://iopscience.iop.org/article/10.1088/1742-6596/513/3/032013/meta)
environment:

```json
"..."
"oasis-environment":{
        "versions":[
            {
                "version":"v1.0",
                "type":"generic",
                "prologue": [
                    "source /cvmfs/oasis.opensciencegrid.org/osg/modules/lmod/current/init/bash"
                ],
                "dependencies":{
                    "cvmfs":[
                        "v2.0"
                    ]
                }
            }
        ]
    },
"..."
```

The lines in the `prologue` field are executed for every new shell executed
inside the builder environment. Note that in this particular case there was no
need to provide a `source` field.


##### Environment wrappers 

A wrapper is any program that executes the payload of the builder. In the usual
case, there is no wrapper, and the builder simply executes its payload using
`/bin/sh`. In the [introductory examples](#description), we showed the builder
accessing a filesystem (cvmfs) that was not present in the host system. This
was done by using the [parrot virtual file
system](http://ccl.cse.nd.edu/software/parrot) as a wrapper as follows:

```json
 "parrot-wrapper":{
        "versions":[
            {
                "version":"v6.0.0",
                "wrapper":[
                    "parrot_run", "--dynamic-mounts", "{}"
                ],
                "dependencies":{
                    "cctools":[
                        "v6.0.0"
                    ]
                }
            }
        ]
```

The `parrot_run` executable is provided through the `cctools` dependency. The
wrapper itself is specified as a list of arguments in the `wrapper` field. The
payload is substituted in place of `{}`. If several wrappers are required, they
nest inner-to-outer as they appear as arguments to `--require` in the command
line.


##### Operating system recipes

Operating systems recipes are similar to package recipes, but they are labeled
with the `operating-system` field. An operating system requirement is specified
with the `--require-os` option.

Here we include an example for Red Hat 7:

```json
"..."
    "redhat7":{
        "tags":["operating systems"],
        "show-in-list":1,
        "operating-system":1,
        "versions":[
            {
                "version":"auto",
                "source":{
                    "type":"os-native",
                    "native":"x86_64/redhat7"
                }
            },
            {
                "version":"7.4",
                "source":{
                    "type":"singularity",
                    "image":"Singularity.vc3.x86_64-centos7.img"
                }
            }
        ]
    },
"..."
```

For the `os-native` type, the `native` field specifies the target system. It is
of the form `architecture/distribution`. Use `./vc3-builder --list=os` for a
list of known distributions.

In the `singularity` type, the image file provided is downloaded from
`<repository\>/images/singularity`, where repository is specified by the
`--repository` option. If the image is not file, but starts with `docker://` or
`shub://`, it is downloaded from the corresponding image repository.

#### Recipes bits-and-pieces

There are three more fields a version specification accepts:

- `prerequisites`: A list of shell commands which need to succed for the
version to be included in the build plan. Useful to check if some file is
present, for example.
- `phony`: In normal operation, the builder executes the recipe of a source
only once. If `phony` is set to `1`, the recipe is executed every time the
package is required.
- `local`: Only relevant for the [parallel build mode](#parallel-build-mode).
Indicates that the recipe should be executed locally, and not in a remote
computational node. It is useful when the recipe takes very little time
compared to scheduling it for parallel execution.


ADDING RECIPES TO THE vc3-builder EXECUTABLE
--------------------------------------------

First, clone the `vc3-builder` repository:

```
git clone https://github.com/vc3-project/vc3-builder.git
cd vc3-builder
```

Second, write any recipe files you want included in the `recipes` directory.
Recipe files names may not contain spaces.  Recipes may be organized in
directories, that are read recursevely. Files are read in lexicographical
order, with later recipe definitions overwriting previous ones if package names
are repeated.

Finally, use `make` to construct the new `vc3-builder` with your recipes included:

```
make clean vc3-builder
```




COMPILING THE BUILDER AS A STATIC BINARY
----------------------------------------

```
git clone https://github.com/vc3-project/vc3-builder.git
cd vc3-builder
make vc3-builder-static
```

The static version will be available at **vc3-builder-static**. 
The steps above set a local [musl-libc](https://www.musl-libc.org) installation that compile **vc3-builder** into a [static perl](http://software.schmorp.de/pkg/App-Staticperl.html) interpreter.



REFERENCE
---------

Benjamin Tovar, Nicholas Hazekamp, Nathaniel Kremer-Herman, and Douglas Thain.
**Automatic Dependency Management for Scientific Applications on Clusters,**
IEEE International Conference on Cloud Engineering (IC2E), April, 2018. 

