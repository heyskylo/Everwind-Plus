#!/usr/bin/env bash
#
# Pulls the latest Everwind release IPA and site files onto the VPS and
# publishes them to the Caddy docroot.
#
# Installed at /usr/local/bin/everwind-sync.sh and driven by the
# everwind-sync.timer systemd unit. Can be run by hand at any time:
#
#   sudo systemctl start everwind-sync.service
#
set -euo pipefail

REPO_URL="https://github.com/heyskylo/Everwind-Plus.git"
BRANCH="main"
CHECKOUT="/opt/everwind"
STATE_DIR="/var/lib/everwind"
SERVE_DIR="/srv/repo.gayfeet.lol"
BASE_URL="https://repo.gayfeet.lol"
IPA_URL="https://github.com/heyskylo/Everwind-Plus/releases/latest/download/Everwind.ipa"

CACHE_IPA="$STATE_DIR/Everwind.ipa"

log() { printf '[everwind-sync] %s\n' "$*"; }

install -d -m 0755 "$STATE_DIR"

# 1. Clone or fast-forward the checkout (source of the site/ directory).
if [ -d "$CHECKOUT/.git" ]; then
	git -C "$CHECKOUT" fetch --quiet --depth 1 origin "$BRANCH"
	git -C "$CHECKOUT" reset --hard --quiet "origin/$BRANCH"
else
	rm -rf "$CHECKOUT"
	git clone --quiet --depth 1 --branch "$BRANCH" "$REPO_URL" "$CHECKOUT"
fi

SITE="$CHECKOUT/site"

# 2. Fetch the newest release IPA (public repo: no auth needed).
TMP_IPA="$(mktemp "${TMPDIR:-/tmp}/everwind-ipa.XXXXXX")"
if curl -fsSL --retry 3 --retry-delay 2 -o "$TMP_IPA" "$IPA_URL" && [ -s "$TMP_IPA" ]; then
	mv "$TMP_IPA" "$CACHE_IPA"
	log "fetched new IPA ($(stat -c%s "$CACHE_IPA") bytes)"
else
	rm -f "$TMP_IPA"
	log "no release IPA available; keeping cached IPA"
fi

# 3. Regenerate the AltStore/Feather source JSON from the cached IPA.
if [ -f "$CACHE_IPA" ]; then
	python3 "$CHECKOUT/scripts/generate_source.py" \
		--ipa "$CACHE_IPA" \
		--out "$SITE/apps.json" \
		--base-url "$BASE_URL"
else
	log "no IPA cached; keeping committed apps.json"
fi

# 4. Publish site files to the Caddy docroot, then drop in the IPA.
install -d -o caddy -g caddy -m 0755 "$SERVE_DIR"
rsync -a --delete --chown=caddy:caddy --chmod=D755,F644 "$SITE/" "$SERVE_DIR/"
if [ -f "$CACHE_IPA" ]; then
	install -o caddy -g caddy -m 0644 "$CACHE_IPA" "$SERVE_DIR/Everwind.ipa"
fi

log "published to $SERVE_DIR: $(ls -1 "$SERVE_DIR" | tr '\n' ' ')"
