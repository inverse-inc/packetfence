# Instructions to test import against devel branch

## Prepare the environment (when on devel only)

```
# Replace 11.0 with the current devel version
cp db/pf-schema-X.Y.sql db/pf-schema-11.0.sql
```

```
# Replace 10.3-11.0 with the current stable and current devel version
cp db/upgrade-X.X-X.Y.sql db/upgrade-10.3-11.0.sql
```
