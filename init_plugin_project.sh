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

# --- Function to detect if we're in a JUCE project directory ---
is_juce_project_directory() {
  local dir="${1:-$(pwd)}"
  [[ -f "$dir/CMakeLists.txt" && -f "$dir/dependencies.sh" && -f "$dir/generate_and_open_xcode.sh" && -f "$dir/README.md" ]]
}

# --- Smart Path Detection ---
CURRENT_WORKING_DIR="$(pwd)"
# Expand tilde in PROJECT_PATH for comparison
EXPANDED_PROJECT_PATH="${PROJECT_PATH/#\~/$HOME}"

if is_juce_project_directory "$CURRENT_WORKING_DIR" && [[ "$CURRENT_WORKING_DIR" != "$EXPANDED_PROJECT_PATH" ]]; then
  echo ""
  echo "🔍 **PATH MISMATCH DETECTED**"
  echo ""
  echo "You appear to be working in a JUCE project directory:"
  echo "  Current location: $CURRENT_WORKING_DIR"
  echo ""
  echo "But your .env PROJECT_PATH is set to:"
  echo "  PROJECT_PATH: $EXPANDED_PROJECT_PATH"
  echo ""
  read -p "🔧 Do you want to update PROJECT_PATH to match your current location? (Y/N): " fix_path
  
  if [[ "$fix_path" =~ ^[Yy]$ ]]; then
    # Update PROJECT_PATH to current directory
    export PROJECT_PATH="$CURRENT_WORKING_DIR"
    
    # Update the .env file
    echo "📝 Updating PROJECT_PATH in .env to: $CURRENT_WORKING_DIR"
    sed -i.bak "s|^PROJECT_PATH=.*|PROJECT_PATH=$CURRENT_WORKING_DIR|" .env
    rm .env.bak
    
    echo "✅ PROJECT_PATH updated to match your current location!"
    echo ""
  else
    echo "ℹ️  Keeping PROJECT_PATH as: $PROJECT_PATH"
    echo ""
  fi
fi

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
    
    # Special handling for PROJECT_PATH - skip the "do you want to edit" question
    # and go straight to the rename suggestion
    if [[ "$var" == "PROJECT_PATH" ]]; then
      suggested_path="$(dirname "$current_val")/$PROJECT_NAME"
      
      # Only ask if the suggested path would be different
      if [[ "$current_val" != "$suggested_path" ]]; then
        echo ""
        echo "🔁 **RECOMMENDED**: Rename PROJECT_PATH to match PROJECT_NAME?"
        echo "   Current:   '$current_val'"
        echo "   Suggested: '$suggested_path'"
        echo ""
        read -p "Rename folder to match project name? (Y/N): " rename_confirm
        
        if [[ "$rename_confirm" =~ ^[Yy]$ ]]; then
          # Get current working directory
          current_working_dir="$(pwd)"
          
          # Check if we're currently inside the directory we want to rename
          if [[ "$current_working_dir" == "$current_val" ]]; then
            echo "📁 Moving up one level to perform the rename..."
            cd "$(dirname "$current_val")"
            
            # Check if target directory already exists
            if [[ -d "$suggested_path" ]]; then
              echo "❌ Target directory already exists: $suggested_path"
              echo "Please rename or remove the existing directory first."
              cd "$current_val"  # Go back to original directory
            else
              # Perform the rename
              mv "$current_val" "$suggested_path"
              if [[ $? -eq 0 ]]; then
                export PROJECT_PATH="$suggested_path"
                echo "✅ Successfully renamed to: $suggested_path"
                echo "📂 Moving into the renamed directory..."
                cd "$suggested_path"
              else
                echo "❌ Failed to rename directory."
                cd "$current_val"  # Go back to original directory
              fi
            fi
            
          # Check if the directory exists at the specified path
          elif [[ -d "$current_val" ]]; then
            # Check if target directory already exists
            if [[ -d "$suggested_path" ]]; then
              echo "❌ Target directory already exists: $suggested_path"
              echo "Please rename or remove the existing directory first."
            else
              mv "$current_val" "$suggested_path"
              if [[ $? -eq 0 ]]; then
                export PROJECT_PATH="$suggested_path"
                echo "✅ Successfully renamed to: $suggested_path"
              else
                echo "❌ Failed to rename directory."
              fi
            fi
            
          # Check if we're in a directory that matches the basename but wrong path
          elif [[ "$(basename "$current_working_dir")" == "$(basename "$current_val")" ]]; then
            echo "📍 Found matching directory name at current location: $current_working_dir"
            new_path="$(dirname "$current_working_dir")/$PROJECT_NAME"
            
            # Check if target directory already exists
            if [[ -d "$new_path" ]]; then
              echo "❌ Target directory already exists: $new_path"
              echo "Please rename or remove the existing directory first."
            else
              cd "$(dirname "$current_working_dir")"
              mv "$(basename "$current_working_dir")" "$PROJECT_NAME"
              if [[ $? -eq 0 ]]; then
                export PROJECT_PATH="$new_path"
                echo "✅ Successfully renamed to: $new_path"
                echo "📂 Moving into the renamed directory..."
                cd "$new_path"
              else
                echo "❌ Failed to rename directory."
                cd "$current_working_dir"
              fi
            fi
            
          else
            echo "⚠️  Source directory doesn't exist at: $current_val"
            echo "Setting PROJECT_PATH to: $suggested_path (will be used for cloning later)"
            export PROJECT_PATH="$suggested_path"
          fi
        else
          echo "ℹ️  Keeping current PROJECT_PATH: $current_val"
        fi
      else
        echo "ℹ️  PROJECT_PATH already matches PROJECT_NAME"
      fi
      
    # Standard handling for other variables
    else
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

