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
docker run --rm -v orderly_library:/library -v $PWD/packages:/packages:ro -w /packages mrcide/orderly.runner:main install_packages
```

If you want to drop all packages first, you can do:

```
docker run --rm -v orderly_library:/library -v $PWD/packages:/packages:ro -w /packages mrcide/orderly.runner:main delete_packages
```
