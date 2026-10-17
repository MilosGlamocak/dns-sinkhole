# dns-sinkhole

A one-command local DNS sinkhole for Fedora. It blocks ads, trackers and other unwanted domains for **every application on your machine** (browsers, apps, CLI tools) without browser extensions.

It runs [dnsmasq](https://thekelleys.org.uk/dnsmasq/doc.html) as a local blocking DNS server and keeps `systemd-resolved` as the system resolver, so VPNs and split DNS keep working.

```
app -> systemd-resolved (127.0.0.53) -> dnsmasq (127.0.0.1) -+-> blocked?  answer 0.0.0.0 / ::
                                                             +-> allowed?  ask upstream (1.1.1.1, 8.8.8.8)
```

## Quick start

```bash
git clone https://github.com/<your-user>/dns-sinkhole.git
cd dns-sinkhole
less dns-sinkhole.sh lib/*.sh     # it runs as root, read it first
./dns-sinkhole.sh --dry-run install   # shows what would change, changes nothing
./dns-sinkhole.sh install
./dns-sinkhole.sh status
```

Then, in your browser, turn **DNS over HTTPS off** (Firefox: Settings > Privacy & Security > DNS over HTTPS; Chrome: Settings > Privacy and security > Security > Use secure DNS). Browsers with their own DoH bypass the system resolver and therefore the blocklist.

## Commands

| Command | What it does |
|---|---|
| `install` | Sets everything up. Safe to re-run. Rolls back automatically if verification fails. |
| `update` | Re-downloads the blocklist and reloads dnsmasq. A daily systemd timer does this for you. |
| `uninstall` | Restores the previous configuration. |
| `status` | Shows service state, number of blocked domains and a self-test. |

Options: `--dry-run` (print actions only), `--log-queries` (log every DNS query to the journal, off by default for privacy).

`--dry-run` is a preview: it runs the real environment checks (Fedora, services running, port 53 free) and prints every file and command it would touch, but changes nothing. It also skips the download and the verification steps, so it shows the plan, not proof that the install will work.

Environment variables:

| Variable | Default |
|---|---|
| `BLOCKLIST_URL` | StevenBlack unified hosts |
| `UPSTREAM_DNS` | `1.1.1.1 8.8.8.8` |

Example: `UPSTREAM_DNS="9.9.9.9 149.112.112.112" ./dns-sinkhole.sh install`

## What it changes on your system

| Path | Purpose |
|---|---|
| `/etc/dnsmasq.d/sinkhole.conf` | dnsmasq configuration |
| `/etc/hosts.d/stevenblack` | Converted blocklist |
| `/etc/hosts.d/00-dns-sinkhole-selftest` | Self-test entry used for verification |
| `/etc/systemd/resolved.conf.d/90-local-dns.conf` | Points systemd-resolved at dnsmasq |
| `/etc/systemd/system/dnsmasq.service.d/90-dns-sinkhole-restart.conf` | Restart dnsmasq if it crashes |
| `/etc/systemd/system/dns-sinkhole-update.{service,timer}` | Daily blocklist refresh |
| `/usr/local/sbin/dns-sinkhole` | Installed copy of the script (used by the timer) |
| `/usr/local/lib/dns-sinkhole/` | Installed copy of the `lib/` modules |
| `/var/lib/dns-sinkhole/` | Saved original settings for uninstall |
| NetworkManager profiles | `ipv4/ipv6.ignore-auto-dns` set to `yes` on saved Wi-Fi and Ethernet profiles (originals are saved and restored on uninstall) |

Files it creates carry a `Managed by dns-sinkhole` marker. Uninstall only removes files with that marker. If a file with the same name existed before, it is backed up and restored.

## Project layout

```
dns-sinkhole.sh        entry point: argument parsing, sudo, dispatch
lib/
  config.sh            paths, constants, defaults (BLOCKLIST_URL, UPSTREAM_DNS)
  common.sh            logging, dry-run helpers, managed-file/backup handling
  render.sh            contents of generated config files, blocklist conversion
  preflight.sh         environment checks before anything is changed
  network.sh           NetworkManager profile snapshot/protect/restore
  blocklist.sh         download, convert, reload dnsmasq
  verify.sh            self-test and end-to-end DNS checks
  cmd-install.sh       `install` + automatic rollback on error
  cmd-update.sh        `update`
  cmd-uninstall.sh     `uninstall`
  cmd-status.sh        `status`
  usage.sh             help text
```

Each module only defines functions; `dns-sinkhole.sh` sources them in a fixed order. To change what a generated file looks like, edit `render.sh`; to change a path, edit `config.sh`.

## Why these design choices

- **Why keep systemd-resolved?** Disabling it breaks VPN and split-DNS integration and fights NetworkManager over `/etc/resolv.conf`. Here resolved only forwards to dnsmasq.
- **Why disable DHCP-provided DNS?** Your router advertises its own DNS server. If resolved keeps it as a candidate, some queries can go there and skip the blocklist.
- **Why two lines per domain?** Applications ask for IPv4 (`A`) and IPv6 (`AAAA`) separately. With only `0.0.0.0 domain`, dnsmasq forwards the `AAAA` query upstream and the real IPv6 address comes back. The script writes both `0.0.0.0 domain` and `:: domain`.
- **Why `no-resolv`?** `/etc/resolv.conf` points at the local resolver. Without it dnsmasq could use itself as upstream and loop.
- **Why verify and roll back?** A broken DNS setup means no internet. After changing anything the script resolves a test name and a real domain. If either fails, it restores the previous state.

## Adding your own rules

Create any file in `/etc/hosts.d/` with **both** lines per domain, then reload:

```bash
printf '0.0.0.0 example.com\n:: example.com\n' | sudo tee /etc/hosts.d/mine
sudo systemctl reload dnsmasq
```

A hosts entry blocks only the exact name. To block a domain and all its subdomains, add this to a file in `/etc/dnsmasq.d/` instead:

```
address=/example.com/0.0.0.0
address=/example.com/::
```

## Limitations

- **Fedora only** for now. The script exits on other distributions.
- **New networks:** profiles are protected at install time. A Wi-Fi network you save later still uses DHCP-provided DNS until you run  
  `nmcli connection modify "<name>" ipv4.ignore-auto-dns yes ipv6.ignore-auto-dns yes && nmcli connection up "<name>"`  
  or re-run `install`.
- **If dnsmasq is down, DNS is down.** systemd restarts it automatically after a crash.
- **Applications with their own encrypted DNS** (browser DoH, some apps) bypass the sinkhole.
- Upstream queries are sent unencrypted to your chosen upstream, so your ISP can see them. Encrypted upstream (DNS over TLS) is on the roadmap.
- Query logging (`--log-queries`) records every domain you visit. Use it for debugging.

## Uninstall

```bash
./dns-sinkhole.sh uninstall
```

The `dnsmasq` and `bind-utils` packages stay installed.

## Roadmap

- DNS over TLS to the upstream
- More distributions
- Multiple blocklists

## Tested on

Fedora 44 (KDE) <!-- confirm after the from-scratch test on the laptop -->

## License

[MIT-0](LICENSE) (MIT No Attribution): use it, change it, sell it, no attribution required.
