import responder

from ceryx import settings
from ceryx.db import RedisClient
from ceryx.exceptions import NotFound


api = responder.API()
client = RedisClient.from_config()


@api.route("/")
def default(req, resp):
    if not req.url.path.endswith("/"):
        api.redirect(resp, f"{req.url.path}/")


@api.route("/api/routes")
class RouteListView:
    async def on_get(self, req, resp):
        resp.media = [dict(route) for route in client.list_routes()]

    async def on_post(self, req, resp):
        data = await req.media()
        route = client.create_route(data)
        resp.status_code = api.status_codes.HTTP_201
        resp.media = dict(route)


@api.route("/api/routes/{host}")
class RouteDetailView:
    async def on_get(self, req, resp, *, host: str):
        try:
            route = client.get_route(host)
            resp.media = dict(route)
        except NotFound:
            resp.media = {"detail": f"No route found for {host}."}
            resp.status_code = 404

    async def on_put(self, req, resp, *, host: str):
        data = await req.media()
        route = client.update_route(host, data)
        resp.media = dict(route)

    async def on_delete(self, req, resp, *, host:str):
        client.delete_route(host)
        resp.status_code = api.status_codes.HTTP_204

@api.route("/health")
class RouteDetailView:
    async def on_head(self, req, resp):
        check = False
        status = 500

        try:
            check = client.isHealthy()
        except:
            check = False

        if check:
            status = 200

        resp.status_code = status


if __name__ == '__main__':
    api.run(port=settings.API_BIND_PORT, address=settings.API_BIND_HOST)
