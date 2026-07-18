# Oracle Cloud VPN Project

Self-hosted VPN server on Oracle Cloud, built with Terraform and Ansible. Started as "I wanna play Roblox on university wifi" and turned into an actual excuse to learn cloud infrastructure properly instead of just clicking around a console.

**Status: in progress.** Updating this as I go instead of writing it all at the end, so it's got the real mess in it, not just the polished final result.

## Why this exists

Short version: my university's wifi blocks games, so Roblox doesn't run. Longer version: instead of just using a random free VPN app, I wanted to actually build my own, partly because it's more reliable and faster if it's mine, and partly because it turned into a genuinely good excuse to learn Terraform, Ansible, cloud networking, and general "how does infrastructure actually work" stuff properly.

So yeah, the goal is real (get Roblox working on campus), but the point of doing it this way instead of the easy way is the learning.

## What this actually does

- Spins up a cloud server on Oracle's free tier using Terraform (so it's all defined in code, not clicked together by hand)
- Uses Ansible to automatically configure that server: installs WireGuard, generates keys, writes the VPN config, starts the service
- Runs WireGuard on that server (fast, modern VPN protocol)
- My laptop connects to it, tunnels traffic through, university wifi just sees encrypted noise instead of "this is Roblox"

## Goals for the full project

- [x] Terraform config for networking and the actual VM
- [ ] Ansible to auto-configure the server (install WireGuard done, SSH lockdown and fail2ban still to go)
- [ ] GitHub Actions so infra changes get reviewed (`terraform plan`) before anything actually applies
- [ ] Ansible Vault so no secrets or keys ever end up in this repo
- [ ] Basic monitoring dashboard (Netdata) so I can see bandwidth and uptime
- [ ] Actual threat model section: what this protects against, what it doesn't (spoiler: it's not protecting me from a nation state, it's protecting me from campus IT blocking UDP traffic to Roblox)

## Progress log

### Networking and VM config written (Terraform)
`main.tf` sets up:
- A private network (VCN) for the server to live in
- Firewall rules: only SSH (22) and WireGuard (UDP 51820) allowed in, everything else blocked
- A VM running Ubuntu 24.04, SSH key login only (no passwords)

### Networking resources created successfully
VCN, gateway, route table, security list, subnet all created fine on the first `terraform apply`.

### Ran into Oracle capacity issues on the free ARM shape
Running into this on `terraform apply`:
Turns out this is a genuinely common thing with Oracle's free tier ARM VMs. They're popular because they're free, so regions run out of available capacity fairly often, especially Tokyo apparently. Not something I broke, just Oracle being out of stock basically.

Wrote a small script (`retry-apply.sh`) that keeps trying `terraform apply` every few minutes until Oracle has room, instead of me manually re-running it a hundred times:

```bash
#!/bin/bash
ATTEMPT=1
while true; do
  echo "Attempt #$ATTEMPT at $(date)"
  terraform apply -auto-approve
  if [ $? -eq 0 ]; then
    echo "Success! VM created on attempt #$ATTEMPT."
    break
  fi
  echo "Failed (likely capacity issue). Waiting 3 minutes before retrying..."
  ATTEMPT=$((ATTEMPT + 1))
  sleep 180
done
```

Eventually just switched to the less popular x86 `VM.Standard.E2.1.Micro` Always Free shape instead of fighting ARM capacity. `terraform apply` went through clean on the first try after that. Lesson: "Always Free" means the resource tier is free forever, not that it's always available.

### VM created and reachable over SSH
Confirmed with `terraform apply` (1 added, 0 changed, 0 destroyed) and then SSH'd in directly to check.

### First Ansible playbook: installing and configuring WireGuard
Wrote `wireguard.yml` to automate the server setup instead of doing it by hand. It installs WireGuard, turns on IP forwarding, generates a keypair, writes the WireGuard config file, and starts the service.

Hit a real bug along the way: my first version of the playbook generated the private key and saved it to a file in two separate steps. On a second run, the "generate" step correctly skipped itself since the key file already existed, but the "save" step didn't know that, and it overwrote the real key with a leftover status message instead. Ended up corrupting the key file. Fixed it by combining key generation and saving into a single atomic shell command, so there's no in-between step that can go stale.

Deleted the corrupted key, reran the playbook, and this time it went through clean: real key generated, config written, WireGuard service started and enabled on boot. Verified with `systemctl status wg-quick@wg0` and `wg show`, both looking correct.

## Tools used so far

Terraform, Ansible, Oracle Cloud Infrastructure (OCI CLI), WireGuard, WSL/Ubuntu

## What's next

- Finish the rest of Phase 2: SSH hardening and fail2ban
- Move to Phase 3: set up my laptop as a WireGuard client and actually test Roblox
- Regenerate the WireGuard private key before this goes any further, since an earlier version got exposed during debugging
- Keep this README updated as I go instead of dumping it all at the end

## Random lessons so far

- Oracle's card verification during signup can actually charge you a small real amount even when it says "verification failed." Happened to me, got it sorted through Oracle's support chat.
- The free tier isn't infinite. "Always Free" just means the resource tier is free forever, not that it's always available.
- Automating a setup step doesn't automatically make it safe. A bug in an Ansible playbook can silently corrupt data just as easily as doing it wrong by hand. Worth actually verifying what a task does, not just that it says "changed" or "ok."
