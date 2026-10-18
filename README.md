### KDance registration

This program (`KDance registration`) is a Django based web app.

It is designed to help associations to handle their members database. It was specifically designed for the K'Dance association, thus, there are a lot of specific features / hardcoded stuff. Nevertheless, I believe it can be useful for any other association, with a few modifications.

##### To run locally
Copy `kdance/.env.example` to `kdance/.env` and adjust the local settings if needed. The example uses development-only database and administrator credentials; do not reuse them outside your local machine. SMTP and payment credentials can remain empty unless you need to test those integrations.
```sh
cd kdance
docker compose up -d db
docker compose run --rm backend python /app/manage.py migrate
docker compose up --build
```

The initial migration creates the administrator configured in `.env` (`SUPERUSER_EMAIL` and `SUPERUSER_PWD`). In your browser, go to `http://localhost:8000`.

##### Maintenance and evolution
I'm more or less active on this repo, depending on the needs of the association. Nevertheless, this is some kind of (big) pet project for me, and I want to take the opportunity to improve various stuff: code of course, but also deployment, testing and so on. Feel free to reach out for any comment or advice.

##### License and copyright
Copyright 2024 - present, Andréa Marnier

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.

##### Contact
For any question, comment or whatever, you can contact me by email. See my first and last name in copyright section? Remove any accent, and build firstname.lastname[at]gmail[dot]com.
