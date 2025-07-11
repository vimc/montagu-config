This file documents the process used to completely rebuild the `uat` system ahead of the rollout of orderly2/packit for VIMC.  Replace `uat` with `science` or `production` to do this for other systems.

# Teardown

Stop everything

```
packit stop --kill uat
(cd ../montagu-orderly-web && ./stop)
montagu stop --kill --network uat
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
privateer restore barman_recover --server=annex2 --to-volume montagu_db_volume
privateer restore montagu_orderly_volume --server=annex2 --source=production2
privateer restore montagu_outpack_volume --server=annex2 --source=production2
```

These took about an hour to copy over from scratch, which is not terrible.  Do not bring anything up while this process is running, as that could result in confused containers as the data changes underneath them.

# Bringing the system up

**Start OrderlyWeb**; in `montagu-orderly-web/` with:

```
./setup uat
./start
```

**Start Packit**; in `montagu-config/` with:

```
packit start --pull uat
```

**Start montagu**; in `montagu-config/` with:

```
montagu start --pull uat
```

It's worth, at this point, running `docker ps -a` and looking for exited containers (or `docker ps -a --filter status=exited`) as this usually means that something terrible happened.

**Create yourself as a packit admin user**:

On the first deployment, packit has no user database and we need to bootstrap this in order to receive users from OrderlyWeb.

First, go to to the relevant packit instance to login:

* `uat`: https://uat.montagu.dide.ic.ac.uk/
* `science`: https://science.montagu.dide.ic.ac.uk/
* `production`: https://montagu.vaccineimpact.org/

and log in, you should see no errors.  This creates your user in the packit db using pre-auth.

Promote your user to a super-user for packit:

```
./scripts/promote-packit-user u.name@imperial.ac.uk
```

**Migrate permissions from OrderlyWeb to Packit**.  This can (and probably should) be run from your local machine's copy of [migrate-packit--perms-from-orderly-web](https://github.com/mrc-ide/migrate-packit--perms-from-orderly-web/), where you should be able to run

```
./scripts/uat.sh
```

which will prompt you for your montagu username and password, give you a summary of what it will migrate and which you can press 'y' to continue with the migration.

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
