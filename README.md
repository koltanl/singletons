# Singletons

A curated collection of standalone utility scripts that solve complex, niche problems. Each script in this repository is a self-contained tool designed for system administrators and power users who need specialized functionality that standard utilities don't provide.

## Philosophy

This repository exists for **heavy hitters** - scripts that:

- **Solve specific, complex problems** that arise in real-world system administration
- **Stand alone** with minimal dependencies beyond standard system tools
- **Provide niche utility** that isn't readily available in package managers
- **Target technical competence** - these are professional tools, not beginner utilities
- **Are worth finding again** when you need them months or years later

Think of this as a personal arsenal of specialized instruments. If a script solves a problem significant enough that you never want to rewrite it from scratch again, it belongs here.

## Scripts

### bigFileAmountCompare.py

**Purpose:** Compare two file locations (local or remote) and generate comprehensive directory-level reports of differences.

**Why it exists:** Standard diff tools don't scale to large directory trees, and rsync's output is verbose and difficult to parse. This script bridges the gap by running rsync dry-runs and aggregating results into actionable summaries grouped by parent directory.

**Use cases:**
- Verifying backup completeness across drives or NAS systems
- Identifying unique content before decommissioning storage
- Auditing data migration between local and remote locations
- Comparing mounted drives to network shares

**Key features:**
- Handles both local paths and SSH remote locations
- Configurable default output locations
- Directory-level aggregation with sample items
- Summary statistics for quick assessment
- Built-in support for authenticated SSH connections

**Technical requirements:** Python 3, rsync, optional sshpass for automated remote authentication

**Usage:**
```bash
# Compare local drive to remote NAS
./bigFileAmountCompare.py /mnt/local owner@home.arpa:/mnt/nas

# Custom output location
./bigFileAmountCompare.py /path/a /path/b -o /tmp/report.txt

# Set persistent default output location
./bigFileAmountCompare.py --set-default ~/reports/ --no-compare
```

---

## Contributing

If you're not the repository owner: These are personal utility scripts. Feel free to fork for your own use, but this isn't a collaborative project.

If you are the repository owner: Only add scripts that meet the "heavy hitter" criteria. One-liners and trivial wrappers belong elsewhere.

## License

GPL-3.0 - See LICENSE file for details.

