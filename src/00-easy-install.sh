#!/bin/bash

# easy install for gitolite

# you run this on the client side, and it takes care of all the server side
# work.  You don't have to do anything on the server side directly

# to do a manual install (since I have tested this only on Linux), open this
# script in a nice, syntax coloring, text editor and follow the instructions
# prefixed by the word "MANUAL" in the comments below :-)

# run without any arguments for "usage" info

# important setting: bail on any errors (else we have to check every single
# command!)
set -e

die() { echo "$@"; echo; echo "run $0 again without any arguments for help and tips"; exit 1; }
prompt() {
    # receives two arguments.  A short piece of text to be displayed, without
    # pausing, in "quiet" mode, and a much longer one to be displayed, *with*
    # a pause, in normal (verbose) mode
    [[ $quiet == -q ]] && [[ -n $1 ]] && {
        echo "$1"
        return
    }
    shift
    echo
    echo
    echo ------------------------------------------------------------------------
    echo "    $1"
    echo
    read -p '...press enter to continue or Ctrl-C to bail out'
}
usage() {
    cat <<EOFU
Usage: $0 [-q] user host port admin_name

  - (optional) "-q" as first arg sets "quiet" mode: no verbose descriptions of
    what is going on, no pauses unless absolutely necessary
  - "user" is the username on the server where you will be installing gitolite
  - "host" is that server's hostname (or IP address is also fine)
  - "port" is optional
  - "admin_name" is *your* name as you want it to appear in the eventual
    gitolite config file

Example usage: $0 git my.git.server sitaram

Notes:
  - "user" and "admin_name" must be simple names -- no special characters etc
    please (only alphanumerics, dot, hyphen, underscore)
  - traditionally, the "user" is "git", but it can be anything you want
  - "admin_name" should be your name, for clarity, or whoever will be the
    gitolite admin

Pre-requisites:
  - you must run this from the gitolite working tree top level directory.
    This means you run this as "src/00-easy-install.sh"
  - you must already have pubkey based access to user@host.  If you currently
    only have password access, use "ssh-copy-id" or something equivalent (or
    copy the key manually).  Somehow (doesn't matter how), get to the point
    where you can type "ssh user@host" and get a command line.

            **DO NOT RUN THIS PROGRAM UNTIL THAT WORKS**

EOFU
    exit 1;
}

# ----------------------------------------------------------------------
# basic sanity / argument checks
# ----------------------------------------------------------------------

# MANUAL: this *must* be run as "src/00-easy-install.sh", not by cd-ing to src
# and then running "./00-easy-install.sh"

[[ $0 =~ ^src/00-easy-install.sh$ ]] ||
{
    echo "please cd to the gitolite repo top level directory and run this as
    'src/00-easy-install.sh'"
    exit 1;
}

# are we in quiet mode?
quiet=
[[ "$1" == "-q" ]] && {
    quiet=-q
    shift
}

# MANUAL: (info) we'll use "git" as the user, "server" as the host, and
# "sitaram" as the admin_name in example commands shown below, if any

[[ -z $3 ]] && usage
user=$1
host=$2
admin_name=$3
# but if the 3rd arg is a number, that's a port number, and the 4th arg is the
# admin_name
port=22
[[ $3 =~ ^[0-9]+$ ]] && {
    port=$3
    [[ -z $4 ]] && usage
    admin_name=$4
}

[[ "$user" =~ [^a-zA-Z0-9._-] ]] && die "user '$user' invalid"
[[ "$admin_name" =~ [^a-zA-Z0-9._-] ]] && die "admin_name '$admin_name' invalid"

# MANUAL: make sure you're in the gitolite directory, at the top level.
# The following files should all be visible:

ls src/gl-auth-command  \
    src/gl-compile-conf \
    src/install.pl  \
    src/update-hook.pl  \
    conf/example.conf   \
    conf/example.gitolite.rc    >/dev/null ||
    die "cant find at least some files in gitolite sources/config; aborting"

# MANUAL: make sure you have password-less (pubkey) auth on the server.  That
# is, running "ssh git@server" should log in straight away, without asking for
# a password

ssh -p $port -o PasswordAuthentication=no $user@$host true ||
    die "pubkey access didn't work; please set it up using 'ssh-copy-id' or something"

# MANUAL: if needed, make a note of the version you are upgrading from, and to

# record which version is being sent across; we assume it's HEAD
git describe --tags --long HEAD 2>/dev/null > src/VERSION || echo '(unknown)' > src/VERSION

# what was the old version there?
export upgrade_details="you are upgrading from \
$(ssh -p $port $user@$host cat gitolite-install/src/VERSION 2>/dev/null || echo '(unknown)' ) \
to $(cat src/VERSION)"

prompt "$upgrade_details" \
    "$upgrade_details

    Note: getting '(unknown)' for the 'from' version should only happen once.
    Getting '(unknown)' for the 'to' version means you are probably installing
    from a tar file dump, not a real clone.  This is not an error but it's
    nice to have those version numbers in case you need support.  Try and
    install from a clone"

# MANUAL: create a new key for you as a "gitolite user" (as opposed to you as
# the "gitolite admin" who needs to login to the server and get a command
# line).  For example, "ssh-keygen -t rsa ~/.ssh/sitaram"; this would create
# two files in ~/.ssh (sitaram and sitaram.pub)

prompt "setting up keypair..." \
    "the next command will create a new keypair for your gitolite access

    The pubkey will be $HOME/.ssh/$admin_name.pub.  You will have to choose a
    passphrase or hit enter for none.  I recommend not having a passphrase for
    now, *especially* if you do not have a passphrase for the key which you
    are already using to get server access!

    Add one using 'ssh-keygen -p' after all the setup is done and you've
    successfully cloned and pushed the gitolite-admin repo.  After that,
    install 'keychain' or something similar, and add the following command to
    your bashrc (since this is a non-default key)

        ssh-add \$HOME/.ssh/$admin_name

    This makes using passphrases very convenient."

if [[ -f $HOME/.ssh/$admin_name.pub ]]
then
    prompt "    ...reusing $HOME/.ssh/$admin_name.pub..." \
    "Hmmm... pubkey $HOME/.ssh/$admin_name.pub exists; should I just re-use it?
    Be sure you remember the passphrase, if you gave one when you created it!"
else
    ssh-keygen -t rsa -f $HOME/.ssh/$admin_name || die "ssh-keygen failed for some reason..."
fi

# MANUAL: copy the pubkey created to the server, say to /tmp.  This would be
# "scp ~/.ssh/sitaram.pub git@server:/tmp" (the script does this at a later
# stage, you do it now for convenience).  Note: only the pubkey (sitaram.pub).
# Do NOT copy the ~/.ssh/sitaram file -- that is a private key!

# MANUAL: if you're running ssh-agent (see if you have an environment variable
# called SSH_AGENT_PID in your "env"), you should add this new key.  The
# command is "ssh-add ~/.ssh/sitaram"

if ssh-add -l &>/dev/null
then
    prompt "    ...adding key to agent..." \
    "you're running ssh-agent.  We'll try and do an ssh-add of the
    private key we just created, otherwise this key won't get picked up.  If
    you specified a passphrase in the previous step, you'll get asked for one
    now -- type in the same one."

    ssh-add $HOME/.ssh/$admin_name
fi

# MANUAL: you now need to add some lines to the end of your ~/.ssh/config
# file.  If the file doesn't exist, create it.  Make sure the file is "chmod
# 644".

# The lines to be included look like this:

#   host gitolite
#       user git
#       hostname server
#       port 22
#       identityfile ~/.ssh/sitaram

echo "
host gitolite
     user $user
     hostname $host
     port $port
     identityfile ~/.ssh/$admin_name" > $HOME/.ssh/.gl-stanza

if grep 'host  *gitolite' $HOME/.ssh/config &>/dev/null
then
    prompt "found gitolite para in ~/.ssh/config; assuming it is correct..." \
    "your \$HOME/.ssh/config already has settings for gitolite.  I will
    assume they're correct, but if they're not, please edit that file, delete
    that paragraph (that line and the following few lines), Ctrl-C, and rerun.

    In case you want to check right now (from another terminal) if they're
    correct, here's what they are *supposed* to look like:
$(cat ~/.ssh/.gl-stanza)"

else
    prompt "creating gitolite para in ~/.ssh/config..." \
    "creating settings for your gitolite access in $HOME/.ssh/config;
    these are the lines that will be appended to your ~/.ssh/config:
$(cat ~/.ssh/.gl-stanza)"

    cat $HOME/.ssh/.gl-stanza >> $HOME/.ssh/config
    # if the file didn't exist at all, it might have the wrong permissions
    chmod 644 $HOME/.ssh/config
fi
rm  $HOME/.ssh/.gl-stanza

# ----------------------------------------------------------------------
# client side stuff almost done; server side now
# ----------------------------------------------------------------------

# MANUAL: copy the gitolite directories "src", "conf", and "doc" to the
# server, to a directory called (for example) "gitolite-install".  You may
# have to create the directory first.

ssh -p $port $user@$host mkdir -p gitolite-install
rsync $quiet -e "ssh -p $port" -a src conf doc $user@$host:gitolite-install/
rm -f src/VERSION

# MANUAL: now log on to the server (ssh git@server) and get a command line.
# This step is for your convenience; the script does it all from the client
# side but that may be too much typing for manual use ;-)

# MANUAL: cd to the "gitolite-install" directory where the sources are.  Then
# copy conf/example.gitolite.rc as ~/.gitolite.rc and edit it if you wish to
# change any paths.  Make a note of the GL_ADMINDIR and REPO_BASE paths; you
# will need them later

prompt "finding/creating gitolite rc..." \
    "the gitolite rc file needs to be edited by hand.  The defaults
    are sensible, so if you wish, you can just exit the editor.

    Otherwise, make any changes you wish and save it.  Read the comments to
    understand what is what -- the rc file's documentation is inline.

    Please remember this file will actually be copied to the server, and that
    all the paths etc. represent paths on the server!"

# lets try and get the file from there first
if scp -P $port $user@$host:.gitolite.rc . &>/dev/null
then
    prompt "    ...trying to reuse existing rc" \
    "Oh hey... you already had a '.gitolite.rc' file on the server.
    Let's see if we can use that instead of the default one..."
    sort < .gitolite.rc             | perl -ne 'print "$1\n" if /^\s*(\$\w+) *=/' > glrc.old
    sort < conf/example.gitolite.rc | perl -ne 'print "$1\n" if /^\s*(\$\w+) *=/' > glrc.new
    if diff -u glrc.old glrc.new
    then
        [[ $quiet == -q ]] || ${VISUAL:-${EDITOR:-vi}} .gitolite.rc
    else
        prompt "" \
        "    looks like you're upgrading, and there are some new rc variables
        that this version is expecting that your old rc file doesn't have.

        I'm going to run your editor with two filenames.  The first is the
        example file from this gitolite version.  It will have a block (code
        and comments) for each of the variables shown above with a '+' sign.

        The second is your current rc file, the destination.  Copy those lines
        into this file, preferably *with* the surrounding comments (for
        clarity) and save it.

        This is necessary; please dont skip this!

        [It's upto you to figure out how your editor handles 2 filename
        arguments, switch between them, copy lines, etc ;-)]"

        ${VISUAL:-${EDITOR:-vi}} conf/example.gitolite.rc .gitolite.rc
    fi
