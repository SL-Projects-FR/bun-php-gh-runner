FROM ubuntu:24.04

ARG RUNNER_VERSION=2.333.1
ARG PHP_VERSION=8.5
ARG PLAYWRIGHT_VERSION=1.57.0
ARG TARGETARCH=x64

ENV DEBIAN_FRONTEND=noninteractive

# ─── System packages ───────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    cron \
    curl \
    git \
    gnupg \
    jq \
    libicu74 \
    lsb-release \
    rsync \
    software-properties-common \
    sudo \
    unzip \
    wget \
    zip \
    # Playwright system deps
    libasound2t64 \
    libatk-bridge2.0-0t64 \
    libatk1.0-0t64 \
    libcups2t64 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0t64 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

# ─── PHP ───────────────────────────────────────────────────────────────────────
RUN add-apt-repository ppa:ondrej/php -y \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-bcmath \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-imagick \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-pcov \
    php${PHP_VERSION}-redis \
    php${PHP_VERSION}-sqlite3 \
    php${PHP_VERSION}-xdebug \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-zip \
    && rm -rf /var/lib/apt/lists/*

# ─── Node.js 22.x LTS ─────────────────────────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# ─── Bun ───────────────────────────────────────────────────────────────────────
RUN curl -fsSL https://bun.sh/install | bash \
    && mv /root/.bun/bin/bun /usr/local/bin/bun \
    && ln -s /usr/local/bin/bun /usr/local/bin/bunx

# ─── Composer ──────────────────────────────────────────────────────────────────
RUN curl -fsSL https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# ─── Playwright browsers ──────────────────────────────────────────────────────
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/playwright-browsers
RUN npx playwright@${PLAYWRIGHT_VERSION} install --with-deps

# ─── Runner user ───────────────────────────────────────────────────────────────
RUN useradd -m -u 1001 -s /bin/bash runner \
    && echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/runner \
    && chmod 0440 /etc/sudoers.d/runner

# ─── GitHub Actions Runner ─────────────────────────────────────────────────────
RUN mkdir -p /home/runner/actions-runner \
    && cd /home/runner/actions-runner \
    && curl -fsSL -o runner.tar.gz \
       "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${TARGETARCH}-${RUNNER_VERSION}.tar.gz" \
    && tar xzf runner.tar.gz \
    && rm runner.tar.gz \
    && chown -R runner:runner /home/runner/actions-runner

# ─── Persistent config directory (for runner credentials) ─────────────────────
RUN mkdir -p /home/runner/runner-config \
    && chown runner:runner /home/runner/runner-config

# ─── Cache directory ──────────────────────────────────────────────────────────
RUN mkdir -p /cache/node_modules /cache/vendor /cache/.locks /var/log \
    && chown -R runner:runner /cache

# ─── Scripts ───────────────────────────────────────────────────────────────────
COPY --chmod=755 scripts/restore-cache.sh /usr/local/bin/restore-cache
COPY --chmod=755 scripts/save-cache.sh    /usr/local/bin/save-cache
COPY --chmod=755 scripts/cleanup-cache.sh /usr/local/bin/cleanup-cache
COPY --chmod=755 scripts/entrypoint.sh    /usr/local/bin/entrypoint.sh

# ─── Cron ──────────────────────────────────────────────────────────────────────
COPY cron/cache-cleanup.cron /etc/cron.d/cache-cleanup
RUN chmod 0644 /etc/cron.d/cache-cleanup \
    && crontab -u runner /etc/cron.d/cache-cleanup

# ─── Finalize ──────────────────────────────────────────────────────────────────
USER runner
WORKDIR /home/runner/actions-runner

ENTRYPOINT ["entrypoint.sh"]
