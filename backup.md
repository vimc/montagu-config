# Backup setup notes

## From my workstation

```
privateer keygen --all
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
pip3 install --user privateer==2.0.0
privateer configure annex2
privateer server start
```

## From production2

```
privateer configure production2
privateer check --connection
screen
privateer backup montagu_orderly_volume --server=annex2
```

## From production

```
privateer configure production
privateer check --connection
screen
privateer backup montagu_orderly_volume --server=annex2
```

## To uat

```
privateer configure uat
privateer restore montagu_orderly_volume --server=annex2 --source=production
privateer restore barman_recover --server=annex2
montagu start uat
```
