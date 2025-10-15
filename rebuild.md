This file documents the process used to completely rebuild the `uat` system (last done in October 2025).

If you are following through this process, expect it to take most of a day, some of the data transfers are quite slow.

# Preparation

Refresh backups from production, to ensure that we work with the most recent data.

**On production2**, within `montagu-config/`, run

```
privateer backup montagu_outpack_volume --server annex2
docker exec -it montagu-packit-db pg_dump -U packituser -Fc packit -f /pgbackup/packit
privateer backup montagu_packit_db_backup --server annex2
```

which backs up the most recent orderly data and the packit db

**On annex2**, from within `montagu-config` dump the database into the backup volume

```
./scripts/annex-dump-montagu-db
```

# Teardown

These commands are all run on `uat`, probably best to double check you're on the right machine please.  Work in the `montagu-config` directory, and have your GitHub PAT handy.

First, stop everything:

```
packit stop --kill
montagu stop --kill --network
```

Clear out all of docker:

```
docker system prune -f --volumes
docker volume rm $(docker volume list -q)
```

# Restore data

Because we deleted the privateer keys, we'll need to run this:

```
privateer configure uat
```

Then pull the data

```
privateer restore montagu_packit_db_backup --server=annex2
privateer restore barman_recover --server=annex2 --to-volume montagu_db_volume
privateer restore montagu_outpack_volume --server=annex2 --source=production2
```

Note that the barman recovery entry changes the destination volume.

These took about an hour to copy over from scratch, which is not terrible.  Do not bring anything up while this process is running, as that could result in confused containers as the data changes underneath them.

The packit db needs an extra step to restore (see [`packit-backup.md`](packit-backup.md)), but this is:

```
docker run -d --rm --name montagu-packit-db-restore -v montagu_packit_db_backup:/pgbackup:ro -v montagu_packit_db:/pgdata ghcr.io/mrc-ide/packit-db:main
# then wait a few seconds
docker exec -it montagu-packit-db-restore pg_restore --verbose --exit-on-error --no-owner -d packit -U packituser /pgbackup/packit
docker stop montagu-packit-db-restore
```

This can be safely run while the other volumes are restored.

# Bringing the system up

This can now be done in any order (packit or montagu first).

**Start Packit**; in `montagu-config/` with:

```
packit configure uat
packit start --pull
```

**Start montagu**; in `montagu-config/` with:

```
montagu configure uat
montagu start --pull
```

It's worth, at this point, running `docker ps -a` and looking for exited containers (or `docker ps -a --filter status=exited`) as this usually means that something terrible happened.

**Copy the data vis tool**

```
./scripts/copy-vis-tool
```

**Build the runner library**:

The runner library volume (`montagu_orderly_library`) will need required packages installed.  Do this by running

```
./scripts/build-orderly-library
```

See [`packages/README.md`](packages/README.md) for more information.

**Schedule regular backups**:

On `production` only, run

```
privateer schedule --as production2 start
```

(there's a small privateer bug that requires use of `--as` here)
