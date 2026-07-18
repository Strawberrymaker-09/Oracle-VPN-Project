# Oracle Cloud VPN Project

Self-hosted VPN server on Oracle Cloud, built with Terraform (and soon Ansible). Started as "I wanna play Roblox on university wifi" and turned into an actual excuse to learn cloud infrastructure properly instead of just clicking around a console.

**Status: in progress.** Updating this as I go instead of writing it all at the end, so it's got the real mess in it, not just the polished final result.

## Why this exists

Short version: my university's wifi blocks games, so Roblox doesn't run. Longer version: most of the free VPNs avliable are also blocked hece I wanted to actually build my own, partly because it's more reliable/faster if it's mine, and partly because it turned into a genuinely good excuse to learn Terraform, cloud networking, and general "how does infrastructure actually work" stuff properly.

So yeah, the goal is real (get Roblox working on campus), but the point of doing it this way instead of the easy way is the learning.

## What this actually does

- Spins up a cloud server on Oracle's free tier using Terraform (so it's all defined in code, not clicked together by hand)
- Runs WireGuard on that server (fast, modern VPN protocol)
- My laptop connects to it, tunnels traffic through, university wifi just sees encrypted noise instead of "this is Roblox"

## Goals for the full project

- [x] Terraform config for networking + the actual VM
- [ ] Ansible to auto-configure the server (install WireGuard, lock down SSH, etc.)
- [ ] GitHub Actions so infra changes get reviewed (`terraform plan`) before anything actually applies
- [ ] Ansible Vault so no secrets/keys ever end up in this repo
- [ ] Basic monitoring dashboard (Netdata) so I can see bandwidth/uptime
- [ ] Actual threat model section, what this protects against, what it doesn't (spoiler: it's not protecting me from a nation-state, it's protecting me from campus IT blocking UDP traffic to Roblox)

## Progress log

### ✅ Networking + VM config written (Terraform)
`main.tf` sets up:
- A private network (VCN) for the server to live in
- Firewall rules, only SSH (22) and WireGuard (UDP 51820) allowed in, everything else blocked
- An Always Free ARM VM (1 OCPU / 6GB RAM), Ubuntu 24.04, SSH key login only (no passwords)

### ✅ Networking resources created successfully
VCN, gateway, route table, security list, subnet, all created fine on the first `terraform apply`.

### 🔄 Currently stuck on: Oracle doesn't have free VM capacity right now
Running into this on `terraform apply`:
```
Error: 500-InternalError, Out of host capacity.
```
Turns out this is a genuinely common thing with Oracle's free tier ARM VMs, they're popular because they're free, so regions run out of available capacity fairly often, especially Tokyo apparently. Not something I broke, just Oracle being out of stock basically.

**Fix:** wrote a small script (`retry-apply.sh`) that just keeps trying `terraform apply` every few minutes until Oracle actually has room, instead of me manually re-running it a hundred times:

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
Currently just... letting this run in the background for a day or two and seeing if capacity frees up.

## Tools used so far

Terraform, Oracle Cloud Infrastructure (OCI CLI), WSL/Ubuntu

## What's next

- Wait out the capacity thing (or fall back to the smaller x86 free shape if it takes forever)
- Move onto Ansible for actually configuring the server once it exists
- Keep this README updated as I go instead of dumping it all at the end

## Random lessons so far

- Oracle's card verification during signup can actually charge you a small real amount even when it says "verification failed" — happened to me, got it sorted through Oracle's support chat.
- The free tier isn't infinite — "Always Free" just means the resource tier is free forever, not that it's always available. Good reminder that free ≠ unlimited/instant.
