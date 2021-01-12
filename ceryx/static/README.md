Add the following lines to the http context of your nginx.conf:

```nginx
# Lua settings
lua_package_path "${prefix}lualib/?.lua;;";
lua_shared_dict ceryx 1m;
# for debugging
# lua_code_cache off;
```

Add new Environment Variables to the systemd-config. For example by placing the following lines
into `/etc/systemd/system/openresty.service.d/CeryxEnvironmentFile.conf`

```systemd
[Service]
EnvironmentFile=/etc/ceryx/config.env
```

Then reload systemd:

```bash
systemctl daemon-reload
```

Now check `/etc/cery/cconfig.env` and set the variables accordingly.

Create a new VHost that uses ceryx. For example by creating the file `.../sites-enabled/ceryx.conf`:

```nginx
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}

map $http_x_forwarded_proto $proxy_set_x_forwarded_proto {
    default $scheme;
    'http'  http;
    'https' https;
}

server {
    listen 80;
    listen 443 ssl;
    server_name ~^ceryx-[a-f0-9-]+\.example\.com;

    default_type text/html;

    ssl_certificate /etc/nginx/ssl/wildcard.example.com.crt;
    ssl_certificate_key /etc/nginx/ssl/wildcard.example.com.key;

    location / {
        set $target "fallback";

        # Lua files
        access_by_lua_file lualib/router.lua;

        # Proxy configuration
        proxy_set_header Host $http_host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Real-IP  $remote_addr;
        proxy_set_header X-Forwarded-Proto $proxy_set_x_forwarded_proto;

        # Upgrade headers
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_redirect ~^(http://[^:]+):\d+(/.+)$ $2;
        proxy_redirect ~^(https://[^:]+):\d+(/.+)$ $2;
        proxy_redirect / /;

        proxy_pass $target;
    }

    error_page 503 /503.html;
    location = /503.html {
        root /etc/ceryx/static;
    }

    error_page 500 /500.html;
    location = /500.html {
        root /etc/ceryx/static;
    }
}
```

Finally reload openresty:

```bash
openresty -s reload
```

Ceryx is now running, you just need to use the API to add something to the Redis database.
