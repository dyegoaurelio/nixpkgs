#!/usr/bin/env python3
import argparse
import re
import sys
from pathlib import Path

def remove_plugin_block(pom_path: str, plugin_name: str):
    text = Path(pom_path).read_text(encoding="utf-8")

    # Match exactly one <plugin>...</plugin> block that contains the artifactId
    # [\s\S] instead of . so we match newlines; tempered with a lazy quantifier
    pattern = re.compile(
        rf"<plugin\b[\s\S]*?</plugin>",
        re.DOTALL
    )

    removed = 0
    def replacer(match):
        nonlocal removed
        block = match.group(0)
        if re.search(rf"<artifactId>\s*{re.escape(plugin_name)}\s*</artifactId>", block):
            removed += 1
            return ""  # remove this block
        return block  # keep others

    new_text = pattern.sub(replacer, text)

    if removed > 0:
        Path(pom_path).write_text(new_text, encoding="utf-8")
        print(f"Removed {removed} plugin block(s) with artifactId '{plugin_name}' from {pom_path}")
    else:
        print(f"No plugin with artifactId '{plugin_name}' found in {pom_path}")


def main():
    parser = argparse.ArgumentParser(description="Remove a plugin block from pom.xml without altering other formatting.")
    parser.add_argument("pom_path", help="Path to pom.xml")
    parser.add_argument("plugin_name", help="Plugin artifactId to remove")
    args = parser.parse_args()

    try:
        remove_plugin_block(args.pom_path, args.plugin_name)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
