#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <pwd.h>
#include <grp.h>

int main(int argc, const char **argv, const char **envp) {

    if(argc < 4) {
        fprintf(stderr, "Use:\n\t %s uid gid executable args*\n", argv[0]);
        exit(1);
    }

    //skip this program's name, *argv is now uid
    argv++;

    char *end = NULL;
    long int uid = strtol(*argv, &end, 10);
    if((end && *end != '\0')  || uid < 0) {
        fprintf(stderr, "'%s' is not a valid uid.\n", *argv, end);
        exit(2);
    }

    //skip uid, *argv is now gid
    argv++;

    end = NULL;
    long int gid = strtol(*argv, &end, 10);
    if((end && *end != '\0')  || gid < 0) {
        fprintf(stderr, "'%s' is not a valid gid.\n", *argv);
        exit(2);
    }

    //skip gid, argv now points to the payload
    argv++;
    const char *executable = *argv;

    //check if uid is a valid user
    struct passwd *p = getpwuid(uid);
    if(!p) {
        fprintf(stderr, "No user has uid '%ld'.\n", uid);
        exit(3);
    }

    //check if gid is a valid user
    struct group *g = getgrgid(gid);
    if(!g) {
        fprintf(stderr, "No group has gid '%ld'.\n", gid);
        exit(3);
    }

    //drop to user's group. Before we drop uid otherwise we can't do it
    //anymore.
    if(setgid(gid) == -1) {
        fprintf(stderr, "Could not drop priviliges to gid '%ld'.\n", gid);
        exit(4);
    }

    //drop to user's uid
    if(setuid(uid) == -1) {
        fprintf(stderr, "Could not drop priviliges to uid '%ld'.\n", uid);
        exit(4);
    }

    execvpe(executable, argv, envp);

    fprintf(stderr, "Could not execute payload.\n");
    exit(5);
}

