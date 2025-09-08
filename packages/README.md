# Packages for the runner

For the orderly2-based runner we keep a long-lived volume of packages mounted at `/library` rather than baking the packages into the image; only packages required to run orderly, orderly.runner and the queue itself will be present there.   All workers share the same library.

Most packages are available on CRAN, but we have a couple of special cases that are still used:

* `jokergoo/ComplexHeatmap` (it is on BioConductor, and so has it's own weird set of deps too)
* `adletaw/captioner`
* `nfultz/stackoverflow` (only used in the first paper now)

Plus `jenner` and `vaccineimpact` from our universe.

## Refreshing the set of packages

This will need to be done periodically, to cope with new versions of R (or system libraries after a redeploy), or to refresh the versions of installed packages.

Run

```
./scripts/build-orderly-library
```

Installation is additive.  If you want to drop all packages first, you can do:

```
./scripts/delete-orderly-library
```

## System Dependencies

Some R packages require certain libraries to be present on the system (or in the container).
For example, the `sf` package requires the system libraries `libudunits2-dev`, `libgdal-dev`, 
`libgeos-dev` and `libproj-dev`. Without these present, the package installation will fail. 
Sometimes the error message will tell you exactly what library is missing. At other times,
the reported error does not make it totally obvious, but googling will get the answer. 
With `sf` for example, we'd see errors about a missing `gdal-config`, or an inability to 
load `libudunits2.so.0`.

Packages can be hot-installed into the container with something like the following:-

```
docker exec -it montagu-orderly-runner-api bash
apt update
apt install libudunits2-dev libgdal-dev libgeos-dev libproj-dev
```

but also, the required packages should be added to the dockerfile for the next deploy - 
see https://github.com/mrc-ide/orderly.runner/blob/main/docker/Dockerfile
