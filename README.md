# montagu-config

Config and scripts for deploying Montagu.

# Pre-deployment scripts

Diagnostic report config is committed to this repo, but if you need to change it, it can be re-generated by running `scripts/generate_real_diagnostic_reports_config.py`.
This will generate a new yaml file "diagnostic-reports.yml" in the current working directory, which can then be copied into place in the relevant instance config directory.

# Deployment

To deploy UAT/Science/Production, first ensure `montagu-deploy` is installed:

    pip3 install --user montagu-deploy

Then start the required instance, e.g.:

    montagu start uat

See https://github.com/vimc/montagu-deploy for more details on the deploy tool.

# Post deployment

After deploying both Montagu AND OrderlyWeb, you may need to copy the data viz tools into place. This can be done
with `scripts/copy-vis-tool.sh`.

# Backup and restore

To interact with the backups (key generation, backup, restore, etc) you will need `privateer2` installed.  Currently do this by installing manually from the sources (`hatch build`, copy the whl file around then `pip3 install --user <path>`). Once we merge back into `privateer`, you can install from pypi with pip:

```
pip3 install --user privateer
```

Before any backup and restore is possible, you would have first needed to create keys:

```
privateer2 keygen --all
```

Each machine that uses privateer needs to be configured; this is `annex` and `annex2` (the servers) and `production`, `production2`, `science` and `uat`. This pulls keys from the vault and writes out persistent ssh configuration.

## Backup

We don't yet support scheduled backups, so everything is manual for now.

```
privateer2 backup production montagu_orderly_volume --server=annex
privateer2 backup production montagu_orderly_volume --server=annex2
```

## Restore

```
privateer2 restore production montagu_orderly_volume --server=annex
```

on science this would be

```
privateer2 restore production montagu_orderly_volume --server=annex --source=production
```

See https://github.com/reside-ic/privateer2 for more details on the backup tool.
