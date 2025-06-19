This file documents the process used to completely rebuild the `uat` system ahead of the rollout of orderly2/packit for VIMC.

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
```

These took about 50 minutes to copy over, which is not terrible.

Migrate the packets from orderly1 to orderly2, this is slow.  Instrucrtions copied from [`README.md`](README.md)

```
docker pull mrcide/outpack.orderly:main
docker run -it --rm --name outpack-migrate \
    -v montagu_orderly_volume:/orderly:ro \
    -v outpack_volume:/outpack \
    mrcide/outpack.orderly:main \
    /orderly /outpack --once
```

We can continue while this runs though, but packets will not be visible until it completes.  Expect this to take a while, but we'll remove this step very soon as we run this on production.

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

Go to https://uat.montagu.dide.ic.ac.uk/ and log in, you should see no errors.  This creates your user in the packit db using pre-auth.  Promote your user to a super-user for packit:

```
./scripts/promote-packit-user u.name@imperial.ac.uk
```

**Migrate permissions from OrderlyWeb to Packit**.  This can (and probably should) be run from your local machine's copy of [migrate-packit--perms-from-orderly-web](https://github.com/mrc-ide/migrate-packit--perms-from-orderly-web/), where you should be able to run

```
./scripts/uat.sh
```

which will prompt you for your montagu username and password, give you a summary of what it will migrate and which you can press 'y' to continue with the migration.

Note that the packet migration must have completed by this point or the migration will fail.

**Copy the data vis tool**

```
./scripts/copy-vis-tool
```
