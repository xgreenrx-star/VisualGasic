#!/bin/bash
# Upload VisualGasic to GitHub
# Run this script to commit and push all changes

set -e

echo "========================================="
echo "  VisualGasic GitHub Upload Script"
echo "========================================="
echo ""

# Confirm repository
echo "Repository: https://github.com/xgreenrx-star/VisualGasic.git"
echo ""

# Show what will be committed
echo "Files to be committed:"
git status --short | head -20
TOTAL=$(git status --short | wc -l)
echo "... and $TOTAL files total"
echo ""

# Confirm
read -p "Do you want to continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Upload cancelled."
    exit 1
fi

# Stage all changes
echo ""
echo "Staging all changes..."
git add .

# Commit
echo ""
echo "Creating commit..."
git commit -m "Migrate to .vg file extension and update all documentation

Major changes:
- Renamed all source files to .vg extension (125 files)
- Updated all documentation with new file references
- Updated scene files and test runners
- Enhanced .gitignore
- Cleaned up temporary and backup files
- Updated GitHub repository URLs
- Ready for public release"

# Show commit info
echo ""
echo "Commit created successfully!"
git log -1 --oneline

# Push
echo ""
echo "Pushing to GitHub..."
git push origin main

echo ""
echo "========================================="
echo "  Upload Complete! ✅"
echo "========================================="
echo ""
echo "View your repository at:"
echo "https://github.com/xgreenrx-star/VisualGasic"
echo ""
echo "Next steps:"
echo "1. Visit the repository on GitHub"
echo "2. Check that everything looks correct"
echo "3. Create a release (optional): git tag v1.0.0 && git push origin v1.0.0"
echo "4. Update repository description and topics"
echo ""
