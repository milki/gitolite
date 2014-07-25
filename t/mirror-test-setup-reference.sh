#!/bin/bash

set -e
hosts="frodo sam"
mainhost=frodo

# setup software
bd=`gitolite query-rc -n GL_BINDIR`
mkdir -p /tmp/g3
rm -rf /tmp/g3/src
cp -a $bd /tmp/g3/src
chmod -R go+rX /tmp/g3

# setup symlinks in frodo and sam's accounts
for h in $hosts
do
    sudo -u $h -i bash -c "rm -rf *.pub bin .ssh projects.list repositories .gitolite .gitolite.rc"
done

[ "$1" = "clear" ] && exit

cd /tmp/g3
[ -d keys ] || {
    mkdir keys
    cd keys
    for h in $hosts
    do
        ssh-keygen -N '' -q -f server-$h  -C $h
        chmod go+r /tmp/g3/keys/server-$h
    done
    cp $bd/../t/mirror-test-ssh-config ssh-config
}
chmod -R go+rX /tmp/g3

for h in $hosts
do
    sudo -u $h -i bash -c "mkdir -p bin; ln -sf /tmp/g3/src/gitolite bin; mkdir -p .ssh; chmod 0700 .ssh"

    sudo -u $h -i cp /tmp/g3/keys/ssh-config    .ssh/config
    sudo -u $h -i cp /tmp/g3/keys/server-$h     .ssh/id_rsa
    sudo -u $h -i cp /tmp/g3/keys/server-$h.pub .ssh/id_rsa.pub
    sudo -u $h -i chmod go-rwx                  .ssh/id_rsa .ssh/config

done

# add all pubkeys to all servers
for h in $hosts
do
    sudo -u $h -i gitolite setup -a admin
    for j in $hosts
    do
        sudo -u $h -i gitolite setup -pk /tmp/g3/keys/server-$j.pub
        echo sudo _u $j _i ssh $h@localhost info
        sudo -u $j -i ssh -o StrictHostKeyChecking=no $h@localhost info
    done
    echo ----
done

# now copy our admin key to the main host
cd;cd .ssh
cp $bd/../t/keys/admin id_rsa; cp $bd/../t/keys/admin.pub id_rsa.pub
chmod go-rwx id_rsa
cp $bd/../t/keys/admin.pub /tmp/g3/keys; chmod go+r /tmp/g3/keys/admin.pub
sudo -u $mainhost -i gitolite setup -pk /tmp/g3/keys/admin.pub
ssh $mainhost@localhost info

lines="
repo gitolite-admin
    option mirror.master = frodo
    option mirror.slaves-1 = sam
    option mirror.redirectOK = sam

include \"%HOSTNAME.conf\"
"

# for each server, set the HOSTNAME to the rc, add the mirror options to the
# conf file, and compile
for h in $hosts
do
    cat $bd/../t/mirror-test-rc | perl -pe "s/%HOSTNAME/$h/" > /tmp/g3/temp
    chmod go+rX /tmp/g3/temp
    sudo -u $h -i cp /tmp/g3/temp .gitolite.rc
    echo "$lines"  | sudo -u $h -i sh -c 'cat >> .gitolite/conf/gitolite.conf'
    sudo -u $h -i gitolite setup
done

referencerepos="
repo big-reference-repo
RW  =   admin
option mirror.master = frodo
option mirror.slaves = sam

repo big-fork
RW  =   admin
option mirror.master = frodo
option mirror.slaves = sam
option reference.repo = big-reference-repo

repo empty-reference-repo
RW  =   admin
option mirror.master = frodo
option mirror.slaves = sam

repo empty-fork
RW  =   admin
option mirror.master = frodo
option mirror.slaves = sam
option reference.repo = empty-reference-repo
";

echo "$referencerepos" | sudo -u frodo -i sh -c "cat >> .gitolite/conf/frodo.conf";
echo "$referencerepos" | sudo -u sam -i sh -c "cat >> .gitolite/conf/sam.conf";
for h in $hosts
do
    sudo -u $h -i gitolite setup;
done

# that ends the setup phase
echo ======================================================================
