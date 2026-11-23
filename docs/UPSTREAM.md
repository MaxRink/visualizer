# Mirroring shots to an upstream Visualizer

This instance can copy each new shot to another Visualizer instance — for
example the hosted one or another self-hosted install — using your own account
there. It is **off by default** and only ever concerns your own shots.

## What is sent

For every new shot created on this instance while mirroring is enabled, the job
sends the shot file to `POST <upstream base URL>/api/shots/upload`, authenticated
with `Authorization: Bearer <your token>`.

The body is the JSON shot format this app already understands on the way in
(the one `Parsers::DecentJson` reads): start time, elapsed time, profile,
pressure/flow/temperature series, totals, state changes and settings. It is
built by `ShotUploadSerializer` from the data stored with the shot.

Not sent: upload keys, your password, your email, other users' shots, coffee
bag ids, notes, private notes, or anything about this instance.

Shots without brew data (no chart series) cannot be exported faithfully and are
recorded as a push error instead of being sent.

## Enable it

1. On the upstream instance, create a token for your account there. On a
   Visualizer instance this is an OAuth access token (register an app at
   `/oauth/applications`, or use the token your client already has). This
   instance itself also issues upload keys, but those are local credentials and
   are **not** what the upstream expects.
2. Open **Edit Profile → Mirror to upstream** here.
3. Paste the token (it is write-only; it is never shown again), set the base URL
   (default `https://visualizer.coffee`), tick **Enable mirroring**, and save.
4. Press **Send test**: it calls `GET <base URL>/api/me` with your token and
   reports the result.

## What happens on failure

The push runs in a background job after the local shot is committed. Server
errors and timeouts are retried with backoff; client errors are recorded and
discarded. The local shot is never modified or deleted because a push failed.
The profile shows the last push time and the last error, and the admin user list
shows whether mirroring is on and whether the last push errored.

## Disable it

Untick **Enable mirroring** and save, or press **Clear token**. Either stops
future pushes immediately. Shots already mirrored upstream stay there; this
instance has no way to delete them remotely.

## Notes

- Only shots created while mirroring is enabled are sent. Nothing is pushed
  retroactively when you turn it on.
- Editing a shot or linking a coffee bag later does not re-push it: the upstream
  payload carries the bean fields copied onto the shot at upload time, not a
  local bag id.
- The token is stored with Active Record encryption and is never rendered,
  logged, or included in API responses.
