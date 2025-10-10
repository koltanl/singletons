#!/usr/bin/env python3
"""
bigFileAmountCompare.py - Compare two file locations and generate directory-level summary

Usage:
    bigFileAmountCompare.py <source> <destination> [options]
    
Examples:
    # Compare local drive to remote NAS
    bigFileAmountCompare.py /mnt/local owner@home.arpa:/mnt/nas
    
    # Use custom output location
    bigFileAmountCompare.py /path/a /path/b -o /tmp/my_report.txt
    
    # Change default output location permanently
    bigFileAmountCompare.py /path/a /path/b --set-default /home/user/reports/
"""

import argparse
import subprocess
import sys
import tempfile
from pathlib import Path
from collections import defaultdict
import os

# Default output location
DEFAULT_OUTPUT = Path.home() / "drive_comparison_report.txt"
CONFIG_FILE = Path.home() / ".config" / "bigFileAmountCompare" / "config"


def load_default_output():
    """Load custom default output location from config file"""
    if CONFIG_FILE.exists():
        try:
            return Path(CONFIG_FILE.read_text().strip())
        except Exception:
            pass
    return DEFAULT_OUTPUT


def save_default_output(path):
    """Save custom default output location to config file"""
    CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
    CONFIG_FILE.write_text(str(path))
    print(f"Default output location set to: {path}")


def run_rsync_comparison(source, destination):
    """Run rsync dry-run to compare two locations"""
    print(f"Comparing locations...")
    print(f"  Source:      {source}")
    print(f"  Destination: {destination}")
    print()
    
    # Create temporary file for rsync output
    with tempfile.NamedTemporaryFile(mode='w+', delete=False, suffix='.txt') as tmp:
        tmp_path = tmp.name
    
    try:
        # Build rsync command
        # -a: archive mode
        # -v: verbose
        # -n: dry-run (no actual changes)
        # --progress: show progress
        cmd = ['rsync', '-avn', '--progress', source, destination]
        
        # If destination is remote and starts with sshpass, handle it
        if destination.startswith('owner@') or '@' in destination:
            # Prepend sshpass if available
            if subprocess.run(['which', 'sshpass'], capture_output=True).returncode == 0:
                cmd = ['sshpass', '-p', '2312'] + cmd
        
        # Run rsync and capture output
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding='utf-8',
            errors='ignore'
        )
        
        # Save output to temp file
        with open(tmp_path, 'w', encoding='utf-8') as f:
            f.write(result.stdout)
        
        print(f"Rsync comparison complete (exit code: {result.returncode})")
        return tmp_path
        
    except Exception as e:
        print(f"Error running rsync: {e}", file=sys.stderr)
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)
        sys.exit(1)


def analyze_rsync_output(file_path):
    """Parse rsync output and group files by parent directory"""
    dir_stats = defaultdict(lambda: {"files": 0, "dirs": 0, "items": []})
    
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            line = line.strip()
            
            # Skip rsync status lines and empty lines
            if not line or line.startswith('rsync:') or line.startswith('sent') or \
               line.startswith('total size') or line.startswith('rsync error') or \
               'bytes/sec' in line or line.startswith('receiving') or \
               line.startswith('sending'):
                continue
            
            # Check if it's a directory (ends with /)
            is_dir = line.endswith('/')
            
            # Get the path
            path = Path(line.rstrip('/'))
            
            # Get parent directory (1-2 levels deep for grouping)
            parts = path.parts
            if len(parts) >= 2:
                parent_key = f"{parts[0]}/{parts[1]}"
            elif len(parts) == 1:
                parent_key = parts[0]
            else:
                continue
            
            # Update statistics
            if is_dir:
                dir_stats[parent_key]["dirs"] += 1
            else:
                dir_stats[parent_key]["files"] += 1
            
            # Store sample items (limit to 5 per directory)
            if len(dir_stats[parent_key]["items"]) < 5:
                dir_stats[parent_key]["items"].append(line)
    
    return dir_stats


