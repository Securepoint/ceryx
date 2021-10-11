"""
Simple Redis client, implemented the data logic of Ceryx.
"""
import redis

from ceryx import exceptions, schemas, settings

def _str(subject):
    return subject.decode("utf-8") if type(subject) == bytes else str(bytes)


class RedisClient:
    @staticmethod
    def from_config(path=None):
        """
        Returns a RedisClient, using the default configuration from Ceryx
        settings.
        """
        return RedisClient(
            settings.REDIS_HOST,
            settings.REDIS_PORT,
            settings.REDIS_PASSWORD,
            0,
            settings.REDIS_PREFIX,
            settings.REDIS_TIMEOUT,
        )

    def __init__(self, host, port, password, db, prefix, timeout):
        self.client = redis.StrictRedis(host=host, port=port, password=password, db=db, socket_timeout=timeout, socket_connect_timeout=timeout)
        self.prefix = prefix

    def _prefixed_key(self, key):
        return f"{self.prefix}:{key}"

    def _route_key(self, source):
        return self._prefixed_key(f"routes:{source}")

    def _settings_key(self, source):
        return self._prefixed_key(f"settings:{source}")

    def _upstream_headers_key(self, source):
        return self._prefixed_key(f"upstream-headers:{source}")

    def _validation_cookie_name_key(self, source):
        return self._prefixed_key(f"validation-cookie-name:{source}")

    def _validation_cookie_value_key(self, source):
        return self._prefixed_key(f"validation-cookie-value:{source}")

    def _delete_target(self, host):
        key = self._route_key(host)
        self.client.delete(key)

    def _delete_settings(self, host):
        key = self._settings_key(host)
        self.client.delete(key)

    def _delete_upstream_headers(self, host):
        key = self._upstream_headers_key(host)
        self.client.delete(key)

    def _delete_validation_cookie(self, host):
        key = self._validation_cookie_name_key(host)
        self.client.delete(key)

        key = self._validation_cookie_value_key(host)
        self.client.delete(key)

    def _lookup_target(self, host, raise_exception=False):
        key = self._route_key(host)
        target = self.client.get(key)

        if target is None and raise_exception:
            raise exceptions.NotFound("Route not found.")

        return target

    def _lookup_settings(self, host):
        key = self._settings_key(host)
        return self.client.hgetall(key)

    def _lookup_upstream_headers(self, host):
        key = self._upstream_headers_key(host)
        return self.client.hgetall(key) or []

    def _lookup_validation_cookie_name(self, host):
        key = self._validation_cookie_name_key(host)
        return self.client.get(key)

    def _lookup_validation_cookie_value(self, host):
        key = self._validation_cookie_value_key(host)
        return self.client.get(key)

    def lookup_hosts(self, pattern="*"):
        lookup_pattern = self._route_key(pattern)
        left_padding = len(lookup_pattern) - 1
        keys = self.client.keys(lookup_pattern)
        return [_str(key)[left_padding:] for key in keys]

    def _set_target(self, host, target, ttl = 0):
        key = self._route_key(host)
        self.client.set(key, target)
        if (ttl):
            self.client.expire(key, ttl)

    def _set_settings(self, host, settings, ttl = 0):
        key = self._settings_key(host)
        self.client.hmset(key, settings)
        if (ttl):
            self.client.expire(key, ttl)

    def _set_upstream_headers(self, host, headers, ttl = 0):
        if (not len(headers)):
            return

        key = self._upstream_headers_key(host)
        self.client.hmset(key, headers)
        if (ttl):
            self.client.expire(key, ttl)

    def _set_validation_cookie(self, host, name, value, ttl = 0):
        if (not len(name) or not len(value)):
            return

        key = self._validation_cookie_name_key(host)
        self.client.set(key, name)
        if (ttl):
            self.client.expire(key, ttl)

        key = self._validation_cookie_value_key(host)
        self.client.set(key, value)
        if (ttl):
            self.client.expire(key, ttl)

    def _set_route(self, route: schemas.Route):
        redis_data = route.to_redis()
        self._set_target(route.source, redis_data["target"], route.ttl)
        self._set_settings(route.source, redis_data["settings"], route.ttl)
        self._set_upstream_headers(
            route.source, redis_data["upstream_headers"], route.ttl)

        if ("validation_cookie_name" in redis_data and "validation_cookie_value" in redis_data):
            self._set_validation_cookie(
                route.source, redis_data["validation_cookie_name"], redis_data["validation_cookie_value"], route.ttl)
        return route

    def get_route(self, host):
        target = self._lookup_target(host, raise_exception=True)
        settings = self._lookup_settings(host)
        upstream_headers = self._lookup_upstream_headers(host)
        validation_cookie_name = self._lookup_validation_cookie_name(host)
        validation_cookie_value = self._lookup_validation_cookie_value(host)

        route = schemas.Route.from_redis({
            "source": host,
            "target": target,
            "settings": settings,
            "upstream_headers": upstream_headers,
            "validation_cookie_name": validation_cookie_name,
            "validation_cookie_value": validation_cookie_value
        })
        return route

    def list_routes(self):
        hosts = self.lookup_hosts()
        routes = [self.get_route(host) for host in hosts]
        return routes

    def create_route(self, data: dict):
        route = schemas.Route.validate(data)
        return self._set_route(route)

    def update_route(self, host: str, data: dict):
        data["source"] = host
        route = schemas.Route.validate(data)
        return self._set_route(route)

    def delete_route(self, host: str):
        self._delete_target(host)
        self._delete_settings(host)

    def isHealthy(self):
        result = self.client.ping()
        return result == True
