#!/bin/bash
# Script to clean up LaTeX build artifacts and diff files
# Removes all root-diff.* files and root.* files (except root.tex)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   LaTeX Cleanup Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Count files to be deleted (excluding .pdf files)
DIFF_FILES=$(ls root-diff.* 2>/dev/null | grep -v ".pdf" | wc -l | tr -d ' ')
ROOT_FILES=$(ls root.* 2>/dev/null | grep -v "root.tex" | grep -v ".pdf" | wc -l | tr -d ' ')
TOTAL=$((DIFF_FILES + ROOT_FILES))

if [ "$TOTAL" -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Already clean - no files to remove"
    exit 0
fi

echo -e "${YELLOW}Files to be removed:${NC}"
echo ""

# Show root-diff files (excluding .pdf)
if [ "$DIFF_FILES" -gt 0 ]; then
    echo -e "${BLUE}root-diff files (keeping .pdf):${NC}"
    ls root-diff.* 2>/dev/null | grep -v ".pdf" | sed 's/^/  /'
    echo ""
fi

# Show root files (excluding root.tex and .pdf)
if [ "$ROOT_FILES" -gt 0 ]; then
    echo -e "${BLUE}root files (keeping root.tex and .pdf):${NC}"
    ls root.* 2>/dev/null | grep -v "root.tex" | grep -v ".pdf" | sed 's/^/  /'
    echo ""
fi

echo -e "${YELLOW}Total files to remove: $TOTAL${NC}"
echo ""

# Ask for confirmation if running interactively
if [ -t 0 ]; then
    read -p "Continue? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Cleanup cancelled${NC}"
        exit 0
    fi
fi

# Remove root-diff files (except .pdf)
if [ "$DIFF_FILES" -gt 0 ]; then
    for file in root-diff.*; do
        if [[ "$file" != *.pdf ]]; then
            rm -f "$file"
        fi
    done
    # Also remove temporary log files
    rm -f root-diff-*.log
    echo -e "${GREEN}✓${NC} Removed $DIFF_FILES root-diff file(s) (kept .pdf)"
fi

# Remove root files (except root.tex and .pdf)
if [ "$ROOT_FILES" -gt 0 ]; then
    for file in root.*; do
        if [ "$file" != "root.tex" ] && [[ "$file" != *.pdf ]]; then
            rm -f "$file"
        fi
    done
    echo -e "${GREEN}✓${NC} Removed $ROOT_FILES root file(s) (kept root.tex and .pdf)"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Cleanup complete!${NC}"
echo -e "${GREEN}========================================${NC}"