else
    cp conf/example.gitolite.rc .gitolite.rc
    [[ $quiet == -q ]] || ${VISUAL:-${EDITOR:-vi}} .gitolite.rc
fi

# copy the rc across
scp $quiet -P $port .gitolite.rc $user@$host:

prompt "installing/upgrading..." \
    "ignore any 'please edit this file' or 'run this command' type
    lines in the next set of command outputs coming up.  They're only relevant
    for a manual install, not this one..."

# extract the GL_ADMINDIR and REPO_BASE locations
GL_ADMINDIR=$(ssh -p $port $user@$host "perl -e 'do \".gitolite.rc\"; print \$GL_ADMINDIR'")
REPO_BASE=$(  ssh -p $port $user@$host "perl -e 'do \".gitolite.rc\"; print \$REPO_BASE'")

# MANUAL: still in the "gitolite-install" directory?  Good.  Run
# "src/install.pl"

ssh -p $port $user@$host "cd gitolite-install; src/install.pl $quiet"

# MANUAL: if you're upgrading, just go to your clone of the admin repo, make a
# dummy change, and push.  (This assumes that you didn't change the
# admin_name, pubkeys, userids, ports, or whatever, and you ran easy install
# only to upgrade the software).  And then you are **done** -- ignore the rest
# of this file for the purposes of an upgrade

