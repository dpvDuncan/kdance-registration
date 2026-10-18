# Quadlets Podman

Ces unités remplacent `docker-compose.yml` pour une exécution Podman rootless.
Elles supposent que le dépôt se trouve dans `~/GitHub/kdance-registration`.
Si ce n'est pas le cas, adaptez les chemins `%h/GitHub/kdance-registration`
dans `kdance-backend.container` et `kdance-db.container`.

## Préparation

Depuis le répertoire `kdance` :

```sh
test -f .env || cp .env.example .env
test -f quadlet/mysql.env || cp quadlet/mysql.env.example quadlet/mysql.env
```

Configurez les variables Django dans `.env`. Dans `quadlet/mysql.env`, réutilisez
les mêmes valeurs pour `MARIADB_DATABASE`, `MARIADB_USER` et
`MARIADB_PASSWORD` que pour `DB_NAME`, `DB_USER` et `DB_PASSWORD` dans `.env`.
Définissez également un mot de passe `MARIADB_ROOT_PASSWORD` robuste. Les anciens
noms `MYSQL_*` restent acceptés par l'image MariaDB. Ne versionnez pas ces deux
fichiers.

MariaDB utilise un nouveau volume `kdance_mariadb_data`. Les fichiers de données
du précédent conteneur MySQL ne sont pas réutilisés : faites une sauvegarde SQL
de MySQL puis restaurez-la dans MariaDB avant de basculer les données à conserver.
L'ancien volume MySQL reste intact.

Construisez l'image du backend depuis `kdance` :

```sh
podman build -t localhost/kdance-backend:latest -f Dockerfile .
```

Le backend s'exécute avec l'UID/GID `10001` défini dans l'image. Le Quadlet
utilise `UserNS=keep-id:uid=10001,gid=10001` pour que le montage du code reste
accessible avec Podman rootless.

## Installation et démarrage

Installez les unités Quadlet dans le répertoire systemd de l'utilisateur :

```sh
mkdir -p ~/.config/containers/systemd
rm -f ~/.config/containers/systemd/kdance-db.network
cp quadlet/kdance-mariadb.volume quadlet/kdance-registration.pod \
   quadlet/kdance-db.container \
   quadlet/kdance-backend.container \
   ~/.config/containers/systemd/
systemctl --user daemon-reload
systemctl --user start kdance-backend.service
```

Le backend démarre après que MariaDB a passé son contrôle de santé. Les deux
conteneurs partagent le réseau du pod; l'unité Quadlet remplace donc `DB_HOST`
par `localhost` pour le backend. Le `DB_HOST=db` de `.env` reste utilisable par
Docker Compose. Seul le port `8000` de l'application est publié sur l'hôte;
MariaDB reste accessible uniquement depuis le pod. L'interface est disponible
sur `http://localhost:8000`.

Pour appliquer les migrations Django :

```sh
podman exec kdance_backend python /app/manage.py migrate
```

Pour démarrer automatiquement les unités après ouverture de session, activez
`kdance-backend.service` avec `systemctl --user enable kdance-backend.service`.