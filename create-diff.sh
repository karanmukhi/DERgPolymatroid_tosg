#!/bin/bash
# Script to create a marked-up PDF showing changes between two LaTeX versions
# Usage:
#   ./create-diff.sh                           # Compares v1/ with current version
#   ./create-diff.sh path/to/old path/to/new   # Custom comparison
#   ./create-diff.sh v2/ v3/                   # Compare two specific versions

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default paths
OLD_DIR="${1:-v1}"
NEW_DIR="${2:-.}"
OUTPUT_NAME="${3:-root-diff}"

# Full paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Handle relative paths properly
if [ "$OLD_DIR" = "." ]; then
    OLD_PATH="${SCRIPT_DIR}/root.tex"
else
    OLD_PATH="${SCRIPT_DIR}/${OLD_DIR}/root.tex"
fi

if [ "$NEW_DIR" = "." ]; then
    NEW_PATH="${SCRIPT_DIR}/root.tex"
else
    NEW_PATH="${SCRIPT_DIR}/${NEW_DIR}/root.tex"
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   LaTeX Diff Generator${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Comparing:${NC}"
echo -e "  Old: ${OLD_PATH}"
echo -e "  New: ${NEW_PATH}"
echo ""

# Check if files exist
if [ ! -f "$OLD_PATH" ]; then
    echo -e "${RED}❌ Error: Old file not found: $OLD_PATH${NC}"
    exit 1
fi

if [ ! -f "$NEW_PATH" ]; then
    echo -e "${RED}❌ Error: New file not found: $NEW_PATH${NC}"
    exit 1
fi

# Step 1: Create the diff
echo -e "${BLUE}[1/5]${NC} Creating latexdiff file..."
cd "$SCRIPT_DIR"

# Create diff, suppress warnings to stderr but keep output
if latexdiff --flatten "$OLD_PATH" "$NEW_PATH" > "${OUTPUT_NAME}.tex" 2> /tmp/latexdiff-warnings.txt; then
    echo -e "${GREEN}✓${NC} Diff file created: ${OUTPUT_NAME}.tex"
else
    # Check if diff file was still created despite warnings
    if [ -f "${OUTPUT_NAME}.tex" ] && [ -s "${OUTPUT_NAME}.tex" ]; then
        echo -e "${YELLOW}⚠${NC}  Diff created with warnings (usually harmless)"
    else
        echo -e "${RED}❌ Error: Failed to create diff file${NC}"
        echo -e "Try running manually: latexdiff --flatten \"$OLD_PATH\" \"$NEW_PATH\""
        if [ -f /tmp/latexdiff-warnings.txt ]; then
            echo -e "${YELLOW}Warnings:${NC}"
            cat /tmp/latexdiff-warnings.txt
        fi
        exit 1
    fi
fi
rm -f /tmp/latexdiff-warnings.txt

# Fix: latexdiff --flatten removes \bibliography command, add it back
if ! grep -q "\\\\bibliography{" "${OUTPUT_NAME}.tex"; then
    # Find the bibliographystyle line and add bibliography command after it
    if grep -q "\\\\bibliographystyle" "${OUTPUT_NAME}.tex"; then
        sed -i '' '/\\bibliographystyle{IEEEtran}/a\
\\bibliography{references}
' "${OUTPUT_NAME}.tex"
        echo -e "${BLUE}ℹ${NC}  Fixed missing bibliography reference"
    fi
fi
echo ""

# Step 2: First pdflatex pass
echo -e "${BLUE}[2/5]${NC} Compiling LaTeX (pass 1/3)..."
pdflatex -interaction=nonstopmode "${OUTPUT_NAME}.tex" > "${OUTPUT_NAME}-pass1.log" 2>&1
if [ -f "${OUTPUT_NAME}.aux" ]; then
    echo -e "${GREEN}✓${NC} First pass complete"
else
    echo -e "${RED}❌ Error in first pass - .aux file not created${NC}"
    echo -e "Check ${OUTPUT_NAME}-pass1.log for details"
    exit 1
fi
echo ""

# Step 3: Process bibliography
echo -e "${BLUE}[3/5]${NC} Processing bibliography..."
# Check if bibliography is needed
if grep -q "\\\\citation" "${OUTPUT_NAME}.aux" 2>/dev/null; then
    if bibtex "${OUTPUT_NAME}" > "${OUTPUT_NAME}-bibtex.log" 2>&1; then
        echo -e "${GREEN}✓${NC} Bibliography processed"
    else
        # Check if it's a real error or just warnings
        if [ -f "${OUTPUT_NAME}.bbl" ]; then
            echo -e "${YELLOW}⚠${NC}  BibTeX completed with warnings"
        else
            echo -e "${YELLOW}⚠${NC}  BibTeX failed - continuing without bibliography"
            echo -e "   (Check ${OUTPUT_NAME}-bibtex.log for details)"
        fi
    fi
else
    echo -e "${BLUE}ℹ${NC}  No bibliography needed"
fi
rm -f "${OUTPUT_NAME}-pass1.log" "${OUTPUT_NAME}-bibtex.log"
echo ""

# Step 4: Second pdflatex pass
echo -e "${BLUE}[4/5]${NC} Compiling LaTeX (pass 2/3)..."
pdflatex -interaction=nonstopmode "${OUTPUT_NAME}.tex" > /dev/null 2>&1
if [ $? -eq 0 ] || [ -f "${OUTPUT_NAME}.pdf" ]; then
    echo -e "${GREEN}✓${NC} Second pass complete"
else
    echo -e "${YELLOW}⚠${NC}  Warnings in second pass (continuing...)"
fi
echo ""

# Step 5: Third pdflatex pass (final)
echo -e "${BLUE}[5/5]${NC} Compiling LaTeX (pass 3/3)..."
pdflatex -interaction=nonstopmode "${OUTPUT_NAME}.tex" > "${OUTPUT_NAME}-final.log" 2>&1
LATEX_EXIT=$?

# Small delay to ensure file system sync
sleep 0.5

if [ $LATEX_EXIT -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Final pass complete"
elif [ -f "${OUTPUT_NAME}.pdf" ]; then
    echo -e "${YELLOW}⚠${NC}  Warnings in final pass (PDF created)"
else
    echo -e "${RED}❌ Error in final pass${NC}"
fi
echo ""

# Additional passes to ensure bibliography is fully resolved
echo -e "${BLUE}[6/9]${NC} Additional compilation for bibliography resolution..."
pdflatex -interaction=nonstopmode "${OUTPUT_NAME}.tex" > /dev/null 2>&1
echo -e "${GREEN}✓${NC} Pass 4 complete"
echo ""

echo -e "${BLUE}[7/9]${NC} Re-processing bibliography..."
bibtex "${OUTPUT_NAME}" > /dev/null 2>&1
echo -e "${GREEN}✓${NC} Bibliography updated"
echo ""

echo -e "${BLUE}[8/9]${NC} Compiling with updated bibliography..."
pdflatex -interaction=nonstopmode "${OUTPUT_NAME}.tex" > /dev/null 2>&1
echo -e "${GREEN}✓${NC} Pass 5 complete"
echo ""

echo -e "${BLUE}[9/9]${NC} Final compilation pass..."
pdflatex -interaction=nonstopmode "${OUTPUT_NAME}.tex" > /dev/null 2>&1
echo -e "${GREEN}✓${NC} Pass 6 complete"
echo ""
