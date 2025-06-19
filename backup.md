# Backup and restore

There are two bits of data that we spend effort backing up:

* the montagu db
* the orderly archive

There are other bits of persistant data that we might want to expand this approach to, but these are currently less important:

* the packit db (this will become important eventually)
* the orderly logs
* the packit redis data (not even persisted to a volume at present)

There's a lot of historical cruft and faffage through here, much of which is related to the postgres database.  Once we start our journey of deprecating that, things will become much easier, and the backup/restore path for orderly will be the main concern.

## Installation

You will need to run this on any machine that you are running commands from

```
pip3 install --user privateer~=2.1.0
```

Once installed, you can check the version by running

```
privateer --version
```

## Restore

This is most often done to restore onto `uat` or `science`, refreshing the data that is stored there.

### Orderly

This one is fairly easy, as we just need to copy the data over, for both the orderly and outpack volumes:

```
privateer restore montagu_orderly_volume --server=annex2 --source=production
privateer restore montagu_outpack_volume --server=annex2 --source=production
```

This can be done fairly safely while the system is running, with the exception that OrderlyWeb does use the SQLite database in the orderly volume.  As such, until we retire `orderly1`/OrderlyWeb it is probably best to do this after taking montagu down (run `./stop` from the `montagu-orderly-web` directory).

### Database

Generally, this will be pulling the `production2` database onto `uat` or `science`, and this is quite involved as we've never really got the hang of barman well.  At present, there are a few steps.

### Prepare the restore volume on annex2

First, we need to update the target that we are going to restore *from*.  Barman is set up to do all sorts of fancy point-in-time recovery workflows but we've never managed to get set up well with this, so the approach that we take is to dump out the data into a volume and then replicate that onto the appropriate host.

When you dump out the data, it will save (a) the "base backup" and (b) the "write ahead logs" from the time of the base backup through to the present.  When the database starts up it will replay the logs onto the database to advance the state up to the current point in time.  This means that if the base backup is very old, it may be faster overall to force a new backup.  We should be generating base backups every month.

Begin by `ssh`-ing onto `annex2`:

```
ssh vagrant@annex2.montagu.dide.ic.ac.uk
```

The commands below are all run from this machine, but can be run in any directory.

You can run:

```
barman-montagu status
```

to see the current state of the system which will print something like

```
barman-montagu is running
Server montagu:
	Active: True
	Disabled: False
	PostgreSQL version: 10.3
	Cluster state: in production
	Current data size: 757.1 GiB
	PostgreSQL Data directory: /pgdata
	Current WAL segment: 000000010000026B0000008D
	Passive node: False
	Retention policies: enforced (mode: auto, retention: RECOVERY WINDOW OF 3 MONTHS, WAL retention: MAIN)
	No. of available backups: 5
	First available backup: 20250301T000001
	Last available backup: 20250601T010001
	Minimum redundancy requirements: satisfied (5/0)
```

which is all good news.  We see that the last backup is on the first of June (20250601T010001) which will be nice if we're restoring in early June.

More extensive checks can be run by running

```
barman-montagu barman check montagu
```

**Optional** If you feel you want to force a new base backup you can do so by running

```
barman-montagu barman backup montagu
```

which will take a while (perhaps an hour) and write out a lot of data.  This is probably not really that needed unless you're having trouble restoring.

**Create a dump of the database** into the `barman_recover` volume (~40 minutes with 1 job, 15 minutes with 4)

```
docker exec -it barman-montagu barman recover --jobs 4 montagu latest /recover/
```

This prints relatively little output while it runs, and no indication of how far through it is.  Running the command a second time will start the whole process off again, sadly.

**Replay the WAL for faster restore**

Run

```
docker pull vimc/montagu-db:master
docker run -d --name barman-replay-wal \
    -v barman_recover:/pgdata \
    vimc/montagu-db:master \
    /etc/montagu/postgresql.production.conf
docker exec -it barman-replay-wal montagu-wait.sh 3600
docker stop barman-replay-wal
docker rm barman-replay-wal
```

which plays the WAL log over the base backup (by starting the db and waiting until it accepts connections, which it only does once this process is complete).  Doing this means that when you restore the databse to a real machine and start it up, it will become responsive almost immediately rather than waiting (like it just did here) on a live system that is disabled while restore proceeds.  If the WAL log collection is small this might only take a few seconds, but if a lot of data has been added since the base backup it could take several minutes.

These last two steps can be theoretically achieved by running `barman-montagu update-nightly` but I don't think that actually works at present.  If it does, it will restore into `montagu_db_volume` and will wipe the volume before restore.

At this point you now have a volume that we can restore from, possibly onto multiple machines.  Everything can be kept running to this point on the machines that you are restoring to.

### Actually restoring the data

The next steps are performed on the target machine, say `uat`, in the `montagu-config` directory.

Bring down montagu with

```
montagu stop uat
```

Update the database contents with

```
privateer restore barman_recover --server=annex2 --to-volume montagu_db_volume
```

which copies the contents of `barman_recover` from `annex2` into the volume `montagu_db_volume` (which is what we want).

then bring montagu back up with:

```
montagu start uat
```

See what is in the recent restore by running:

```
docker exec -it montagu-db psql -U vimc -d montagu -c \
  "select who, timestamp from api_access_log order by id desc limit 50;"
```

which shows recent API access logs, or other queries to satisfy yourself that the data has been restored as you might expect.

## Backup

To manually force a backup:

```
privateer backup montagu_orderly_volume --server annex2
privateer backup montagu_outpack_volume --server annex2
```

This is only meaningful for the orderly volume, because the db volume is handled by `barman`.  Because this is incremental, it will usually be fairly fast.

## Initial setup

**This section should not be done routinely**, but documents what was done, and what could be done to start again with fresh keys, or on fresh machines.

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
