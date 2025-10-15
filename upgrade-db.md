# Upgrading postgres

Upgrading Postgres involves downtime on production.  Older versions work quite well in practice but get increasingly worrying as they age.

## Packit

The packit db is small enough that probably dumping a backup, upgrading the image used, and restoring into a newer version will probably work.  This is untested.

First, create a new docker image that references a recent postgres.  You can increase multiple major versions at once.  See [this PR for example](https://github.com/mrc-ide/packit/pull/247), which migrates from 10 to 17.  Get this image building and passing (in this case no work was required).

Make sure that backup of the production database is up-to-date by running, on production in `montagu-config/`:

```
docker exec -it montagu-packit-db pg_dump -U packituser -Fc packit -f /pgbackup/packit
privateer backup montagu_packit_db_backup --server annex2
```

Test out the new database on `uat`.  On that machine, bring down packit:

```
packit stop --kill
```

Run the upgrade using `pgautoupgrade`, for example

```
docker run --rm --name pgauto -it \
    -v montagu_packit_db:/var/lib/postgresql/data \
	-e PGAUTO_ONESHOT=yes \
    pgautoupgrade/pgautoupgrade:17-alpine
```

(this only takes a few seconds to run).

The volume name here must match the database volume, as seen in `docker volume list` and the image tag needs to match the major version of the postgres release you are aiming for (see [the docker hub page](https://hub.docker.com/r/pgautoupgrade/pgautoupgrade) for details and tags).  **Be careful to get the right volume here, not the montagu db one**.

Edit `montagu-config/uat/packit.yml` (probably on a PR) to point at the branch of the packit-db that you created above.

Bring packit back up with

```
packit start --pull
```

This should start up fairly quickly, and you should be able to log in.

If this works, then the same basic process can be run on production, though with the PR merged and the config left on main.  Once working, refresh the backup (as above).

## Montagu

If the montagu database gets much smaller (e.g., if we manage to remove the demographics, coverage and burden estimate tables in future) then a dump and restore process might be better and faster than the approach below.

First, create a new docker image that references a recent postgres.  You can increase multiple major versions at once.  See [this PR for example]https://github.com/vimc/montagu-system/pull/9 (or [this original one]((https://github.com/vimc/montagu-db/pull/175) before the move to the monorepo), which migrates from 10 to 17.  Get this image building and passing.


Test out the new database on `uat`.  On that machine, bring down montagu:

```
montagu stop --kill
```

Run the upgrade using `pgautoupgrade`, for example

```
docker run --rm --name pgauto -it \
    -v montagu_db_volume:/var/lib/postgresql/data \
	-e PGAUTO_ONESHOT=yes \
    -e PGUSER=vimc \
    -e PGAUTO_REINDEX=no \
    pgautoupgrade/pgautoupgrade:17-alpine
```

Note here that we:

* set the user to avoid some weird warnings about a missing root user
* avoid indexing, because we'll manually do this later to avoid some weird errors

This takes a few minutes, but not that long because we skip building the index.

```
docker run -d -it --rm --name montagu-db-upgrade -v montagu_db_volume:/pgdata vimc/montagu-db:vimc-6447-2
docker exec -it montagu-db-upgrade montagu-wait.sh 3600
docker exec -it montagu-db-upgrade psql -U vimc -d montagu -c "reindex (verbose) database montagu;"
docker stop montagu-db-upgrade
```

This takes ages, at least an hour or two.

Once this is done, edit `montagu-config/uat/montagu.yml` and change the db branch (two places within the `db:` block, one for the db and one for the migration image).

You also need to pull the migration image explicitly; this will be particularly important on `production2` because the tag is unchanged but the image has changed:

```
docker pull vimc/montagu-migrate:vimc-6447-2
```

Bring montagu back up

```
montagu start --pull
```

On production, we left montagu running.  We ran

```
privateer restore --dry-run montagu_packit_db_backup --server=annex2
```

to get the db restore command, then ran

```
privateer restore barman_recover --server=annex2 --to-volume montagu_db_volume_v17
```

to restore it into a volume with the db major version as part of the name.  This takes a while as it makes a second full copy of the db.  Be sure to have lots of space here.

Upgrade the database by running:

```
docker run --rm --name pgauto -it \
    -v montagu_db_volume_v17:/var/lib/postgresql/data \
	-e PGAUTO_ONESHOT=yes \
    -e PGUSER=vimc \
    -e PGAUTO_REINDEX=no \
    pgautoupgrade/pgautoupgrade:17-alpine
```

Note here the use of the `_v17` volume and not the main container.  Once this runs, we need to rebuild the index too:


```
docker run -d -it --rm --name montagu-db-upgrade -v montagu_db_volume_v17:/pgdata vimc/montagu-db:vimc-6447-2
docker exec -it montagu-db-upgrade montagu-wait.sh 3600
docker exec -it montagu-db-upgrade psql -U vimc -d montagu -c "reindex (verbose) database montagu;"
docker stop montagu-db-upgrade
```

Note here the use of the `_v17` volume again.
