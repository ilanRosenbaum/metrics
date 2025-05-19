# Base image
FROM node:20-bookworm-slim@sha256:83e53269616ca1b22cf7533e5db4e2f1a0c24a8e818b21691d6d4a69ec9e2c6d

# Copy repository
COPY . /metrics
WORKDIR /metrics

# Setup
# Base and essential tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    gnupg \
    ca-certificates \
    libgconf-2-4 \
    curl \
    unzip \
  && rm -rf /var/lib/apt/lists/*

# Google Chrome (see point 3 about Puppeteer)
RUN wget -q -O /tmp/google-chrome.asc https://dl-ssl.google.com/linux/linux_signing_key.pub \
    && gpg --dearmor /tmp/google-chrome.asc \
    && mv /tmp/google-chrome.gpg /usr/share/keyrings/google-chrome.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && rm -f /tmp/google-chrome.asc \
    && apt-get update && apt-get install -y --no-install-recommends \
    google-chrome-stable \
    fonts-ipafont-gothic \
    fonts-wqy-zenhei \
    fonts-thai-tlwg \
    fonts-kacst \
    fonts-freefont-ttf \
    libxss1 \
    libx11-xcb1 \
    libxtst6 \
    lsb-release \
  && rm -rf /var/lib/apt/lists/*

# Deno
RUN curl -fsSL https://deno.land/x/install/install.sh | DENO_INSTALL=/usr/local sh

# Ruby, Git, Build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    ruby-full \
    git \
    g++ \
    cmake \
    pkg-config \
    libssl-dev \
    xz-utils \
  && rm -rf /var/lib/apt/lists/*
RUN gem install licensed

# Python
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
  && rm -rf /var/lib/apt/lists/*

# NPM dependencies (see point 3 about Puppeteer ENV vars)
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome-stable
COPY package.json package-lock.json* .npmrc* ./
RUN npm ci

# Application build
COPY . .
RUN chmod +x /metrics/source/app/action/index.mjs \
    && npm run build

# Environment variables
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD true
ENV PUPPETEER_BROWSER_PATH "google-chrome-stable"

# Execute GitHub action
ENTRYPOINT node /metrics/source/app/action/index.mjs
