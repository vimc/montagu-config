# Backup and restore

We can backup Montagu, orderly (outpack) and packit data from the production machine. Data is backed up to annex2. 
We frequently want to restore from the backup to UAT (our dev testing machine) and to Science (the machine used for 
testing by VIMC science team, who often want a recent copy of Montagu DB and orderly reports to use away from production). 
We have never needed to restore back onto production itself, but this should be possible in the case of disaster by 
following the same procedure (see [rebuild.md](./rebuild.md) for how we would rebuild a machine from scratch).

In this document we describe:
- How the backup and restore process works for each data store in Montagu
- How to run the backup and restore process 
- A more detailed account of restoring Montagu DB (not using the helper script) with additional status checks and optional steps

## How data is backed up and restored in Montagu

In general, we can safely take backups (of production) while the system is running, but when we restore (to UAT or Science) 
we should do so with all containers stopped so that we do not overwrite any new local changes with the restore, and to 
avoid any data inconsistencies.

We keep our backups on the annex2 machine so all backups are done from production to annex2 and all restores are done from
annex2 to the machine being restored

### Montagu DB

This is the only part of the system which is backed up automatically. Write-ahead logs (WAL) are automatically 
streamed from the production machine to annex2 using **barman** (running on annex2). The WAL are relative to a base backup. 
Read more about this approach to Postgres backups [here](https://www.postgresql.org/docs/current/continuous-archiving.html).

Ideally we would prefer not to use WAL and the additional complexity it requires, but we need to do so because Montagu 
DB is too big to take full backups whenever we want to restore. Once we have reduced the size of Montagu DB (when burden 
estimates have been moved out to orderly/packit and historic estimates archived into a separate db) we may be able to retire 
this approach.

[Barman](https://pgbarman.org/) is a third party tool, for which we have written a montagu-specific wrapper, `barman-montagu`, 
implemented in the [montagu-db-backup](https://github.com/vimc/montagu-db-backup) repo. See this repo for further documentation, 
but bear it mind that it is rather out of date. For example...

New base backups are currently manually triggered. There is an intended yacron schedule, described and built into montagu-db-backup - 
however this was not reliable and is not currently running. It is worth making a new base backup occasionally as it means 
that the restore will be quicker as there will be less WAL to replay.

To restore the Montagu DB from its current state we run `./scripts/annex-dump-montagu` on annex2. This does not create a 
SQL dump, but rather prepares a restorable recover volume from the current base backup and WAL.

We then use **privateer** to pull this volume across from annex2 to the machine we're restoring to. 
[Privateer](https://github.com/reside-ic/privateer) is a tool we developed to sync docker volumes between machines. 
See [privateer.json](./privateer.json) in this repo for the configuration privateer uses to send restore data between 
montagu machines. Then all we need to do is restart montagu.

### Outpack volume

The outpack (orderly) volume backup and restore process is manual and handled entirely by privateer. On the production 
machine we run a privateer command to backup the volume to annex, and on the machine we want to restore to we run another 
privateer command to pull the data down from annex.

### Packit DB

Again, backing up Packit DB is a manual step. 

When we only want to update orderly packets on the restore machine, we actually do not need to take any further steps to 
restore Packit DB, as all the new packet data will be in the restored outpack volume. Outpack server and Packit API will 
spot any new packets and update Packit DB with those. We can run the Resync job in Packit admin page to clean out any 
metadata for packets which no longer exist - packets which had run on the restore machine and did not exist on production.

However if there is any Packit DB data from production that we do want to restore e.g. relating to users, permissions, 
pinned packets etc, then we can do a Packit DB backup and restore as well. On production, we do a postgres dump to 
generate a volume we can recover from then send that to annex using privateer. On the machine being restored, we pull the 
volume using privateer and then a restore db command to actually restore into the packit-db volume. Note that because the 
packit db is small, we do a full db dump every time and do not use WAL.

## Other data
This data is not currently included in backup and retore:
* the orderly logs
* the packit redis data (not even persisted to a volume at present)

## How to backup and restore Montagu data

The typical task that you'll want to do is to restore UAT or Science from the latest data on Production. This means that
for each of Montagu db, Outpack volume and Packit db you'll first need to ensure backed up production data is available 
on annex2 and then restore that data onto the target machine. 

In all cases we backup to and restore from docker volumes. If you are nervous about a particular backup failing for any 
reason you can always take a copy of the existing backup volume on annex2 or on the target machine, either before doing
the backup (on annex2) or before pulling the data with privateer (on the target machine).

The restore process may also be carried out when rebuilding a machine from scratch for some reason. This could be UAT, 
Science or Production. [rebuild.md](./rebuild.md) describes additional setup steps you'll need to do when rebuilding. 

### Backup

#### Montagu DB backup

As described above, Montagu db is continuously backed up by barman streaming WAL to annex2. However you may 
optionally want to take a new base backup. This is done on annex2 by running:
```
barman-montagu barman backup montagu
```

See "Montagu DB Backup and Restore - step by step" for more details. 

#### Outpack volume backup
On production2 run:

```
privateer backup montagu_outpack_volume --server annex2
```

#### Packit DB backup

If you need to take a backup of latest Packit DB, rather than just updating from the restored Outpack volume, then on 
production2 run:
```
docker exec -it montagu-packit-db pg_dump -U packituser -Fc packit -f /pgbackup/packit
privateer backup montagu_packit_db_backup --server annex2
```


### Restore

#### Montagu DB restore

Expect this to take about 2 hours. 

##### Make a restore volume of Montagu DB
On annex2 from within `montagu-config` dump the database into the backup volume

```
./scripts/annex-dump-montagu-db
```
This helper script covers the steps described in "Prepare the restore volume on annex2".


##### Restore Montagy DB onto Target machine
Then on on the machine that you want to restore into, from within `montagu-config`, run:

```
montagu stop --kill
privateer restore barman_recover --server=annex2 --to-volume montagu_db_volume
montagu start
```

This will bring down montagu while the restore is carried out.


#### Outpack volume restore

On the target machine, pull the data over for the outpack volume:

```
privateer restore montagu_outpack_volume --server=annex2 --source=production2
```

Here, `production2` is the original source of the data, and `annex2` is the backup server that it is stored on.

This can be done fairly safely while the system is running, but you may want to stop packit first.  On Science or UAT 
you will have deleted any packets that are only present on those machines (this process just copies over the contents 
of production and deletes any additions) so you should resync packets:
* uat: https://uat.montagu.dide.ic.ac.uk/packit/resync-packets
* science: https://science.montagu.dide.ic.ac.uk/packit/resync-packets

You don't need to resync packets if you're going to restore the full Packit DB, as this will include all the latest packet
metadata. 


#### Packit DB restore
If doing a full Packit DB restore, there are a few steps to run on the target machine. The restoration step is quite 
awkward, but we'll add some helpers into packit-db to do this in one shot soon (there are some similar scripts for Montagu DB). 
Essentially we want to run the restore while the Packit system is not running, and we need to restore from the backup 
dump volume into an empty Packit DB container. 
We need to make sure that each step has completed before starting the next. 

1. Run `privateer restore montagu_packit_db_backup --server annex2` to pull the Packit db backup from annex2
2. Stop packit: `packit stop`
3. Delete the old Packit database volume. Be sure you are on UAT/Science and not production please:`docker volume rm montagu_packit_db`
4. Make a new empty database volume: `docker volume create montagu_packit_db`
5. Start a DB container with the empty volume and backup voume: `docker run -d --rm --name montagu-packit-db-restore -v montagu_packit_db_backup:/pgbackup:ro -v montagu_packit_db:/pgdata ghcr.io/mrc-ide/packit-db:main`
6. Wait a few seconds to ensure the container starts up fully
7. Run `pg_restore` in the container to populate the data volume: `docker exec -it montagu-packit-db-restore pg_restore --verbose --exit-on-error --no-owner -d packit -U packituser /pgbackup/packit`
8. Stop the DB container: `docker stop montagu-packit-db-restore`
9. Restart packit: `packit start`



## Montagu DB Backup and Restore - step by step

Generally, this will be pulling the `production2` database onto `uat` or `science`, and this is quite involved as we've never really got the hang of barman well.  
At present, there are a few steps.

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

**WARNING**: with recent versions of barman, some extra work is required as it will not happily backup directly onto the 
directory that is our mount path (`/recover`, here) so we need to manually move things around.  
Please see `./scripts/annex-dump-montagu-db` for the details - this prose below just outlines the important logical parts of the process.

```
docker exec -it barman-montagu barman recover --jobs 4 montagu latest /recover/
```

This prints relatively little output while it runs, and no indication of how far through it is.  Running the command a second time will start the whole process off again, sadly.

**Replay the WAL for faster restore**

Run

```
docker pull ghcr.io/vimc/montagu-db:main
docker run -d --name barman-replay-wal \
    -v barman_recover:/pgdata \
    ghcr.io/vimc/montagu-db:main \
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
