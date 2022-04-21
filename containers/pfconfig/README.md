
# Run with

```
docker run -v/usr/local/pf/conf:/usr/local/pf/conf -v /var/lib/mysql/mysql.sock:/run/mysqld/mysqld.sock -v/usr/local/pf/var/run:/usr/local/pf/var/run --rm -ti $(docker build -q -f docker/pfconfig/Dockerfile .)
```