def format_report(dir_stats, source, destination):
    """Format the analysis into a readable report"""
    lines = []
    lines.append("=" * 80)
    lines.append("FILE LOCATION COMPARISON REPORT")
    lines.append("=" * 80)
    lines.append(f"Source:      {source}")
    lines.append(f"Destination: {destination}")
    lines.append("")
    lines.append("UNIQUE CONTENT IN SOURCE (Not in destination)")
    lines.append("=" * 80)
    lines.append("")
    
    # Sort by parent directory name
    for parent_dir in sorted(dir_stats.keys()):
        stats = dir_stats[parent_dir]
        total_items = stats["files"] + stats["dirs"]
        
        lines.append(f"Directory: {parent_dir}/")
        lines.append(f"  - Files: {stats['files']}")
        lines.append(f"  - Subdirectories: {stats['dirs']}")
        lines.append(f"  - Total items: {total_items}")
        
        if stats["items"]:
            lines.append(f"  - Sample items:")
            for item in stats["items"][:3]:
                lines.append(f"      {item}")
        lines.append("")
    
    # Summary statistics
    lines.append("=" * 80)
    lines.append("SUMMARY")
    lines.append("=" * 80)
    total_files = sum(s["files"] for s in dir_stats.values())
    total_dirs = sum(s["dirs"] for s in dir_stats.values())
    lines.append(f"Total unique parent directories: {len(dir_stats)}")
    lines.append(f"Total unique files: {total_files}")
    lines.append(f"Total unique subdirectories: {total_dirs}")
    lines.append(f"Grand total: {total_files + total_dirs} items")
    lines.append("")
    
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Compare two file locations and generate a directory-level summary of unique content.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Compare local drive to NAS
  %(prog)s /run/media/user/drive owner@home.arpa:/mnt/nas
  
  # Use custom output location for this run
  %(prog)s /path/a /path/b -o /tmp/report.txt
  
  # Set new default output location
  %(prog)s /path/a /path/b --set-default ~/reports/
  
  # Just set default without running comparison
  %(prog)s --set-default ~/reports/ --no-compare
        """
    )
    
    parser.add_argument(
        'source',
        nargs='?',
        help='Source location (local path or remote path)'
    )
    
    parser.add_argument(
        'destination',
        nargs='?',
        help='Destination location to compare against (local or remote)'
    )
    
    parser.add_argument(
        '-o', '--output',
        type=Path,
        help=f'Output file location for this run (default: {load_default_output()})'
    )
    
    parser.add_argument(
        '--set-default',
        type=Path,
        metavar='PATH',
        help='Set new default output location for future runs'
    )
    
    parser.add_argument(
        '--no-compare',
        action='store_true',
        help='Skip comparison (useful with --set-default)'
    )
    
    parser.add_argument(
        '-q', '--quiet',
        action='store_true',
        help='Suppress report display (still saves to file)'
    )
    
    args = parser.parse_args()
    
    # Handle --set-default
    if args.set_default:
        save_default_output(args.set_default)
        if args.no_compare:
            sys.exit(0)
    
    # Validate required arguments for comparison
    if not args.no_compare:
        if not args.source or not args.destination:
            parser.error("source and destination are required unless --no-compare is used")
    
    # Determine output location
    output_path = args.output or load_default_output()
    
    # Ensure source path ends with / for proper rsync behavior
    source = args.source
    if not source.endswith('/') and not '@' in source:
        source = source + '/'
    
    destination = args.destination
    if not destination.endswith('/'):
        destination = destination + '/'
    
    try:
        # Step 1: Run rsync comparison
        rsync_output = run_rsync_comparison(source, destination)
        
        # Step 2: Analyze the output
        print("Analyzing differences...")
        dir_stats = analyze_rsync_output(rsync_output)
        
        # Step 3: Generate report
        print("Generating report...")
        report = format_report(dir_stats, args.source, args.destination)
        
        # Step 4: Save to file
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(report)
        print(f"\n✓ Report saved to: {output_path}")
        
        # Step 5: Display report (unless quiet)
        if not args.quiet:
            print("\n" + "=" * 80)
            print(report)
        
        # Cleanup temp file
        if os.path.exists(rsync_output):
            os.unlink(rsync_output)
        
    except KeyboardInterrupt:
        print("\n\nOperation cancelled by user")
        sys.exit(130)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

