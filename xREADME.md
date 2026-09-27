# Demo Case: Hatchet as a Durable Execution Orchestration Layer

<blockquote>
Einfachste Variante
Stack zunächst nur mit GitLab starten:

`export GITLAB_ROOT_PASSWORD='change-me'`

`docker compose up -d gitlab`

Warten, bis GitLab bereit ist:

`docker compose logs -f gitlab`

Browser öffnen:
`http://localhost:8080`

Login:

Username: `root`
Password: `<GITLAB_ROOT_PASSWORD>`
In GitLab:

Avatar → Edit profile → Access → Personal access tokens

Token anlegen mit mindestens:

`api`

als Scope.

Token anschließend nicht ins Compose-File schreiben, sondern beispielsweise:
export `GITLAB_API_TOKEN='glpat-xxxxxxxxxxxxxxxx'`
Jetzt den Rest starten:
docker compose up -d

</blockquote>
~~~sh
export GITLAB_ROOT_PASSWORD='change-me-for-demo'
export GITLAB_API_TOKEN='glpat-...'

docker compose up -d

~~~
