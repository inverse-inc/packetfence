#include <unistd.h>
#ifndef REAL_PATH
#define REAL_PATH "/usr/local/pf/bin/pfcmd.pl"
#endif
int main(ac, av)
char **av;
{
    execv(REAL_PATH, av);
    return 0;
}
