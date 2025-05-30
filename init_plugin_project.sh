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

# --- Interactive Edit Prompt ---
echo ""
echo "📄 Current .env values:"
echo "  PROJECT_NAME=$PROJECT_NAME"
echo "  GITHUB_USERNAME=$GITHUB_USERNAME"
echo "  PROJECT_PATH=$PROJECT_PATH"
echo ""

read -p "✏️  Do you want to edit any of these values? (Y/N): " edit_env
if [[ "$edit_env" =~ ^[Yy]$ ]]; then
  for var in PROJECT_NAME GITHUB_USERNAME PROJECT_PATH; do
    current_val="${!var}"
    echo ""
    read -p "🔁 Do you want to edit $var? (Current: '$current_val') (Y/N): " edit_field
    if [[ "$edit_field" =~ ^[Yy]$ ]]; then
      while true; do
        read -p "✏️  Enter new value for $var: " new_val
        echo "You entered: '$new_val'"
        read -p "✅ Is this correct? (Y/N): " confirm_val
        if [[ "$confirm_val" =~ ^[Yy]$ ]]; then
          export $var="$new_val"
          break
        fi
      done
    fi
  done

  # --- Validate PROJECT_NAME format ---
  validate_project_name() {
    local name="$1"
    [[ "$name" =~ ^[a-zA-Z0-9._-]+$ ]]
  }

  while ! validate_project_name "$PROJECT_NAME"; do
    echo "❌ Invalid PROJECT_NAME: '$PROJECT_NAME'"
    echo "✅ Must use only letters, numbers, hyphens (-), underscores (_), or periods (.)"
    read -p "🔁 Enter a new valid PROJECT_NAME (or leave blank to cancel): " new_name
    [[ -z "$new_name" ]] && echo "❌ Cancelled by user." && exit 1
    PROJECT_NAME="$new_name"
  done

  # --- Update .env safely ---
  echo "📝 Updating .env with new values..."
  sed -i.bak "s|^PROJECT_NAME=.*|PROJECT_NAME=$PROJECT_NAME|" .env
  sed -i.bak "s|^GITHUB_USERNAME=.*|GITHUB_USERNAME=$GITHUB_USERNAME|" .env
  sed -i.bak "s|^PROJECT_PATH=.*|PROJECT_PATH=$PROJECT_PATH|" .env
  rm .env.bak
fi

# --- Validate all required vars ---
if [[ -z "$PROJECT_NAME" || -z "$GITHUB_USERNAME" || -z "$PROJECT_PATH" ]]; then
  echo "❌ Missing one of: PROJECT_NAME, GITHUB_USERNAME, PROJECT_PATH"
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

  # Update PROJECT_PATH in .env again
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