# determine if this is an upgrade; we decide based on whether a pubkey called
# $admin_name.pub exists in $GL_ADMINDIR/keydir on the remote side
upgrade=0
if ssh -p $port $user@$host cat $GL_ADMINDIR/keydir/$admin_name.pub &> /dev/null
then
    prompt "done!

    If you forgot the help message you saw when you first ran this, there's a
    somewhat generic version of it at the end of this file.  Try:

        tail -30 $0
" \
    "this looks like an upgrade, based on the fact that a file called
    $admin_name.pub already exists in $GL_ADMINDIR/keydir on the server.

    Please go to your clone of the admin repo, make a dummy change (like maybe
    add a blank line to something), commit, and push.  You're done!

    (This assumes that you didn't change the admin_name, pubkeys, userids,
    ports, or whatever, and you ran easy install only to upgrade the
    software)."

    exit 0

fi

# MANUAL: setup the initial config file.  Edit $GL_ADMINDIR/conf/gitolite.conf
# and add at least the following lines to it:

#   repo gitolite-admin
#       RW+                 = sitaram

echo "#gitolite conf
# please see conf/example.conf for details on syntax and features

repo gitolite-admin
    RW+                 = $admin_name

repo testing
    RW+                 = @all

" > gitolite.conf

# send the config and the key to the remote
scp $quiet -P $port gitolite.conf $user@$host:$GL_ADMINDIR/conf/
scp $quiet -P $port $HOME/.ssh/$admin_name.pub $user@$host:$GL_ADMINDIR/keydir

