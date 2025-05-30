#!/usr/bin/env bash

set -e  # Exit on error

# --- Welcome Message ---
echo ""
echo "🚀 JUCE Plugin Project Initializer"
echo ""
echo "This script will:"
echo "• Use https://github.com/danielraffel/JUCE-Plugin-Starter.git as a template"
echo "• Remove its git history"
echo "• Initialize your new JUCE plugin project in a fresh Git repo"
echo "• Create a new *private* GitHub repository via the GitHub CLI (gh)"
echo "• Push your first commit to that repo"
echo ""
read -p "❓ Do you want to continue? (Y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "❌ Cancelled by user."
  exit 0
fi

# --- Check .env exists ---
if [[ ! -f .env ]]; then
  echo "❌ .env file not found. Please run: cp .env.example .env"
  exit 1
fi

# --- Load .env variables ---
set -o allexport
source .env
set +o allexport

# --- Validate required variables ---
if [[ -z "$PROJECT_NAME" || -z "$GITHUB_USERNAME" || -z "$PROJECT_PATH" ]]; then
  echo "❌ Missing one of: PROJECT_NAME, GITHUB_USERNAME, PROJECT_PATH in .env"
  exit 1
fi

# --- Check gh CLI is available ---
if ! command -v gh &> /dev/null; then
  echo "❌ GitHub CLI (gh) not found. Install it: https://cli.github.com/"
  exit 1
fi

# --- Check gh authentication ---
if ! gh auth status &> /dev/null; then
  echo "⚠️  GitHub CLI is not authenticated."
  echo "👉 Run: gh auth login"
  exit 1
fi

# --- Validate and sanitize GitHub project name ---
validate_project_name() {
  local name="$1"
  if [[ "$name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    return 0
  else
    return 1
  fi
}

while ! validate_project_name "$PROJECT_NAME"; do
  echo ""
  echo "❌ Invalid GitHub repo name: '$PROJECT_NAME'"
  echo "✅ Repo names can include: letters, numbers, hyphens (-), underscores (_), or periods (.)"
  read -p "🔁 Enter a new valid PROJECT_NAME (or leave blank to cancel): " new_name

  if [[ -z "$new_name" ]]; then
    echo "❌ Cancelled by user."
    exit 1
  fi

  PROJECT_NAME="$new_name"
fi

# --- Check and rename project folder if using default starter path ---
if [[ "$PROJECT_PATH" == *"JUCE-Plugin-Starter" && -d "$PROJECT_PATH" ]]; then
  SUGGESTED_PATH="$(dirname "$PROJECT_PATH")/$PROJECT_NAME"
  if [[ -d "$SUGGESTED_PATH" ]]; then
    echo "❌ Folder already exists at: $SUGGESTED_PATH. Rename or delete it first."
    exit 1
  fi

  echo "📁 Renaming '$PROJECT_PATH' to '$SUGGESTED_PATH'..."
  mv "$PROJECT_PATH" "$SUGGESTED_PATH"
  PROJECT_PATH="$SUGGESTED_PATH"

  # --- Update PROJECT_PATH in .env ---
  echo "📝 Updating PROJECT_PATH in .env..."
  sed -i.bak "s|^PROJECT_PATH=.*|PROJECT_PATH=$PROJECT_PATH|" .env
  rm .env.bak
fi

# --- Final check that folder exists ---
if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "❌ Project folder not found at: $PROJECT_PATH"
  echo "📦 You may need to clone the starter: git clone https://github.com/danielraffel/JUCE-Plugin-Starter.git \"$PROJECT_PATH\""
  exit 1
fi

# --- Begin repo setup ---
cd "$PROJECT_PATH"

echo "🧹 Removing old git history..."
rm -rf .git

echo "📁 Initializing new git repo..."
git init
git add .
git commit -m "Initial commit for $PROJECT_NAME"

echo "🌐 Creating private GitHub repo..."
gh repo create "$GITHUB_USERNAME/$PROJECT_NAME" \
  --private \
  --source=. \
  --remote=origin \
  --push \
  --confirm

echo ""
echo "✅ Project successfully initialized and pushed to:"
echo "   https://github.com/$GITHUB_USERNAME/$PROJECT_NAME"
echo ""
