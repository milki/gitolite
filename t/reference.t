#!/usr/bin/perl
use strict;
use warnings;

# this is hardcoded; change it if needed
use lib "src/lib";
use Gitolite::Test;
my $h = $ENV{HOME};

# fork command
# ----------------------------------------------------------------------

try "plan 14";

my $rb = `gitolite query-rc -n GL_REPO_BASE`;

try "sed -ie 's%.Mirroring.,%\"Mirroring\",\\n\"create-with-reference\",%' ~/.gitolite.rc";

confreset;confadd '

    repo source
        RW+ = u1 u2

    repo fork
        RW+ = u1 u2
    option reference.repo = source

    repo notfork
        RW+ = u1 u2
    option reference.repo = non-existent
';

try "
    ADMIN_PUSH set1; !/FATAL/
                      /Reference repo non-existent is not a gitolite repo/

" or die text();

try " # Verify files
    # source doesn't have alternates
    ls $rb/source.git/objects/info/alternates;  !ok

    # fork has source as an alternate
    ls $rb/fork.git/objects/info/alternates;   ok
    cat $rb/fork.git/objects/info/alternates;  ok;  /$rb/source.git/objects/

    # notfork doesn't have alternates
    ls $rb/notfork.git/objects/info/alternates;  !ok
";