# --- Final check that folder exists or create it ---
if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "📁 Project folder not found at: $PROJECT_PATH"
  
  # Check if this looks like it should be cloned from the starter template
  parent_dir="$(dirname "$PROJECT_PATH")"
  project_name="$(basename "$PROJECT_PATH")"
  
  # Offer to clone the starter template to the specified location
  read -p "📦 Do you want to clone the JUCE-Plugin-Starter template to '$PROJECT_PATH'? (Y/N): " clone_confirm
  if [[ "$clone_confirm" =~ ^[Yy]$ ]]; then
    # Ensure parent directory exists
    mkdir -p "$parent_dir"
    
    # Clone to a temporary name first, then rename
    temp_clone_path="$parent_dir/JUCE-Plugin-Starter-temp-$"
    git clone https://github.com/danielraffel/JUCE-Plugin-Starter.git "$temp_clone_path"
    if [[ $? -eq 0 ]]; then
      mv "$temp_clone_path" "$PROJECT_PATH"
      echo "✅ Successfully cloned and set up project at: $PROJECT_PATH"
    else
      echo "❌ Failed to clone repository."
      exit 1
    fi
  else
    echo "❌ Cannot proceed without project directory."
    exit 1
  fi
fi

# --- Begin repo setup with confirmation ---
cd "$PROJECT_PATH"

echo ""
echo "🚀 **READY TO CREATE YOUR PLUGIN PROJECT**"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📁 Project directory: $PROJECT_PATH"
echo "🐙 GitHub repository: https://github.com/$GITHUB_USERNAME/$PROJECT_NAME"
echo ""
echo "This will:"
echo "• Remove existing git history"
echo "• Initialize a new git repository"
echo "• Create your first commit"
echo "• Create a GitHub repository"
echo "• Push your code to GitHub"
echo ""

# Ask for repository visibility
read -p "🔒 Make this a private repository? (Y/N, default: Y): " private_repo
if [[ "$private_repo" =~ ^[Nn]$ ]]; then
  REPO_VISIBILITY="public"
  VISIBILITY_FLAG="--public"
  echo "📖 Creating PUBLIC repository"
else
  REPO_VISIBILITY="private"
  VISIBILITY_FLAG="--private"
  echo "🔒 Creating PRIVATE repository"
fi

echo ""
read -p "✅ Proceed with project creation? (Y/N): " final_confirm
if [[ ! "$final_confirm" =~ ^[Yy]$ ]]; then
  echo "❌ Cancelled by user."
  exit 0
fi

echo ""
echo "🧹 Removing old git history..."
rm -rf .git

echo "📁 Initializing new git repo..."
git init
git add .
git commit -m "Initial commit for $PROJECT_NAME"

echo "🌐 Creating $REPO_VISIBILITY GitHub repo..."
gh repo create "$GITHUB_USERNAME/$PROJECT_NAME" \
  $VISIBILITY_FLAG \
  --source=. \
  --remote=origin \
  --push \
  --confirm

echo ""
echo "🎉 **SUCCESS!**"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Project successfully initialized and pushed to:"
echo "   https://github.com/$GITHUB_USERNAME/$PROJECT_NAME"
echo ""
echo "🚀 You're ready to start working on your new plugin!"
echo "   Working directory: $PROJECT_PATH"
echo ""
echo "Next steps:"
echo "• Run ./generate_and_open_xcode.sh to open in Xcode"
echo "• Edit source files to build your plugin"
echo "• Commit changes: git add . && git commit -m \"Your changes\""
echo "• Push updates: git push"
echo ""
