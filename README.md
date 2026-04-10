# Self-Hosted GitHub Actions Runner

Image Docker custom pour les runners GitHub Actions self-hosted, pre-equipee avec les outils necessaires pour les projets PHP/Laravel et Vue.js/Bun.

## Outils pre-installes

| Outil | Version |
|-------|---------|
| PHP | 8.5 (cli + bcmath, curl, gd, imagick, mbstring, mysql, pcov, redis, sqlite3, xdebug, xml, zip) |
| Composer | latest |
| Node.js | 22.x LTS |
| Bun | latest |
| Playwright | deps systeme uniquement (browsers caches sur volume) |
| GitHub Actions Runner | 2.333.1 |

## Deploiement

### 1. Configuration

```bash
cp .env.example .env
```

Renseigner les variables dans `.env` :

```
GITHUB_URL=https://github.com/your-org
RUNNER_TOKEN_1=<token depuis GitHub Settings > Actions > Runners > New self-hosted runner>
RUNNER_TOKEN_2=<token pour le 2eme runner>
RUNNER_NAME_1=runner-1
RUNNER_NAME_2=runner-2
RUNNER_LABELS=self-hosted,linux,x64
```

### 2. Build et demarrage

```bash
docker compose build
docker compose up -d
```

Les runners apparaissent dans **GitHub Settings > Actions > Runners**.

### 3. Deploiement sur une autre machine

Copier le projet sur la machine, creer un `.env` avec des noms de runners differents et de nouveaux tokens, puis `docker compose up -d`. Fonctionne aussi sur Windows via Docker Desktop (WSL2).

### 4. Arret / redemarrage

```bash
docker compose down     # arret — le runner passe en "Offline" sur GitHub
docker compose up -d    # redemarrage — reconnexion automatique
```

Le token n'est necessaire qu'a la premiere configuration. Les credentials sont persistees dans un volume Docker.

## Systeme de cache

L'image embarque deux scripts disponibles dans le `PATH` de tous les workflows : `restore-cache` et `save-cache`. Ils gerent un cache local sur un volume Docker, base sur le hash SHA256 des lock files.

### Usage

```yaml
restore-cache <type> <lockfile> [target_dir]
save-cache    <type> <lockfile> [source_dir]
```

- `type` : identifiant du cache (ex: `node_modules`, `vendor`, `playwright`)
- `lockfile` : fichier dont le hash sert de cle (ex: `bun.lock`, `composer.lock`)
- `target_dir` / `source_dir` : optionnel, chemin custom (par defaut `./<type>`)

### Exemples dans les workflows

#### node_modules (Bun)

```yaml
- name: Restore node_modules
  id: cache-node
  run: restore-cache node_modules bun.lock
  continue-on-error: true

- name: Install dependencies
  if: steps.cache-node.outcome == 'failure'
  run: bun install --frozen-lockfile

- name: Save node_modules cache
  if: steps.cache-node.outcome == 'failure'
  run: save-cache node_modules bun.lock
```

#### vendor (Composer)

```yaml
- name: Restore vendor
  id: cache-vendor
  run: restore-cache vendor composer.lock
  continue-on-error: true

- name: Install PHP dependencies
  if: steps.cache-vendor.outcome == 'failure'
  run: composer install --no-interaction --prefer-dist

- name: Save vendor cache
  if: steps.cache-vendor.outcome == 'failure'
  run: save-cache vendor composer.lock
```

#### Playwright browsers

Les navigateurs ne sont pas dans l'image Docker (pour eviter les problemes de version). Ils sont caches sur le volume via le 3eme argument :

```yaml
- name: Get Playwright version
  run: echo $(bunx playwright --version) > .pw-version

- name: Restore Playwright browsers
  id: cache-pw
  run: restore-cache playwright .pw-version $PLAYWRIGHT_BROWSERS_PATH
  continue-on-error: true

- name: Install Playwright browsers
  if: steps.cache-pw.outcome == 'failure'
  run: bunx playwright install --with-deps

- name: Save Playwright browsers cache
  if: steps.cache-pw.outcome == 'failure'
  run: save-cache playwright .pw-version $PLAYWRIGHT_BROWSERS_PATH
```

### Nettoyage automatique

Un cron quotidien (3h du matin) supprime les entrees de cache inutilisees depuis plus de 30 jours. Les logs sont dans `/var/log/cache-cleanup.log`.

## Volumes Docker

| Volume | Contenu | Partage |
|--------|---------|---------|
| `cache-data` | Cache node_modules, vendor, playwright | Partage entre tous les runners de la machine |
| `runner-N-config` | Credentials du runner (`.credentials`, `.runner`) | Un par runner |
| `runner-N-work` | Workspace de travail | Un par runner |

## Mise a jour

### Mettre a jour le runner GitHub Actions

Modifier `RUNNER_VERSION` dans `docker-compose.yml`, puis :

```bash
docker compose build
docker compose down
docker volume rm bun-php-gh-runner_runner-1-config bun-php-gh-runner_runner-2-config
docker compose up -d
```

Les volumes de config doivent etre supprimes car la nouvelle version du runner necessite une re-registration.

### Mettre a jour PHP, Node.js ou Bun

Modifier les `args` dans `docker-compose.yml`, puis `docker compose build && docker compose up -d`. Pas besoin de supprimer les volumes.
