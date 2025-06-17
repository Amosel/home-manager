# 1Password Secrets Management Setup

This configuration provides secure API key management using 1Password CLI instead of storing secrets in files.

## Why 1Password CLI > SOPS/SSH Keys?

- **Better Security**: Secrets never touch disk unencrypted
- **Biometric Auth**: Touch ID/Face ID authentication
- **Centralized**: All secrets in one secure vault
- **Cross-Device**: Works across all your devices
- **Audit Trail**: 1Password logs all secret access
- **Team Sharing**: Easy to share secrets with team members

## Initial Setup

### 1. Install 1Password CLI

```bash
# Install via Homebrew (recommended)
brew install 1password-cli

# Or download from https://1password.com/downloads/command-line/
```

### 2. Sign in to 1Password

```bash
# Sign in to your 1Password account
op signin

# Verify you're signed in
op account list
```

### 3. Apply Home Manager Configuration

```bash
home-manager switch
```

## Adding Secrets to 1Password

### Via 1Password App (Recommended)

1. Open 1Password app
2. Create new item or edit existing
3. Add your API keys as "password" or "text" fields
4. Note the vault name, item name, and field name

### Via CLI

```bash
# Create a new item with an API key
op item create --category "API Credential" \
  --title "OpenAI" \
  --vault "Personal" \
  credential="your-api-key-here"

# Add field to existing item
op item edit "OpenAI" --vault "Personal" \
  api_key="your-api-key-here"
```

## Configuring Secrets in Home Manager

Edit `secrets.nix` and uncomment/modify the secrets you need:

```bash
# Example secret references:
load_secret "op://Personal/OpenAI/credential" "OPENAI_API_KEY" "optional"
load_secret "op://Personal/GitHub Token/credential" "GITHUB_TOKEN" "optional"
```

The format is: `op://VAULT_NAME/ITEM_NAME/FIELD_NAME`

## Using Secrets

### Option 1: Load into Current Shell

```bash
# Load all configured secrets into current shell
load-secrets
```

### Option 2: Run Command with Secrets

```bash
# Run a single command with secrets loaded
op-env npm run dev
op-env python script.py
op-env curl -H "Authorization: Bearer $GITHUB_TOKEN" api.github.com
```

### Option 3: Manual Loading

```bash
# Get a specific secret
op read "op://Personal/OpenAI/credential"

# Use in a command
export OPENAI_API_KEY=$(op read "op://Personal/OpenAI/credential")
```

## Common Secret Reference Patterns

```bash
# API Keys
op://Personal/OpenAI/credential
op://Personal/Anthropic/api_key
op://Personal/GitHub Token/credential

# Database connections
op://Development/Database/connection_string
op://Development/Redis/url

# AWS credentials
op://Personal/AWS/access_key_id
op://Personal/AWS/secret_access_key

# Service credentials
op://Personal/Stripe/secret_key
op://Personal/SendGrid/api_key
```

## Security Best Practices

### 1. Use Descriptive Names
- ✅ `GitHub Token - Personal Projects`
- ❌ `token123`

### 2. Organize with Vaults
- `Personal` - Your personal API keys
- `Work` - Work-related credentials
- `Development` - Dev environment secrets

### 3. Set Appropriate Access
- Use 1Password's sharing features for team access
- Regularly audit who has access to what

### 4. Rotate Keys Regularly
- Set up key rotation reminders in 1Password
- Update both 1Password and any hardcoded references

## Troubleshooting

### "op: command not found"
```bash
# Install 1Password CLI
brew install 1password-cli
```

### "not signed in to 1Password"
```bash
# Sign in
op signin
```

### Secret not found
```bash
# List all items to find correct path
op item list

# Get item details
op item get "Item Name" --vault "Vault Name"
```

### Permissions error
```bash
# Check account access
op account list

# Re-authenticate
op signin --force
```

## Migration from Other Secret Managers

### From SOPS
1. Decrypt existing secrets: `sops -d secrets.yaml`
2. Add each secret to 1Password
3. Update references in `secrets.nix`
4. Remove SOPS files

### From .env files
1. Review `.env` files for secrets
2. Add each to 1Password
3. Add to `secrets.nix` 
4. Remove or gitignore `.env` files

## Advanced Usage

### Environment-Specific Secrets
```bash
# Development
load_secret "op://Development/API/key" "API_KEY" "optional"

# Production  
load_secret "op://Production/API/key" "API_KEY" "required"
```

### Conditional Loading
```bash
# Only load if in specific directory
if [[ "$PWD" == *"/work-project"* ]]; then
  load_secret "op://Work/Project API/key" "PROJECT_API_KEY" "required"
fi
```

### Integration with Development Tools
```bash
# Load secrets before running development commands
alias dev="load-secrets && npm run dev"
alias test="load-secrets && npm test"
alias deploy="load-secrets && npm run deploy"
```