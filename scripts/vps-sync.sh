#!/usr/bin/env bash
#
# Pulls the latest Everwind and Minecraft LCE release IPAs plus the site files
# onto the VPS and publishes them to the Caddy docroot.
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
MCLCE_URL="https://github.com/heyskylo/MCLCE-iOS/releases/latest/download/Minecraft.LCE.ipa"

CACHE_IPA="$STATE_DIR/Everwind.ipa"
CACHE_MCLCE="$STATE_DIR/Minecraft.LCE.ipa"

log() { printf '[sideload-sync] %s\n' "$*"; }

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

# 2. Fetch the newest release IPAs (public repos: no auth needed). On
#    failure keep the cached copy so the docroot never goes empty.
fetch_ipa() {
	local url="$1" dest="$2" label="$3"
	local tmp
	tmp="$(mktemp "${TMPDIR:-/tmp}/${label}-ipa.XXXXXX")"
	if curl -fsSL --retry 3 --retry-delay 2 -o "$tmp" "$url" && [ -s "$tmp" ]; then
		mv "$tmp" "$dest"
		log "fetched $label IPA ($(stat -c%s "$dest") bytes)"
		return 0
	fi
	rm -f "$tmp"
	log "no $label release IPA available; keeping cached IPA"
	return 1
}

fetch_ipa "$IPA_URL" "$CACHE_IPA" everwind || true
fetch_ipa "$MCLCE_URL" "$CACHE_MCLCE" mclce || true

# 3. Regenerate the AltStore/Feather source JSON from the cached IPAs.
if [ -f "$CACHE_IPA" ] && [ -f "$CACHE_MCLCE" ]; then
	python3 "$CHECKOUT/scripts/generate_source.py" \
		--ipa "$CACHE_IPA" \
		--mclce-ipa "$CACHE_MCLCE" \
		--out "$SITE/apps.json" \
		--base-url "$BASE_URL"
elif [ -f "$CACHE_IPA" ]; then
	python3 "$CHECKOUT/scripts/generate_source.py" \
		--ipa "$CACHE_IPA" \
		--out "$SITE/apps.json" \
		--base-url "$BASE_URL"
else
	log "no Everwind IPA cached; keeping committed apps.json"
fi

# 4. Publish site files to the Caddy docroot, then drop in the IPAs.
#    /assets/ is excluded: it holds the runtime asset pack that the iOS CI
#    downloads at build time and is managed out-of-band, so the mirror
#    must not delete it.
install -d -o caddy -g caddy -m 0755 "$SERVE_DIR"
rsync -a --delete --exclude=/assets/ --chown=caddy:caddy --chmod=D755,F644 "$SITE/" "$SERVE_DIR/"
if [ -f "$CACHE_IPA" ]; then
	install -o caddy -g caddy -m 0644 "$CACHE_IPA" "$SERVE_DIR/Everwind.ipa"
fi
if [ -f "$CACHE_MCLCE" ]; then
	install -o caddy -g caddy -m 0644 "$CACHE_MCLCE" "$SERVE_DIR/Minecraft.LCE.ipa"
fi

log "published to $SERVE_DIR: $(ls -1 "$SERVE_DIR" | tr '\n' ' ')"
