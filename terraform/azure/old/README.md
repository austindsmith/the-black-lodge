# generate-azure

Terraform for the Entra ID app registration that backs the Generate EDFacts
deployment.

## What it creates

- App registration (`AzureADMyOrg` audience, single-tenant)
- Web redirect URI pointing at `https://<ingress_host>/signin-oidc`
- `Administrator` and `Reviewer` app roles (required by Generate's identity model)
- A service principal for the app (needed for role assignment)
- A client secret (long-lived; rotate manually when needed)
- Optional pre-assignment of the Administrator role to a user you own

## Prerequisites

```
az login
az account show   # confirm you're in the right tenant
```

The `azuread` provider authenticates from your active `az` session automatically.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars   # edit ingress_host and optionally admin_user_id
terraform init
terraform apply
```

To find your user object ID for `admin_user_id`:

```bash
az ad user show --id <your@email.com> --query id -o tsv
```

## Outputs → HelmRelease

After apply, pull the values into your HelmRelease:

```bash
terraform output tenant_id    # azureAd.tenantId
terraform output client_id    # azureAd.clientId
terraform output domain       # azureAd.domain  (e.g. yourtenant.onmicrosoft.com)
terraform output -raw client_secret   # store as GENERATE_AAD_CLIENT_SECRET in Infisical
```

Your helmrelease.yaml values block ends up as:

```yaml
azureAd:
  domain: yourtenant.onmicrosoft.com
  tenantId: <tenant_id output>
  clientId: <client_id output>
  clientSecret:
    enabled: true
```

The actual secret value goes into Infisical under `GENERATE_AAD_CLIENT_SECRET`.

## After first deploy

Log in to https://<ingress_host> with your Microsoft account. The first login
will fail with "no roles assigned" until you assign yourself the Administrator
role in the Entra portal (or set `admin_user_id` before apply).

To assign roles in the portal:
Enterprise Applications → Generate → Users and groups → Add user/group

## Domain note

`azureAd.domain` must match the verified domain on your tenant. For a personal
account free tenant it will be `<something>.onmicrosoft.com`. That is fine.
