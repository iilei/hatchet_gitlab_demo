# Bootstrap notes

The GitLab container owns its `/etc/gitlab`, `/var/log/gitlab`, and
`/var/opt/gitlab` volumes. Do not mount those same GitLab volumes into a
second helper container to run Rails commands.

For automated bootstrapping, wait for `/-/health` and then use the GitLab API
with a deliberately scoped token. Keep tokens in `.env`, Docker secrets, or a
real secret manager; do not commit them.
