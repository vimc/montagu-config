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
