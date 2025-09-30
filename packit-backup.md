On production2, run:

```
docker exec -it montagu-packit-db pg_dump -U packituser -Fc packit -f /pgbackup/packit
privateer backup montagu_packit_db_backup --server annex2
```

On uat, run

```
privateer restore montagu_packit_db_backup --server annex2
```

Then bring packit down, this is important.

Delete the packit database persistant data.  Be sure you are on uat and not production please.

```
docker volume rm montagu_packit_db
```

The restoration step is quite awkward, but we'll add some helpers into `packit-db` to do this in one shot soon.  The basic idea is:

* start the db (empty)
* run the restore
* stop the db

But making sure that each command has completed before running the next.  Montagu-db has some scripts from 8 years ago that did this sort of thing.

```
docker volume create montagu_packit_db
docker run -d --rm --name montagu-packit-db-restore -v montagu_packit_db_backup:/pgbackup:ro -v montagu_packit_db:/pgdata ghcr.io/mrc-ide/packit-db:main
```

Give that a few seconds to come up properly.

Run `pg_restore`

```
docker exec -it montagu-packit-db-restore pg_restore --verbose --exit-on-error --no-owner -d packit -U packituser /pgbackup/packit
```

Then stop the container

```
docker stop montagu-packit-db-restore
```

Then bring up packit

```
packit start
```
