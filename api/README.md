## Development

```
pip3 install pipenv
pipenv install
pipenv run python api.py
```


## API

### Create a new route

```bash
curl --request POST \
  --url http://localhost:5555/api/routes \
  --header 'Content-Type: application/json' \
  --data '{
    "source": "90444bf2-2db1-41b8-9f70-7b78c15fa045.admin.usc.securepoint.cloud",
    "target": "https://proxytest.naugrim.org",
    "upstream_headers": {
      "cookie": "SESSID=this_is_passed_to_the_target"
    },
    "validation_cookie_name": "ze_cookie",
    "validation_cookie_value": "this_is_validated_on_the_proxy",
    "ttl": 3600
  }'
```
`source` and `target` are required, the remaining parameters are optional.

If `validation_cookie_name` and `validation_cookie_value` are given, a cookie with this name and value must be given by the client accessing the `source`.
The request is denied otherwise.

Response:

```json
{
  "source": "923101c1-d9da-41c6-9af4-7aa79b595224.admin.usc.securepoint.cloud",
  "target": "https://proxytest.naugrim.org",
  "settings": {
    "enforce_https": false,
    "mode": "proxy",
    "certificate_path": null,
    "key_path": null
  },
  "upstream_headers": {
    "cookie": "SESSID=this_is_passed_to_the_target"
  },
  "ttl": 3600,
  "validation_cookie_name": "ze_cookie",
  "validation_cookie_value": "this_is_validated_on_the_proxy"
}
```

### Healthcheck

```bash
curl --request HEAD \
  --url http://localhost:5555/health \
  --header 'Content-Type: application/json'
```

Reponse:

Statuscode `200` if everything is good.

### Delete a route from Ceryx

```bash
curl -H "Content-Type: application/json" \
     -X DELETE \
     http://localhost:5555/api/routes/923101c1-d9da-41c6-9af4-7aa79b595224.admin.usc.securepoint.cloud
```

### Enforce HTTPS

You can enforce redirection from HTTP to HTTPS for any host you would like.

```bash
curl -H "Content-Type: application/json" \
     -X POST \
     -d '{"source":"923101c1-d9da-41c6-9af4-7aa79b595224.admin.usc.securepoint.cloud","target":"https://proxytest.naugrim.org", "settings": {"enforce_https": true}}' \
     http://localhost:5555/api/routes
```

The above functionality works in `PUT` update requests as well.

### Redirect to target, instead of proxying

Instead of proxying the request to the targetm you can prompt the client to redirect the request there itself.

```bash
curl -H "Content-Type: application/json" \
     -X POST \
     -d '{"source":"923101c1-d9da-41c6-9af4-7aa79b595224.admin.usc.securepoint.cloud","target":"https://proxytest.naugrim.org", "settings": {"mode": "redirect"}}' \
     http://localhost:5555/api/routes
```