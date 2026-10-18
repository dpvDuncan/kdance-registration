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

Pour Traefik en HTTPS, définissez `ALLOWED_HOSTS` avec le nom d'hôte public sans
schéma et `CSRF_TRUSTED_ORIGINS` avec son origine complète, par exemple
`https://inscriptions.example.org`. Django utilise `X-Forwarded-Proto` transmis
par Traefik pour reconnaître les requêtes HTTPS. N'autorisez l'accès au port
`8000` qu'à travers le proxy de confiance.

MariaDB utilise un nouveau volume `kdance_mariadb_data`. Les fichiers de données
du précédent conteneur MySQL ne sont pas réutilisés : faites une sauvegarde SQL
de MySQL puis restaurez-la dans MariaDB avant de basculer les données à conserver.
L'ancien volume MySQL reste intact. Podman ajuste le propriétaire du volume
MariaDB au démarrage (`:U`) pour qu'il soit inscriptible dans le namespace
rootless du pod; cette opération peut prendre du temps si le volume contient
déjà beaucoup de fichiers.

Construisez l'image du backend depuis `kdance` :

```sh
podman build -t localhost/kdance-backend:latest -f Dockerfile .
```

Le backend s'exécute avec l'UID/GID `10001` défini dans l'image. Le Quadlet
du pod utilise `UserNS=keep-id:uid=10001,gid=10001` pour que le montage du code
reste accessible avec Podman rootless. Ce réglage est au niveau du pod, partagé
par ses conteneurs.

## Installation et démarrage

Depuis le répertoire `kdance`, le script automatise la préparation, le build,
l'installation des Quadlets et les migrations :

```sh
./deploy-podman.sh
```

Il ne remplace jamais les fichiers `.env` existants. Sur un nouveau clone, il
les crée depuis les exemples puis s'arrête pour vous laisser renseigner les
secrets avant de relancer le déploiement.

Pour Ubuntu, utilisez une version de Podman qui fournit Quadlet et systemd
utilisateur. Pour que l'application redémarre après un reboot sans session
ouverte, activez le lingering avec `sudo loginctl enable-linger "$USER"`.

### Installation manuelle

Installez les unités Quadlet dans le répertoire systemd de l'utilisateur :

```sh
mkdir -p ~/.config/containers/systemd
rm -f ~/.config/containers/systemd/kdance-db.network
cp quadlet/kdance-mariadb.volume quadlet/kdance-registration.pod \
   quadlet/kdance-db.container \
   quadlet/kdance-backend.container \
   ~/.config/containers/systemd/
systemctl --user daemon-reload
systemctl --user start kdance-registration-pod.service
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

Le pod Quadlet est rattaché à `default.target` et démarre ses conteneurs après
`daemon-reload`; ne lancez pas `systemctl enable` directement sur les `.service`
générés. Pour un démarrage au boot sans session ouverte, activez le lingering de
l'utilisateur comme indiqué plus haut.