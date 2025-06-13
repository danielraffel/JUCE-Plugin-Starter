#!/bin/bash
set -e

# === UV Environment Setup Script ===
# This script sets up a Python virtual environment using UV
# for post-installation dependency management

echo "🐍 Setting up UV Python environment..."

# Get the actual user (not root during installation)
ACTUAL_USER=$(stat -f "%Su" /dev/console)
USER_HOME=$(eval echo ~$ACTUAL_USER)
PROJECT_NAME="${1:-[PROJECT_NAME]}"
UV_ENV_DIR="${USER_HOME}/.local/share/${PROJECT_NAME}/uv_env"

echo "📁 Creating UV environment at: $UV_ENV_DIR"

# Check if UV is installed
if ! command -v uv &> /dev/null; then
    echo "📦 Installing UV package manager..."
    # Install UV for the actual user
    sudo -u "$ACTUAL_USER" curl -LsSf https://astral.sh/uv/install.sh | sh
    
    # Add UV to PATH for this session
    export PATH="${USER_HOME}/.cargo/bin:$PATH"
else
    echo "✅ UV already installed"
fi

# Create project directory structure
sudo -u "$ACTUAL_USER" mkdir -p "$(dirname "$UV_ENV_DIR")"

# Create UV environment
echo "🔧 Creating UV virtual environment..."
sudo -u "$ACTUAL_USER" uv venv "$UV_ENV_DIR"

# Create requirements.txt if it doesn't exist
REQUIREMENTS_FILE="${USER_HOME}/.local/share/${PROJECT_NAME}/requirements.txt"
if [ ! -f "$REQUIREMENTS_FILE" ]; then
    echo "📝 Creating default requirements.txt..."
    sudo -u "$ACTUAL_USER" cat > "$REQUIREMENTS_FILE" << EOF
# Python dependencies for ${PROJECT_NAME}
# Add your required packages here
# Example:
# numpy>=1.21.0
# scipy>=1.7.0
# matplotlib>=3.4.0
EOF
fi

# Install dependencies if requirements.txt has content
if [ -s "$REQUIREMENTS_FILE" ]; then
    echo "📦 Installing Python dependencies..."
    sudo -u "$ACTUAL_USER" "$UV_ENV_DIR/bin/pip" install -r "$REQUIREMENTS_FILE"
else
    echo "ℹ️  No dependencies to install (requirements.txt is empty)"
fi

# Create activation script
ACTIVATION_SCRIPT="${USER_HOME}/.local/share/${PROJECT_NAME}/activate_env.sh"
echo "📜 Creating environment activation script..."
sudo -u "$ACTUAL_USER" cat > "$ACTIVATION_SCRIPT" << EOF
#!/bin/bash
# Activation script for ${PROJECT_NAME} UV environment
source "$UV_ENV_DIR/bin/activate"
echo "🐍 ${PROJECT_NAME} Python environment activated"
echo "📁 Environment: $UV_ENV_DIR"
EOF

sudo -u "$ACTUAL_USER" chmod +x "$ACTIVATION_SCRIPT"

echo "✅ UV environment setup complete!"
echo "📁 Environment location: $UV_ENV_DIR"
echo "🔧 Activation script: $ACTIVATION_SCRIPT"
echo "📝 Requirements file: $REQUIREMENTS_FILE"
echo ""
echo "To use the environment:"
echo "  source $ACTIVATION_SCRIPT"
echo ""

exit 0