# Rebuild Montagu System

This file describes bootstrapping the configuring of the entire Montagu system of machines. It should not be done
routinely but documents what was done, and what could be done to start again with fresh keys, or on fresh machines.

### Generate keys

First generate keys.  This can be done on any machine, with this repo checked out, at the root directory

```
privateer keygen --all
```

You will be able to see keys in the vault:

```
$ vault list /secret/vimc/privateer
Keys
----
annex
annex2
keys/
production
production2
science
testing/
uat
```

### Configure hosts

Configure the servers (`annex` and `annex2`) first, then the clients.

### annex2

This is the new machine that holds our backups.

```
privateer configure annex2
privateer server start
```

This pulls the appropriate keys and starts the ssh server that will recieve backups from the clients.

### annex1

This is the old machine that used to hold backups.  It is quite slow, and the disks are very slow.

```
privateer configure annex
privateer server start
```

This pulls the appropriate keys and starts the ssh server that will recieve backups from the clients.

### Client machines

For all of `production2`, `science` and `uat` the basic setup is

```
privateer configure production2 # or other name
privateer check --connection
```

which checks that everything looks ok

For `production2` you can schedule a daily backup of the orderly volume with

```
privateer schedule start
```

(NB I think that this is not currently working! Oct 2025)
