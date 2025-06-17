{ config, lib, pkgs, ... }:

{
  # 1Password CLI integration for secure secrets management
  # This provides a better security model than storing secrets in files
  
  home.packages = with pkgs; [
    _1password-cli
  ];

  # Create activation script to set up 1Password CLI
  home.activation.setupOnePassword = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # Check if 1Password CLI is configured
    if command -v op >/dev/null 2>&1; then
      echo "1Password CLI is available"
      
      # Create a script to load secrets from 1Password
      mkdir -p ${config.home.homeDirectory}/.config/op
      
      # Create a secrets loading script
      cat > ${config.home.homeDirectory}/.config/op/load-secrets.sh << 'EOF'
#!/bin/bash

# Function to safely load secrets from 1Password
load_secret() {
  local secret_ref="$1"
  local var_name="$2"
  local required="$3"
  
  if ! command -v op >/dev/null 2>&1; then
    if [ "$required" = "true" ]; then
      echo "Error: 1Password CLI not found but $var_name is required"
      return 1
    fi
    return 0
  fi
  
  # Check if signed in
  if ! op account list >/dev/null 2>&1; then
    echo "Please sign in to 1Password: op signin"
    if [ "$required" = "true" ]; then
      return 1
    fi
    return 0
  fi
  
  local secret_value
  secret_value=$(op read "$secret_ref" 2>/dev/null)
  
  if [ $? -eq 0 ] && [ -n "$secret_value" ]; then
    export "$var_name"="$secret_value"
    echo "✓ Loaded $var_name from 1Password"
  else
    if [ "$required" = "true" ]; then
      echo "✗ Failed to load required secret $var_name from $secret_ref"
      return 1
    else
      echo "⚠ Optional secret $var_name not found at $secret_ref"
    fi
  fi
}

# Load your secrets here - modify these examples for your actual secrets
# Format: load_secret "op://vault/item/field" "ENVIRONMENT_VARIABLE" "required|optional"

# Example secrets (uncomment and modify as needed):
# load_secret "op://Personal/OpenAI/credential" "OPENAI_API_KEY" "optional"
# load_secret "op://Personal/GitHub Token/credential" "GITHUB_TOKEN" "optional"
# load_secret "op://Personal/Anthropic/api_key" "ANTHROPIC_API_KEY" "optional"
# load_secret "op://Personal/AWS/access_key_id" "AWS_ACCESS_KEY_ID" "optional"
# load_secret "op://Personal/AWS/secret_access_key" "AWS_SECRET_ACCESS_KEY" "optional"

# For development databases
# load_secret "op://Development/Database/connection_string" "DATABASE_URL" "optional"

# For API services
# load_secret "op://Personal/Stripe/secret_key" "STRIPE_SECRET_KEY" "optional"
# load_secret "op://Personal/SendGrid/api_key" "SENDGRID_API_KEY" "optional"

echo "Secrets loading complete"
EOF

      chmod +x ${config.home.homeDirectory}/.config/op/load-secrets.sh
      
      # Create a simple alias script
      cat > ${config.home.homeDirectory}/.config/op/op-env.sh << 'EOF'
#!/bin/bash
# Quick script to run commands with 1Password secrets loaded
source ~/.config/op/load-secrets.sh && "$@"
EOF

      chmod +x ${config.home.homeDirectory}/.config/op/op-env.sh
      
    else
      echo "1Password CLI not found. Install it with: brew install 1password-cli"
    fi
  '';

  # Add shell aliases for easier 1Password integration
  programs.zsh.shellAliases = {
    # Load secrets into current shell
    "load-secrets" = "source ~/.config/op/load-secrets.sh";
    
    # Run command with secrets loaded
    "op-env" = "~/.config/op/op-env.sh";
    
    # Quick 1Password operations
    "op-signin" = "op signin";
    "op-list" = "op item list";
    "op-get" = "op item get";
  };

  programs.bash.shellAliases = {
    "load-secrets" = "source ~/.config/op/load-secrets.sh";
    "op-env" = "~/.config/op/op-env.sh";
    "op-signin" = "op signin";
    "op-list" = "op item list";
    "op-get" = "op item get";
  };

  # Environment variables that can be set from 1Password
  # These will be empty by default and populated when secrets are loaded
  home.sessionVariables = {
    # Development tools
    OPENAI_API_KEY = "";
    ANTHROPIC_API_KEY = "";
    GITHUB_TOKEN = "";
    
    # Cloud providers
    AWS_ACCESS_KEY_ID = "";
    AWS_SECRET_ACCESS_KEY = "";
    
    # Development services
    DATABASE_URL = "";
    STRIPE_SECRET_KEY = "";
    SENDGRID_API_KEY = "";
  };

  # Create a systemd user service to periodically refresh secrets (Linux only)
  # On macOS, you can use launchd or just load manually
  systemd.user.services.op-secrets-refresh = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Refresh 1Password secrets";
      After = [ "graphical-session.target" ];
    };
    
    Service = {
      Type = "oneshot";
      ExecStart = "${config.home.homeDirectory}/.config/op/load-secrets.sh";
      Environment = "PATH=${lib.makeBinPath (with pkgs; [ _1password-cli ])}";
    };
  };

  systemd.user.timers.op-secrets-refresh = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Refresh 1Password secrets timer";
      Requires = [ "op-secrets-refresh.service" ];
    };
    
    Timer = {
      OnCalendar = "hourly";
      Persistent = true;
    };
    
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}