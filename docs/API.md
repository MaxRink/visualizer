# Using the API on this instance

This page is for people who want to point a client at a self-hosted Visualizer
instance. It only describes endpoints that exist in this repository.

## Base URL

Every endpoint lives under `/api`:

```
https://<your-instance>/api
```

The published OpenAPI contract is `openapi.yaml` in this repository (it lists
`https://visualizer.coffee/api` as the hosted server; the paths and fields are
the same here).

## Create an upload key

1. Sign in and open **Edit Profile**.
2. In **Upload keys**, give the key a name (for example `Beanconqueror`) and
   press **Create upload key**.
3. Press **Reveal** to see the key, then **Copy**. Keys start with `vzu_`.
4. **Revoke** deletes a key immediately; create as many as you need, one per
   device or script.

The token is stored encrypted on the server and is only shown to you. Never put
it in a URL, a screenshot, or a repository.

## Authentication

Send the key in either header:

```bash
curl -H "Authorization: Bearer vzu_your_key" https://<your-instance>/api/me
curl -H "X-Upload-Key: vzu_your_key" https://<your-instance>/api/me
```

- The key belongs to one user and grants exactly that user's permissions; there
  are no OAuth scopes to request.
- Session cookies are not accepted by `/api`. A browser session and a key are
  separate credentials.
- `401` means the key is missing, unknown, or revoked.
- `403` means the key is valid but the request is not allowed (someone else's
  shot, a disabled or unconfirmed account).
- Requests are not subject to the Authelia login: the reverse proxy only
  bypasses it for `/api/`, so scripts and phones work without a browser.

## Upload a shot file

```bash
curl -X POST "https://<your-instance>/api/shots/upload" \
  -H "Authorization: Bearer vzu_your_key" \
  -H "Accept: application/json" \
  -F "file=@20210921T085910.json"
```

The raw file body also works:

```bash
curl -X POST "https://<your-instance>/api/shots/upload" \
  -H "Authorization: Bearer vzu_your_key" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  --data-binary @20210921T085910.json
```

The response is `{"id": "<shot-uuid>"}`. Accepted formats are the ones the
repository's parsers understand: Decent (`.shot`, `.json`), Beanconqueror
(`.json`), Gaggiuino, GaggiMate, Meticulous, and Smart Espresso Profiler CSV.
Uploads made with a key record which key was used; the shot page shows it to
administrators.

## Link a shot to a coffee bag

```bash
curl -X PATCH "https://<your-instance>/api/shots/<shot-uuid>" \
  -H "Authorization: Bearer vzu_your_key" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{"shot":{"coffee_bag_id":"<bag-uuid>"}}'
```

`PATCH /api/shots/{id}` requires `Accept: application/json`; without it the
endpoint answers `422 Request must be JSON`. To attach a photo, send the same
request as `multipart/form-data` with `shot[image]`. Bag links and image
uploads made through a key are attributed to that key.

## Reading

```bash
curl -H "Authorization: Bearer vzu_your_key" \
  "https://<your-instance>/api/shots?items=25&page=2"
```

`items` defaults to 10. The hosted service caps it at 100, a self-hosted
instance at 1000; the operator can change that with `VISUALIZER_API_MAX_ITEMS`.
Responses include a `paging` object with `count`, `page`, `limit`, `pages`.

## Rate limits

The hosted service allows 50 requests per minute and 200 per 10 minutes per IP,
plus 200 per 10 minutes per user. Self-hosted instances have these switched off
by default; set `VISUALIZER_RATE_LIMITS=true` to enable them. Exceeding a limit
returns `429`.

## Configure an existing client

This repository is the server. It ships no client apps, so it cannot confirm
which third-party clients hard-code `https://visualizer.coffee`. Two rules
decide whether an app can be repointed:

- **Can be repointed:** the app has a server/base-URL setting and a field or
  header for an API key or HTTP basic auth. Set the base URL to
  `https://<your-instance>` and paste the `vzu_…` key as a Bearer token (or use
  your email and password with basic auth).
- **Cannot be repointed:** the app hard-codes the hosted hostname or only
  supports OAuth against it. There is no setting in this repository that can
  change a compiled-in host.

The official mobile app is not part of this repository, so its behaviour is
unverified here; if it has no server setting, it cannot be used with this
instance. Use one of these instead:

**curl** — see the examples above.

**iOS Shortcuts** — *Get Contents of URL* action:
- URL: `https://<your-instance>/api/shots/upload`
- Method: `POST`
- Headers: `Authorization: Bearer vzu_your_key`
- Request Body: *Form*, field `file`, type *File*, value the shot file.

**Tasker (Android)** — *HTTP Request* action:
- Method: `POST`
- URL: `https://<your-instance>/api/shots/upload`
- Headers: `Authorization: Bearer vzu_your_key`
- File to upload: the shot file, parameter name `file`.

Both recipes create the same shot as `curl` and record the key on the shot.
