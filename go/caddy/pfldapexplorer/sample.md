# Search

```
curl -H "Content-Type: application/json"  -d '{"server":"AD","search":"(sAMAccountName=zammit)","attributes":["userPrincipalName","sAMAccountName"]}' http://127.0.0.1:22226/api/v1/ldap/search| python -m json.tool
