# Backup setup notes

## From my workstation

```
privateer2 keygen --all
```

then

```
vault list /secret/vimc/privateer
```

```
Keys
----
annex
annex2
production
production2
science
uat
```

## From annex2

```
privateer2 configure annex2
privateer2 server start
```

## From production2

```
privateer2 configure production2
privateer2 check --connection
screen
privateer2 backup montagu_orderly_volume --server=annex2
```

## From production

```
privateer2 configure production
privateer2 check --connection
screen
privateer2 backup montagu_orderly_volume --server=annex2
```

## To uat

```
privateer2 configure uat
privateer2 restore montagu_orderly_volume --server=annex2 --source=production
privateer2 restore barman_recover --server=annex2
montagu start uat
```
