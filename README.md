# Enterprise Distributed Linux Backup Orchestrator with AWS S3 Integration

A production-grade, fully automated distributed backup pipeline built using standard Site Reliability Engineering (SRE) and Linux administration practices. This project handles the programmatic extraction of data from multiple remote worker nodes, processes localized compression, enforces military-grade AES-256 bit symmetric cryptography via GnuPG, and safely streams payloads directly to an immutable AWS S3 infrastructure vault.

---

## 📂 Repository Structure

* `iam-policies/`: Contains the AWS IAM JSON policies granting minimal write access.
* `scripts/`: Contains the core orchestrator bash script (`backup_orchestrator.sh`).
* `systemd/`: Systemd service and timer files to handle automation.
* `screenshots/`: Visual guides of the setup.	

## 🏗️ Architecture Blueprint
* **ControlNode:** The core management server orchestrating the backup execution lifecycle, handling encryption keys, and driving AWS cloud egress.
* **Worker Nodes (Distributed):** Target compute nodes (`worker1`, `worker2`, `worker3`) hosting production configurations (`/etc`), application servers (`/var/www`), and containers (`/var/lib/docker/volumes`).
* **Cloud Infrastructure:** Amazon S3 Backup Vault locked behind strict identity-based security policies.

---

## 🛠️ Step-by-Step Implementation Lifecycle

### Phase 1: AWS CLI Environment Provisioning
The ControlNode requires programmatic interaction with the AWS API. The environment was initialized by installing the AWS CLI v2 package and declaring unique workspace configurations.

```bash
1. Download and extract the standard AWS CLI package
curl "[https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip](https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip)" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

2. Initialize credentials and region alignment 
aws configure

### Phase 2: Least-Privilege IAM Infrastructure Design

**To eliminate the threat vector of a compromised backup agent deleting existing archives, a strict, write-only JSON identity policy was drafted and mapped to the IAM user.**

Declared in iam-policies/s3-backup-policy.json folder

# Provision the highly secure remote storage bucket
aws s3 mb s3://ie-homelab-backup-vault-2026 --region eu-west-1

### Phase 3: Distributed Authentication & Privileged Access

1. SSH Keypair Mapping: Programmatic access was established from ControlNode root user accounts down to standard operator profiles (jsamuel) on the distributed workers:

ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
ssh-copy-id -o StrictHostKeyChecking=accept-new jsamuel@192.X.X.X
ssh-copy-id -o StrictHostKeyChecking=accept-new jsamuel@192.X.X.X
ssh-copy-id -o StrictHostKeyChecking=accept-new jsamuel@192.X.X.X

2. Privileged Escalation Scoping: To safely read sensitive files (like /etc/shadow) without logging in directly as root, explicit passwordless sudo rule limitations were configured on the Worker Nodes:

echo "jsamuel ALL=(ALL) NOPASSWD: /usr/bin/rsync" | sudo tee /etc/sudoers.d/jsamuel-rsync


### Phase 4: Shell Pipeline Implementation (scripts/backup_orchestrator.sh)

Declared in the scripts/backup_orchestrator.sh

### Phase 5: Autonomous Service Automation (Systemd Timers)

To abstract scheduling away from legacy, brittle cron mechanisms, the execution lifecycle was offloaded to native Systemd files, providing high-precision scheduling and centralized engine telemetry within journalctl.

1. Systemd Unit Descriptor (systemd/homelab-backup.service):

Declared in systemd/homelab-backup.service folder

2. Systemd Schedule Engine (systemd/homelab-backup.timer):

Declared in systemd/homelab-backup.timer folder

3. Activating and locking in infrastructure execution loops
sudo systemctl daemon-reload
sudo systemctl enable --now homelab-backup.timer

### Phase 6:  SELinux Security Hardening
To permanently authorize the automation engine without compromising system security, policy definitions were remapped to allow script translation

1. Add a permanent SELinux file context rule mapping your folder to 'bin_t'
sudo semanage fcontext -a -t bin_t "/homelab-s3-backup/scripts(/.*)?"

2. 2. Relabel the directory and everything inside it based on the new rule
sudo restorecon -R -v /homelab-s3-backup/scripts	

3. Log Errors for SeLinux: 
[root@ControlNode scripts]# ausearch -m AVC -ts recent | grep backup_orchestrator.sh
type=AVC msg=audit(1783958310.618:498): avc:  denied  { execute } for  pid=11499 comm="(rator.sh)" name="backup_orchestrator.sh" dev="dm-0" ino=41963399 scontext=system_u:system_r:init_t:s0 tcontext=unconfined_u:object_r:default_t:s0 tclass=file permissive=0
type=AVC msg=audit(1783958435.080:560): avc:  denied  { execute } for  pid=12323 comm="(rator.sh)" name="backup_orchestrator.sh" dev="dm-0" ino=41963399 scontext=system_u:system_r:init_t:s0 tcontext=unconfined_u:object_r:default_t:s0 tclass=file permissive=0
type=AVC msg=audit(1783958574.236:622): avc:  denied  { execute } for  pid=13291 comm="(rator.sh)" name="backup_orchestrator.sh" dev="dm-0" ino=41963393 scontext=system_u:system_r:init_t:s0 tcontext=unconfined_u:object_r:default_t:s0 tclass=file permissive=0
[root@ControlNode scripts]# 


📈 SRE & Engineering Competencies Demonstrated

Cloud Data Management: AWS CLI V2 API mapping, storage abstraction via AWS S3 bucket structures, IAM infrastructure engineering.

Linux Infrastructure Automation: Custom systems automation using Bash, POSIX Signals tracking (trap), rsync system synchronization, remote passwordless security topologies, access control lists (sudoers.d).

Systems Hardening & Data Encryption: Application of strict cryptographic controls (AES-256 symmetric cipher blocks via GnuPG Engine) coupled with AWS Least-Privilege Identity-Based security profiles.
