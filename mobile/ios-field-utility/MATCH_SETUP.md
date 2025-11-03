# Fastlane Match Setup for TestFlight Automation

This guide will set up automated code signing for TestFlight uploads from GitHub Actions.

## Prerequisites

- Xcode installed on your Mac
- Apple Developer account with admin access
- Git installed
- Fastlane installed (`gem install fastlane` or `brew install fastlane`)

## One-Time Setup (Run on Your Mac)

### Step 1: Create a Private Git Repository for Certificates

1. Go to https://github.com/new
2. Create a **private** repository named `skyfeeder-certificates` (or any name you prefer)
3. **Important:** Must be private to protect your certificates
4. Initialize with a README
5. Copy the repository URL (e.g., `https://github.com/yourusername/skyfeeder-certificates.git`)

### Step 2: Initialize Match

Open Terminal and navigate to the project:

```bash
cd /path/to/Codex_Vs_Code/mobile/ios-field-utility
```

Run match init (if not already done):

```bash
fastlane match init
```

- Choose `git` as storage mode
- Enter your private repository URL when prompted

### Step 3: Generate Certificates and Profiles

```bash
# This will create and store App Store certificates/profiles
fastlane match appstore --app_identifier com.skyfeeder.field
```

You'll be prompted to:
1. **Enter a passphrase** - Choose a strong password and save it securely (you'll need this for GitHub secrets)
2. **Sign in with Apple ID** - Use your Apple Developer account
3. **Confirm team** - Select your development team

Match will:
- Create an App Store Distribution certificate (if needed)
- Create an App Store provisioning profile
- Encrypt everything with your passphrase
- Store it in your private git repository

### Step 4: Add GitHub Secrets

Go to your repository settings:
https://github.com/artiebot/Codex_Vs_Code/settings/secrets/actions

Add these secrets:

1. **MATCH_GIT_URL**
   - Value: Your certificates repository URL
   - Example: `https://github.com/yourusername/skyfeeder-certificates.git`

2. **MATCH_PASSWORD**
   - Value: The passphrase you chose in Step 3

3. **FASTLANE_USER** (optional but recommended)
   - Value: Your Apple ID email
   - Example: `you@example.com`

### Step 5: Configure Git Access for GitHub Actions

For the GitHub Actions runner to access your private certificates repo, you need to provide authentication.

**Option A: Personal Access Token (Recommended)**

1. Go to https://github.com/settings/tokens/new
2. Name: "Fastlane Match Access"
3. Expiration: Choose appropriate duration
4. Select scopes: `repo` (full control)
5. Generate token
6. Update `MATCH_GIT_URL` secret to include the token:
   ```
   https://<TOKEN>@github.com/yourusername/skyfeeder-certificates.git
   ```
   Replace `<TOKEN>` with your personal access token

**Option B: Deploy Key (More secure)**

1. Generate SSH key pair:
   ```bash
   ssh-keygen -t ed25519 -C "github-actions-match" -f ~/.ssh/match_deploy_key
   ```

2. Add public key to certificates repo:
   - Go to your certificates repo settings
   - Deploy keys → Add deploy key
   - Title: "GitHub Actions"
   - Key: Contents of `~/.ssh/match_deploy_key.pub`
   - ✅ Allow write access

3. Add private key as GitHub secret:
   - Name: `MATCH_GIT_PRIVATE_KEY`
   - Value: Contents of `~/.ssh/match_deploy_key`

4. Use SSH URL for `MATCH_GIT_URL`:
   ```
   git@github.com:yourusername/skyfeeder-certificates.git
   ```

### Step 6: Test Locally (Optional but Recommended)

Before pushing to CI, test that match works:

```bash
cd mobile/ios-field-utility
fastlane testflight_upload
```

This will:
- Fetch certificates from your match repo
- Build the app
- Upload to TestFlight

If this succeeds locally, it should work in CI.

### Step 7: Trigger GitHub Actions Workflow

Once all secrets are added:

1. Push any change to trigger the workflow, or
2. Manually trigger from GitHub Actions tab
3. Go to https://github.com/artiebot/Codex_Vs_Code/actions
4. Watch the "iOS TestFlight" workflow run

## Troubleshooting

### "No Accounts" Error
Make sure `FASTLANE_USER` secret is set with your Apple ID.

### "Authentication failed" for Match Repo
- Verify `MATCH_GIT_URL` includes the token or uses SSH with deploy key
- Check that the token/key has access to the certificates repository

### "Wrong password" for Match
- Verify `MATCH_PASSWORD` matches the passphrase you set during `fastlane match appstore`

### "No provisioning profiles found"
Run `fastlane match appstore` again to regenerate profiles.

## Maintenance

### Renewing Certificates (Annual)
Certificates expire after 1 year. To renew:

```bash
fastlane match nuke distribution
fastlane match appstore --app_identifier com.skyfeeder.field
```

### Adding New Team Members
They need to run:
```bash
fastlane match appstore --app_identifier com.skyfeeder.field --readonly
```

This installs the shared certificates on their machine.

## Security Notes

- **Never commit** the match passphrase or certificates to your main repository
- The certificates repo must remain **private**
- Rotate the `MATCH_PASSWORD` if compromised
- Use organization secrets if this is a team project
- Consider using a dedicated Apple ID for CI/CD
