# Git LFS Object Migration Tool

⚠️ **WARNING: EXPERIMENTAL TOOL** ⚠️  
**USE AT YOUR OWN RISK. This tool may cause data loss or repository corruption.**

This script helps migrate Git LFS objects from one GitHub repository to another. It uses the GitHub LFS API to download objects from the source repository and then pushes them to the destination repository.

### Risk Mitigation

To reduce risk when using this tool:
- Make the source repository read-only before running the script (either archive the repository on GitHub or use a token with read-only permissions)
- Create a backup of both repositories before starting the migration
- Test on a non-production repository first

## Prerequisites

- `jq` command-line tool for JSON processing
- Git LFS installed and configured
- GitHub Personal Access Token with appropriate permissions

## How to Use

1. **Clone the source repository with a mirror**:
   ```bash
   git clone --mirror https://github.com/source-org/source-repo.git
   cd source-repo.git
   ```

2. **Run the migration script**:
   ```bash
   /path/to/lfs_migrate.sh destination-org destination-repo github-pat
   ```
   
   Where:
   - `destination-org` is the GitHub organization name of the destination repository
   - `destination-repo` is the name of the destination repository
   - `github-pat` is your GitHub Personal Access Token

3. **Validate the migration** (recommended):
   ```bash
   # Clone the destination repository
   git clone https://github.com/destination-org/destination-repo.git
   cd destination-repo
   
   # Fetch all LFS objects and validate them
   git lfs fetch --all
   git lfs fsck
   ```
   
   This validation step helps ensure all LFS objects were properly migrated and are accessible.

## How It Works

The script:
1. Connects to both source and destination repositories
2. Identifies all LFS objects in the source repository
3. Downloads each LFS object using the GitHub LFS Batch API
4. Pushes each object to the destination repository
5. Cleans up temporary files

## Limitations

- This is an experimental tool and has not been thoroughly tested in production environments
- Large repositories with many LFS objects may take a long time to migrate
- Network errors or API rate limits may interrupt the migration process

## Troubleshooting

If you encounter issues:
- Check your GitHub token has sufficient permissions
- Verify the source and destination repositories are correctly configured with Git LFS
- Examine any error messages for API failures or rejection reasons

## License

This project is licensed under the ISC License - see the [LICENSE](LICENSE) file for details.
