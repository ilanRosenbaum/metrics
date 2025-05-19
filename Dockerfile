FROM node:20-bookworm-slim

# Set DEBIAN_FRONTEND to noninteractive to prevent apt-get from hanging on prompts
ENV DEBIAN_FRONTEND=noninteractive

# Copy repository contents early for WORKDIR context, but specific files will be COPIED again later for better caching.
COPY . /metrics
WORKDIR /metrics

# Make the entrypoint script executable early (if it's part of the initial COPY)
RUN chmod +x /metrics/source/app/action/index.mjs

# Layer 1: Install base system utilities & initial update
RUN echo "RUN Layer 1: Starting - Install base system utilities" \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        wget \
        gnupg \
        ca-certificates \
        libgconf-2-4 \
        curl \
        unzip \
    && rm -rf /var/lib/apt/lists/* \
    && echo "RUN Layer 1: Finished - Install base system utilities"

# Layer 2: Setup Google Chrome repository
RUN echo "RUN Layer 2: Starting - Setup Google Chrome repository" \
    && wget -q -O /tmp/google-chrome.asc https://dl-ssl.google.com/linux/linux_signing_key.pub \
    && gpg --dearmor -o /usr/share/keyrings/google-chrome-archive-keyring.gpg /tmp/google-chrome.asc \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-archive-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && rm -f /tmp/google-chrome.asc \
    && apt-get update \
    && echo "RUN Layer 2: Finished - Setup Google Chrome repository and apt-get update"

# Layer 3: Install Google Chrome Stable and essential fonts/X11 libs
# This is where the hang was suspected.
RUN echo "RUN Layer 3: Starting - Install google-chrome-stable, fonts, and X11/LSB libs" \
    && apt-get install -y --no-install-recommends \
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
    && rm -rf /var/lib/apt/lists/* \
    && echo "RUN Layer 3: Finished - Install google-chrome-stable, fonts, and X11/LSB libs"

# Layer 4: Install Deno
RUN echo "RUN Layer 4: Starting - Install Deno" \
    && curl -fsSL https://deno.land/x/install/install.sh | DENO_INSTALL=/usr/local sh \
    && echo "RUN Layer 4: Finished - Install Deno"

# Layer 5: Install Ruby, Git, and build tools for gems (including Nokogiri dependencies)
RUN echo "RUN Layer 5: Starting - Install Ruby, Git, and build/Nokogiri tools" \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ruby-full \
        git \
        g++ \
        cmake \
        make \
        pkg-config \
        libssl-dev \
        libxml2-dev \
        libxslt1-dev \
        zlib1g-dev \
        xz-utils \
    && rm -rf /var/lib/apt/lists/* \
    && echo "RUN Layer 5: Finished - Install Ruby, Git, and build/Nokogiri tools"

# Layer 6: Install 'licensed' gem
RUN echo "RUN Layer 6: Starting - Install 'licensed' gem" \
    && gem install licensed \
    && echo "RUN Layer 6: Finished - Install 'licensed' gem"

# Layer 7: Install Python
RUN echo "RUN Layer 7: Starting - Install Python" \
    && apt-get update \
    && apt-get install -y --no-install-recommends python3 \
    && rm -rf /var/lib/apt/lists/* \
    && echo "RUN Layer 7: Finished - Install Python"

# Layer 8: Set Puppeteer ENV vars FOR INSTALL, copy package files, and install npm dependencies
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome-stable

COPY package.json package-lock.json* .npmrc* ./
RUN echo "RUN Layer 8: Starting - npm ci (installing Node modules)" \
    && npm ci \
    && echo "RUN Layer 8: Finished - npm ci"

# Layer 9: Copy the rest of the application code (if not already there from initial COPY)
# And run the build script.
# Ensure the .dockerignore file is properly configured to avoid copying unnecessary files.
COPY . .
RUN echo "RUN Layer 9: Starting - npm run build" \
    # Re-ensure entrypoint is executable in case COPY . overwrote permissions
    && chmod +x /metrics/source/app/action/index.mjs \
    && npm run build \
    && echo "RUN Layer 9: Finished - npm run build"

# Original Environment variables from your Dockerfile (placed before ENTRYPOINT)
# PUPPETEER_SKIP_CHROMIUM_DOWNLOAD is already true from above, but setting it again does no harm.
# PUPPETEER_BROWSER_PATH is preserved as per your concern.
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD true
ENV PUPPETEER_BROWSER_PATH "google-chrome-stable"

# Execute GitHub action
ENTRYPOINT [ "node", "/metrics/source/app/action/index.mjs" ]