# MANUAL: cd to $GL_ADMINDIR and run "src/gl-compile-conf"
ssh -p $port $user@$host "cd $GL_ADMINDIR; src/gl-compile-conf $quiet"

# ----------------------------------------------------------------------
# hey lets go the whole hog on this; setup push-to-admin!
# ----------------------------------------------------------------------

# MANUAL: you have to now make the first commit in the admin repo.  This is
# a little more complex, so read carefully and substitute the correct paths.
# What you have to do is:

#   cd $REPO_BASE/gitolite-admin.git
#   GIT_WORK_TREE=$GL_ADMINDIR git add conf/gitolite.conf keydir
#   GIT_WORK_TREE=$GL_ADMINDIR git commit -am start

# Substitute $GL_ADMINDIR and $REPO_BASE appropriately.  Note there is no
# space around the "=" in the second and third lines.

echo "cd $REPO_BASE/gitolite-admin.git
GIT_WORK_TREE=$GL_ADMINDIR git add conf/gitolite.conf keydir
GIT_WORK_TREE=$GL_ADMINDIR git commit -am start --allow-empty
" | ssh -p $port $user@$host

# MANUAL: now that the admin repo is created, you have to set the hooks
# properly.  The install program does this.  So cd back to the
# "gitolite-install" directory and run "src/install.pl"

ssh -p $port $user@$host "cd gitolite-install; src/install.pl $quiet"

# MANUAL: you're done!  Log out of the server, come back to your workstation,
# and clone the admin repo using "git clone gitolite:gitolite-admin.git", or
# pull once again if you already have a clone

prompt "cloning gitolite-admin repo..." \
"now we will clone the gitolite-admin repo to your workstation
    and see if it all hangs together.  We'll do this in your \$HOME for now,
    and you can move it elsewhere later if you wish to."

cd $HOME
git clone gitolite:gitolite-admin.git

# MANUAL: be sure to read the message below; this applies to you too...

echo
echo
echo ------------------------------------------------------------------------
echo "
All done!

The admin repo is currently cloned at ~/gitolite-admin; you can clone it
anywhere you like.  To administer gitolite, make changes to the config file
(config/gitolite.conf) and/or the pubkeys (in subdirectory 'keydir') in any
clone, then git add, git commit, and git push.

ADDING REPOS: Edit the config file to give *some* user access to the repo.
When you push, an empty repo will be created on the server, which authorised
users can then clone from, or push to.

ADDING USERS: copy their pubkey as keydir/<username>.pub, add it, commit and
push.

CONFIG FILE FORMAT: see comments in conf/example.conf in the gitolite source.

SSH MAGIC: Remember you (the admin) now have *two* keys to access the server
hosting your gitolite setup -- one to get you a command line, and one to get
you gitolite access; see doc/6-complex-ssh-setups.mkd.  If you're not using
keychain or some such software, you may have to run this each time you log in:

    ssh-add ~/.ssh/$admin_name

URLS:  *Your* URL for cloning any repo on this server will be

    gitolite:reponame.git

*Other* users you set up will have to use

    $user@$host:reponame.git
"