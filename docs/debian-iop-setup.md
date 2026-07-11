# Running Compliance on Debian with IoP (Insights on Prem)

This guide documents every step needed to run compliance-backend with a Debian 12 host in an IoP (Insights on Premises) development environment built with [Forklift](https://github.com/theforeman/forklift). The entire IoP pipeline — insights-client, Foreman proxy, ingress, puptoo, HBI, compliance-backend — assumes RHEL by default. Each assumption is documented here with the patch required to support Debian.

**Environment:** Forklift dev VMs on libvirt (Fedora host), IoP server on CentOS 9 Stream, Debian 12 client VM.

**Status:** Host registration and upload work end-to-end. Compliance scan upload is not yet integrated.

---

## Table of Contents

1. [VM Setup](#1-vm-setup)
2. [Debian Client: Package Installation](#2-debian-client-package-installation)
3. [insights-client Installation on Debian](#3-insights-client-installation-on-debian)
4. [Register Debian Host in Foreman](#4-register-debian-host-in-foreman)
5. [IoP Server Patches](#5-iop-server-patches)
   - [5a. foreman_rh_cloud: ClientAuthentication](#5a-foreman_rh_cloud-clientauthentication)
   - [5b. foreman_rh_cloud: MachineTelemetriesController](#5b-foreman_rh_cloud-machinetelemetriescontroller)
   - [5c. foreman_rh_cloud: CloudRequestForwarder](#5c-foreman_rh_cloud-cloudrequestforwarder)
   - [5d. HBI System Profile Schema](#5d-hbi-system-profile-schema)
   - [5e. Puptoo OS Detection](#5e-puptoo-os-detection)
   - [5f. Applying Patches (Bootsnap & Container Restarts)](#5f-applying-patches)
6. [SSG Content for Debian](#6-ssg-content-for-debian)
7. [Running a Compliance Scan](#7-running-a-compliance-scan)
8. [Current Status & Known Issues](#8-current-status--known-issues)
9. [Architecture Reference](#9-architecture-reference)

---

## 1. VM Setup

### Forklift Box Definition

Add to `vagrant/boxes.d/99-local.yaml` in your Forklift directory:

```yaml
debian12-compliance-client:
  box_name: generic-x64/debian12
  memory: 2048
  cpus: 2
```

Bring up the VM:

```bash
cd ~/devel/forklift
vagrant up debian12-compliance-client
```

### Network / DNS

The Debian VM needs to resolve the IoP server hostname. Add to `/etc/hosts` on the Debian VM:

```bash
# On the Debian VM (vagrant ssh debian12-compliance-client)
echo "192.168.124.121 centos9-katello-devel-iop.fedora.example.com" | sudo tee -a /etc/hosts
```

Replace `192.168.124.121` with your IoP server's actual IP (check with `vagrant ssh centos9-katello-devel-iop -c 'hostname -I'`).

---

## 2. Debian Client: Package Installation

```bash
# On the Debian VM
sudo apt-get update
sudo apt-get install -y python3-pip openscap-scanner openscap-common libopenscap25
```

---

## 3. insights-client Installation on Debian

### Why this is needed

Debian has no `subscription-manager` or `insights-client` RPM package. We install insights-client from source and insights-core (the data collection engine) via pip.

### Install insights-core

```bash
sudo pip3 install --break-system-packages insights-core==3.7.7
```

### Clone and install insights-client

```bash
cd /tmp
git clone https://github.com/RedHatInsights/insights-client.git
cd insights-client
sudo pip3 install --break-system-packages -e .
sudo cp src/insights-client /usr/bin/insights-client
sudo chmod 755 /usr/bin/insights-client
```

### Configure insights-client

Create `/etc/insights-client/insights-client.conf`:

```bash
sudo mkdir -p /etc/insights-client
sudo tee /etc/insights-client/insights-client.conf << 'EOF'
[insights-client]
loglevel=DEBUG
auto_config=False
authmethod=BASIC
username=admin
password=changeme
cert_verify=False
base_url=centos9-katello-devel-iop.fedora.example.com:443/redhat_access/r/insights
legacy_upload=False
EOF
```

**Critical settings explained:**

| Setting | Value | Why |
|---------|-------|-----|
| `legacy_upload=False` | Required | The legacy upload path requires `subscription-manager` (RHSM cert auth). The platform API path (`/platform/ingress/v1/upload`) uses HTTP basic auth instead. |
| `authmethod=BASIC` | Required | No RHSM certificate exists on Debian. Use Foreman admin credentials. |
| `auto_config=False` | Required | Auto-config tries to read RHSM config which doesn't exist. |
| `base_url` | Foreman proxy path | All requests go through Foreman's `MachineTelemetriesController` which proxies to IoP ingress. The path `/redhat_access/r/insights` is the Foreman route prefix. |
| `cert_verify=False` | Dev only | Foreman's dev SSL certificate is self-signed. |

---

## 4. Register Debian Host in Foreman

### Why manual registration is needed

Foreman's normal host registration flow uses `subscription-manager` to register via Katello, which creates a subscription facet. Debian has no `subscription-manager`, so we create the host directly via the Foreman API.

```bash
# From the IoP server or any machine with curl access to Foreman
FOREMAN_URL="https://centos9-katello-devel-iop.fedora.example.com"

curl -sk -X POST "$FOREMAN_URL/api/v2/hosts" \
  -u admin:changeme \
  -H "Content-Type: application/json" \
  -d '{
    "host": {
      "name": "debian12-compliance-client.fedora.example.com",
      "organization_id": 1,
      "location_id": 2,
      "ip": "192.168.124.2",
      "managed": false,
      "build": false
    }
  }'
```

Adjust `organization_id` and `location_id` to match your Foreman setup. The FQDN must match the Debian VM's hostname.

### Set the insights client parameter

The host needs `enable_insights_client = true` to pass the telemetry check. This is usually set by a global default, but verify:

```bash
curl -sk "$FOREMAN_URL/api/v2/hosts/debian12-compliance-client.fedora.example.com" \
  -u admin:changeme | python3 -m json.tool | grep -A2 enable_insights
```

---

## 5. IoP Server Patches

These patches modify components on the IoP server VM (`centos9-katello-devel-iop`). Each patch addresses a specific RHEL-only assumption in the pipeline.

### 5a. foreman_rh_cloud: ClientAuthentication

**File:** `foreman_rh_cloud/app/controllers/concerns/insights_cloud/client_authentication.rb`

**Problem:** The `authorize` method calls `client_authorized?` which does `subscribed_host_by_uuid(User.current.uuid)`. This joins `Host` with `katello_subscription_facets` — a table that only has entries for hosts registered via `subscription-manager`. Debian hosts have no subscription facet, so authentication always fails with a 500 error (`NoMethodError: undefined method 'organization' for nil:NilClass`).

**Patch:** Add a `find_host_for_iop` fallback that looks up the host by FQDN from the upload metadata or by IP address when in IoP mode.

```ruby
# Replace the entire file content with:
module InsightsCloud
  module ClientAuthentication
    extend ActiveSupport::Concern

    include ::Katello::Authentication::ClientAuthentication

    def authorize
      client_authorized? || (super && find_host_for_iop)
    end

    def client_authorized?
      authenticate_client && valid_machine_user?
    end

    def valid_machine_user?
      subscribed_host_by_uuid(User.current.uuid).present?
    end

    def subscribed_host_by_uuid(uuid)
      @host = Host.unscoped.joins(:subscription_facet).where(:katello_subscription_facets => { :uuid => uuid }).first
    end

    private

    def find_host_for_iop
      return true if @host
      return true unless ForemanRhCloud.with_iop_smart_proxy?

      # In IoP mode with BASIC auth (no cert), try to find host by FQDN from upload metadata
      if request.params[:metadata].present?
        begin
          metadata = JSON.parse(request.params[:metadata].read)
          request.params[:metadata].rewind
          fqdn = metadata['fqdn']
          @host = Host.unscoped.find_by(name: fqdn) if fqdn
        rescue JSON::ParserError, NoMethodError
        end
      end

      # Fallback: look up by IP address
      @host ||= Host.unscoped.find_by(ip: request.remote_ip)

      @host.present? || true
    end
  end
end
```

### 5b. foreman_rh_cloud: MachineTelemetriesController

**File:** `foreman_rh_cloud/app/controllers/insights_cloud/api/machine_telemetries_controller.rb`

**Problem:** `update_host_facet` (after_action for uploads in IoP mode) calls `@host.subscription_facet.uuid` which crashes with `NoMethodError` when the host has no subscription facet.

**Patch:** Make `update_host_facet` nil-safe:

```ruby
# Find the update_host_facet method and replace with:
def update_host_facet
  return unless upload_success?
  return if @host&.insights
  return unless @host&.subscription_facet || @host

  insights_facet = @host.build_insights(uuid: @host.subscription_facet&.uuid || @host.name)
  insights_facet.save
end
```

The key change is `@host.subscription_facet&.uuid || @host.name` — if there's no subscription facet (Debian), use the hostname as the insights facet UUID.

### 5c. foreman_rh_cloud: CloudRequestForwarder

**File:** `foreman_rh_cloud/app/services/foreman_rh_cloud/cloud_request_forwarder.rb`

**Problem:** `prepare_forwarded_header` originally calls `host.subscription_facet.uuid` directly, which crashes for non-subscription hosts. The `Forwarded` header value becomes the `owner_id` in HBI's system profile (via the gateway's `identity.pl` → puptoo). HBI validates `owner_id` as a UUID pattern — if the FQDN is used as fallback, HBI rejects the entire system profile.

**Patch:**

```ruby
# Find prepare_forwarded_header and replace with:
def prepare_forwarded_header(host)
  "for=\"_#{host.subscription_facet&.uuid || SecureRandom.uuid}\""
end
```

**How the Forwarded header flows through the pipeline:**

1. Foreman sends `Forwarded: for="_<UUID>"` to the IoP gateway
2. The gateway's `identity.pl` (Perl script in nginx) extracts the UUID and puts it in `identity.system.cn`
3. The gateway base64-encodes the identity and sets the `x-rh-identity` header
4. Ingress passes `x-rh-identity` to Kafka as `b64_identity`
5. Puptoo decodes `b64_identity`, extracts `identity.system.cn`, and sets it as `owner_id` in the system profile
6. HBI validates `owner_id` against the UUID regex pattern `[0-9a-f]{8}-[0-9a-f]{4}-...`

### 5d. HBI System Profile Schema

**Problem:** HBI validates the `operating_system.name` field against a hardcoded enum: `[RHEL, CentOS, CentOS Linux]`. When puptoo sends `Debian` as the OS name, HBI rejects the entire system profile with a `ValidationException`.

**Files to patch:**

1. Extract the schema files from the HBI container:

```bash
# On the IoP server
sudo podman cp iop-core-host-inventory:/opt/app-root/src/swagger/system_profile.spec.yaml /tmp/system_profile.spec.yaml
sudo podman cp iop-core-host-inventory:/opt/app-root/src/swagger/openapi.json /tmp/openapi.json
sudo chmod 666 /tmp/system_profile.spec.yaml /tmp/openapi.json
```

2. Edit `/tmp/system_profile.spec.yaml` — find the `operating_system` → `name` → `enum` field (around line 371):

```yaml
# Before:
            enum: [RHEL, CentOS, CentOS Linux]
            example: "RHEL, CentOS, CentOS Linux"

# After:
            enum: [RHEL, CentOS, CentOS Linux, Debian, Ubuntu]
            example: "RHEL, CentOS, CentOS Linux, Debian, Ubuntu"
```

3. Edit `/tmp/openapi.json` — find the same enum in the JSON schema and add `"Debian"`, `"Ubuntu"`.

4. Add volume mounts to the HBI container quadlet files:

```bash
# /etc/containers/systemd/iop-core-host-inventory.container — add after Network line:
Volume = /tmp/system_profile.spec.yaml:/opt/app-root/src/swagger/system_profile.spec.yaml:ro,z
Volume = /tmp/openapi.json:/opt/app-root/src/swagger/openapi.json:ro,z

# /etc/containers/systemd/iop-core-host-inventory-api.container — same lines:
Volume = /tmp/system_profile.spec.yaml:/opt/app-root/src/swagger/system_profile.spec.yaml:ro,z
Volume = /tmp/openapi.json:/opt/app-root/src/swagger/openapi.json:ro,z
```

5. Restart HBI containers:

```bash
sudo systemctl daemon-reload
sudo systemctl restart iop-core-host-inventory iop-core-host-inventory-api
```

### 5e. Puptoo OS Detection

**Problem:** Puptoo extracts OS information from the insights archive. The OS detection code (in `process/profile.py`) only handles RHEL and CentOS Linux — both require `/etc/redhat-release` to exist. Debian has no `/etc/redhat-release`, so the `operating_system` field is never populated in the system profile.

**Patch:** Add Debian/Ubuntu detection using the `/etc/os-release` parser (which insights-core does collect from Debian).

1. Extract the file:

```bash
sudo podman cp iop-core-puptoo:/app-root/src/puptoo/process/profile.py /tmp/puptoo_profile.py
sudo chmod 666 /tmp/puptoo_profile.py
```

2. Find the RHEL/CentOS OS detection block (around line 507-532). It looks like:

```python
    if (redhat_release_parser or redhat_release_combiner) and os_release_combiner:
        try:
            ...
            if os_release_combiner.is_rhel and redhat_release_combiner:
                profile["operating_system"] = {
                    "major": redhat_release_combiner.major,
                    "minor": redhat_release_combiner.minor,
                    "name": "RHEL"
                }
            elif "CentOS Linux" in os_release_combiner.name and redhat_release_parser:
                ...
        except Exception as e:
            catch_error("redhat_release", e)
            raise
```

3. **After** the `raise` line (end of the RHEL/CentOS block), **before** the `profile["rhsm"]` line, insert:

```python
    # Debian/Ubuntu: no /etc/redhat-release, use /etc/os-release directly
    if "operating_system" not in profile and os_release_parser:
        try:
            os_id = os_release_parser.get("ID", "").lower()
            version_id = os_release_parser.get("VERSION_ID", "0")
            os_name_map = {"debian": "Debian", "ubuntu": "Ubuntu"}
            if os_id in os_name_map:
                parts = version_id.split(".")
                major = int(parts[0]) if parts[0].isdigit() else 0
                minor = int(parts[1]) if len(parts) > 1 and parts[1].isdigit() else 0
                profile["os_release"] = version_id
                profile["operating_system"] = {
                    "major": major,
                    "minor": minor,
                    "name": os_name_map[os_id]
                }
                if profile.get("system_update_method") is None:
                    profile["system_update_method"] = "apt"
        except Exception as e:
            catch_error("os_release_debian", e)
```

4. Volume-mount into the puptoo container:

```bash
# /etc/containers/systemd/iop-core-puptoo.container — add after Network line:
Volume = /tmp/puptoo_profile.py:/app-root/src/puptoo/process/profile.py:ro,z
```

5. Restart puptoo:

```bash
sudo systemctl daemon-reload
sudo systemctl restart iop-core-puptoo
```

**Note:** This patch is applied but not yet fully verified. The `os_release_parser` relies on insights-core collecting `/etc/os-release` from the Debian system. If insights-core's Spec for `os_release` only triggers on RHEL-like systems, the parser might not be available. In that case, insights-core would need a patch to its collection specs.

### 5f. Applying Patches

After modifying any Ruby file in `foreman_rh_cloud/`, Foreman's bootsnap cache must be cleared:

```bash
# On the IoP server
rm -rf /home/vagrant/foreman/tmp/cache/bootsnap*

# Restart Foreman (dev mode uses foreman-start, not systemd)
cd /home/vagrant/foreman
pkill -f 'puma.*6\.6'
sleep 2
nohup bundle exec foreman start > /tmp/foreman.log 2>&1 &
```

Wait ~30 seconds for Foreman to start, then verify:

```bash
curl -sk https://localhost/api/v2/status | head -1
# Should return JSON starting with "{"
```

---

## 6. SSG Content for Debian

SCAP Security Guide (SSG) provides security profiles for Debian 12.

### Download SSG with Debian content

```bash
# On the Debian VM
cd /tmp
wget https://github.com/ComplianceAsCode/content/releases/download/v0.1.81/scap-security-guide-0.1.81.zip
unzip scap-security-guide-0.1.81.zip -d ssg
ls ssg/scap-security-guide-0.1.81/ssg-debian12-ds.xml
```

### Available Debian 12 profiles

```bash
oscap info /tmp/ssg/scap-security-guide-0.1.81/ssg-debian12-ds.xml
```

The benchmark reference ID is: `xccdf_org.ssgproject.content_benchmark_Debian-12`

### compliance-backend changes needed (not yet implemented)

The following files in compliance-backend are hardcoded for RHEL and need changes to support Debian:

| File | Issue |
|------|-------|
| `app/models/supported_ssg.rb` | `OS_NAME = 'RHEL'` hardcoded constant |
| `app/models/v2/security_guide.rb:51` | RHEL regex for extracting OS major version from ref_id |
| `app/services/datastream_downloader.rb` | Assumes RHEL RPM package naming for SSG content |
| `config/supported_ssg.default.yaml` | Only lists RHEL SSG entries |
| `app/consumers/inventory_events_consumer.rb:50-52` | Requires `insights_id` for host lookup |

---

## 7. Running a Compliance Scan

### Manual scan on Debian

```bash
# On the Debian VM
sudo oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_anssi_np_nt28_minimal \
  --results /tmp/scan-results.xml \
  --report /tmp/scan-report.html \
  /tmp/ssg/scap-security-guide-0.1.81/ssg-debian12-ds.xml
```

### Upload results to compliance-backend

**Not yet implemented.** The `insights-client --compliance` flow requires:

1. compliance-backend to recognize Debian profiles and create policies
2. A way to download the Debian datastream to the client
3. The scan results upload path through Foreman to compliance-backend

---

## 8. Current Status & Known Issues

### What works

- Debian VM created and networked via Forklift
- insights-client installed from source on Debian
- insights-client uploads archives to Foreman proxy successfully (HTTP 202)
- Foreman proxy forwards to IoP ingress
- Puptoo processes the archive and sends host facts to HBI
- Host is created in HBI with a valid UUID `owner_id`
- OpenSCAP installed and can run Debian 12 datastream scans locally

### What's pending

| Item | Status | Notes |
|------|--------|-------|
| Puptoo OS detection for Debian | Patch applied, unverified | `operating_system` still shows as `None` in HBI. May need insights-core collection spec fix. |
| compliance-backend Debian support | Not started | Requires code changes in 5+ files (see section 6) |
| Compliance policy creation for Debian | Blocked | Requires compliance-backend changes |
| Scan result upload | Blocked | Requires compliance-backend changes |
| Duplicate hosts in HBI | Under investigation | Each upload may create a new host instead of updating |

### Known quirks

1. **RHSM facts warning:** `Could not write to /etc/rhsm/facts/insights-client.facts` — harmless, `/etc/rhsm/` doesn't exist on Debian.
2. **`os_kernel_release` missing:** HBI shows `None` for kernel release. The kernel version (`6.1.0`) is present but the release string is parsed differently on Debian.
3. **Zero MAC address warning:** HBI logs `Zero MAC address reported by: puptoo` — the loopback interface's `00:00:00:00:00:00` MAC is included.

---

## 9. Architecture Reference

### Upload Flow

```
Debian VM                          IoP Server (CentOS 9)
---------                          ----------------------

insights-client
  |
  | POST /redhat_access/r/insights/platform/ingress/v1/upload
  | (BASIC auth: admin/changeme)
  v
Apache (port 443)
  |
  v
Foreman (puma, port 3000)
  MachineTelemetriesController#forward_request
    1. set_admin_user
    2. ClientAuthentication#authorize
       -> find_host_for_iop (reads FQDN from metadata)     <-- PATCHED
    3. ensure_org (from @host.organization)
    4. ensure_branch_id (org.label in IoP mode)
    5. ensure_telemetry_enabled_for_consumer
    6. CloudRequestForwarder#forward_request
       -> prepare_forwarded_header: for="_<UUID>"           <-- PATCHED
       -> POST to gateway (port 24443)
  |
  v
IoP Gateway (nginx, port 24443)
  identity.pl:
    Forwarded header -> extract UUID -> build identity JSON
    -> base64 encode -> set x-rh-identity header
  |
  v
Ingress (Go, port 8080)
  -> Reads x-rh-identity, stores archive, sends Kafka message
  -> Topic: platform.upload.advisor
  |
  v
Puptoo (Python)
  -> Consumes from platform.upload.advisor
  -> Extracts system facts from archive using insights-core
  -> Sets operating_system from /etc/os-release                <-- PATCHED
  -> Sets owner_id from b64_identity.system.cn
  -> Produces to platform.inventory.host-ingress
  |
  v
HBI (Host-Based Inventory, Python)
  -> Consumes from platform.inventory.host-ingress
  -> Validates system_profile against schema                   <-- PATCHED (enum)
  -> Creates/updates host in inventory_db
  -> Produces to platform.inventory.events
```

### Key Differences: RHEL vs Debian

| Aspect | RHEL | Debian |
|--------|------|--------|
| Host registration | subscription-manager → Katello | Manual API call to Foreman |
| Client auth | RHSM certificate | HTTP Basic (admin/password) |
| Upload path | `legacy_upload=True` (RHSM) | `legacy_upload=False` (platform API) |
| OS detection | `/etc/redhat-release` | `/etc/os-release` |
| Host identification | subscription_facet UUID | FQDN from metadata |
| Forwarded header | subscription_facet.uuid | SecureRandom.uuid |
| Package manager | yum/dnf | apt |
| SSG content | RPM packages | Downloaded ZIP from GitHub releases |

### Files Modified on IoP Server

| File | Component | Change |
|------|-----------|--------|
| `foreman_rh_cloud/.../client_authentication.rb` | Foreman | Added `find_host_for_iop` |
| `foreman_rh_cloud/.../machine_telemetries_controller.rb` | Foreman | Nil-safe `update_host_facet` |
| `foreman_rh_cloud/.../cloud_request_forwarder.rb` | Foreman | UUID fallback in `prepare_forwarded_header` |
| `/tmp/system_profile.spec.yaml` | HBI | Added Debian/Ubuntu to OS name enum |
| `/tmp/openapi.json` | HBI | Same enum change |
| `/tmp/puptoo_profile.py` | Puptoo | Added Debian/Ubuntu OS detection |
| `/etc/containers/systemd/iop-core-host-inventory.container` | HBI | Volume mounts for schema |
| `/etc/containers/systemd/iop-core-host-inventory-api.container` | HBI | Volume mounts for schema |
| `/etc/containers/systemd/iop-core-puptoo.container` | Puptoo | Volume mount for profile.py |
