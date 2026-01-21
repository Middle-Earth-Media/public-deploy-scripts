#!/bin/sh

ulimit -n 4096
set -e  # Exit on error

# --------------------------------------
# ✅ Parse CLI Arguments
# --------------------------------------
FORWARD_ARGS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --pv|--no-tailwind|--ua-template) FORWARD_ARGS="$FORWARD_ARGS $1" ;;
    *) echo ""; echo "❌ Unknown option: $1"; exit 1 ;;
  esac
  shift
done

# --------------------------------------
# 📥 Pull supporting files if missing
# --------------------------------------
[ ! -f .github/workflows/build.yaml ] && \
    # TEST: curl -sSL --create-dirs -o .github/workflows/build.yaml https://raw.githubusercontent.com/Middle-Earth-Media/public-deploy-scripts/test/build.yaml
    # PROD: curl -sSL --create-dirs -o .github/workflows/build.yaml  https://raw.githubusercontent.com/Middle-Earth-Media/public-deploy-scripts/prod/build.yaml
    curl -sSL --create-dirs -o .github/workflows/build.yaml https://raw.githubusercontent.com/Middle-Earth-Media/public-deploy-scripts/prod/build.yaml

[ ! -f .git/hooks/pre-commit ] && \
    # TEST: curl -sSL --create-dirs -o .git/hooks/pre-commit https://raw.githubusercontent.com/Middle-Earth-Media/public-deploy-scripts/test/laravel-hooks/pre-commit && chmod +x .git/hooks/pre-commit
    # PROD: curl -sSL --create-dirs -o .git/hooks/pre-commit https://raw.githubusercontent.com/Middle-Earth-Media/public-deploy-scripts/prod/laravel-hooks/pre-commit && chmod +x .git/hooks/pre-commit
    curl -sSL --create-dirs -o .git/hooks/pre-commit https://raw.githubusercontent.com/Middle-Earth-Media/public-deploy-scripts/prod/laravel-hooks/pre-commit && chmod +x .git/hooks/pre-commit

[ ! -f docker-compose.yaml ] && \
    # TEST: curl -sSL -o docker-compose.yaml https://raw.githubusercontent.com/Middle-Earth-Media/public-deploy-scripts/test/docker-compose.yaml
    # PROD: curl -sSL -o docker-compose.yaml https://raw.githubusercontent.com/Middle-Earth-Media/public-deploy-scripts/prod/docker-compose.yaml
    curl -sSL -o docker-compose.yaml https://raw.githubusercontent.com/Middle-Earth-Media/public-deploy-scripts/prod/docker-compose.yaml

[ ! -f deploy-plan.json ] && \
    # TEST: curl -sSL -o deploy-plan.json https://raw.githubusercontent.com/Middle-Earth-Media/public-deploy-scripts/test/deploy-plan.json
    # PROD: curl -sSL -o deploy-plan.json https://raw.githubusercontent.com/Middle-Earth-Media/public-deploy-scripts/prod/deploy-plan.json
    curl -sSL -o deploy-plan.json https://raw.githubusercontent.com/Middle-Earth-Media/public-deploy-scripts/prod/deploy-plan.json

# --------------------------------------
# 🗂️ Handle PV Option
# --------------------------------------
if echo "$FORWARD_ARGS" | grep -qw -- --pv; then
    # TEST: curl https://raw.githubusercontent.com/Middle-Earth-Media/public-deploy-scripts/test/add-pv.sh --create-dirs -o add-pv.sh
    # PROD: curl https://raw.githubusercontent.com/Middle-Earth-Media/public-deploy-scripts/prod/add-pv.sh --create-dirs -o add-pv.sh
	curl https://raw.githubusercontent.com/Middle-Earth-Media/public-deploy-scripts/prod/add-pv.sh --create-dirs -o add-pv.sh
	chmod +x add-pv.sh
	./add-pv.sh
	rm add-pv.sh
fi

# --------------------------------------
# 🐳 Always generate Dockerfile.dev from API
# --------------------------------------
    # TEST: https://build-dockerfile-api-test.thewestgate.org/api/docker/build-dev > Dockerfile.dev
    # PROD: https://build-dockerfile-api.thewestgate.org/api/docker/build-dev > Dockerfile.dev
curl -X POST -d @deploy-plan.json \
     -H "Content-Type: application/json" -H "AUTH: $AUTH" \
     https://build-dockerfile-api.thewestgate.org/api/docker/build-dev > Dockerfile.dev

# --------------------------------------
# 🐳 Rebuild Container
# --------------------------------------
docker stop app || true
docker rm app || true

if command -v docker-compose >/dev/null 2>&1; then
    docker-compose up -d --build
else
    docker compose up -d --build
fi

# --------------------------------------
# 🚀 Run Laravel provisioning inside container
# --------------------------------------
# TEST: curl -sSL -o laravel-app.sh https://raw.githubusercontent.com/Middle-Earth-Media/public-deploy-scripts/test/laravel-app.sh
# PROD: curl -sSL -o laravel-app.sh https://raw.githubusercontent.com/Middle-Earth-Media/public-deploy-scripts/prod/laravel-app.sh
curl -sSL -o laravel-app.sh https://raw.githubusercontent.com/Middle-Earth-Media/public-deploy-scripts/prod/laravel-app.sh
chmod +x laravel-app.sh
docker exec -it app ./laravel-app.sh $FORWARD_ARGS
rm laravel-app.sh

# --------------------------------------
# 🔧 Run npm dev server in background
# --------------------------------------
echo ""
echo "Running npm run dev in background..."
docker exec -d app npm run dev
