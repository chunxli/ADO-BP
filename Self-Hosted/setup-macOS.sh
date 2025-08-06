#!/bin/bash
set -e

# === Default parameters (set here or leave blank to prompt) ===
DEFAULT_ORG_URL=""
DEFAULT_PAT=""
DEFAULT_POOL="Default"
DEFAULT_AGENT_NAME="$(hostname)"
# === End default parameters ===

# 1. Detect CPU architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
    AGENT_ARCH="osx-arm64"
else
    AGENT_ARCH="osx-x64"
fi

# 2. Fetch latest agent version
LATEST_VERSION=$(curl -s https://api.github.com/repos/microsoft/azure-pipelines-agent/releases/latest | grep 'tag_name' | cut -d\" -f4 | sed 's/^v//')
if [ -z "$LATEST_VERSION" ]; then
    echo "Failed to fetch latest agent version. Exiting."
    exit 1
fi
AGENT_PKG="vsts-agent-${AGENT_ARCH}-${LATEST_VERSION}.tar.gz"
AGENT_PKG_URL="https://download.agent.dev.azure.com/agent/${LATEST_VERSION}/${AGENT_PKG}"

# 3. Install dependencies
command -v curl >/dev/null 2>&1 || { echo "curl not found, installing..."; brew install curl; }
command -v tar >/dev/null 2>&1 || { echo "tar not found, installing..."; brew install tar; }
command -v xcpretty >/dev/null 2>&1 || { echo "xcpretty not found, installing..."; sudo gem install xcpretty; }

# 4. Download agent package
if [ ! -f "$AGENT_PKG" ]; then
    echo "Downloading Azure DevOps agent package: $AGENT_PKG_URL"
    curl -O $AGENT_PKG_URL
fi

# 4.1 Clear extended attributes to avoid macOS Gatekeeper errors
xattr -c "$AGENT_PKG"

# 5. Extract package
AGENT_DIR="ado-agent"
rm -rf $AGENT_DIR
mkdir $AGENT_DIR
cd $AGENT_DIR
tar zxvf ../$AGENT_PKG

# 6. Configure agent
ORG_URL="${AZP_URL:-${DEFAULT_ORG_URL}}"  # Azure DevOps org URL
PAT="${AZP_TOKEN:-${DEFAULT_PAT}}"         # Personal Access Token
POOL="${AZP_POOL:-${DEFAULT_POOL}}"
AGENT_NAME="${AZP_AGENT_NAME:-${DEFAULT_AGENT_NAME}}"

if [ -z "$ORG_URL" ]; then
    read -p "Enter Azure DevOps organization URL: " ORG_URL
fi
if [ -z "$PAT" ]; then
    read -s -p "Enter Personal Access Token: " PAT
    echo
fi
if [ -z "$POOL" ]; then
    read -p "Enter Agent Pool (Default: Default): " POOL
    POOL=${POOL:-Default}
fi
if [ -z "$AGENT_NAME" ]; then
    read -p "Enter Agent Name (Default: $(hostname)): " AGENT_NAME
    AGENT_NAME=${AGENT_NAME:-$(hostname)}
fi

./config.sh --unattended \
    --url "$ORG_URL" \
    --auth pat \
    --token "$PAT" \
    --pool "$POOL" \
    --agent "$AGENT_NAME" \
    --acceptTeeEula \
    --replace

# 7. Install as service
sudo ./svc.sh install

# 8. Start the service
sudo ./svc.sh start

echo "Azure DevOps agent installed and started as a service."
