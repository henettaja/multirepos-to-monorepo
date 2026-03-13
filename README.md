# multirepos-to-monorepo

Merge multiple Git repositories into a single monorepo **while preserving full commit history, tags, and Git LFS objects**.

This Bash script automates the process of:
- importing each repo into its own subfolder,
- handling tag prefixing to avoid collisions,
- doing robust default branch detection,
- and cleaning up all temporary directories automatically to save disk space.

Perfect for teams migrating from many scattered repos to a single source of truth with a clean, auditable history.

***

## ✨ Features

- **Full history preservation** for each imported repository under its own subfolder.
- **Tag prefixing** (optional) → prevents tag name collisions across repos (e.g. `repoA-v1.0`).
- **Use any git platform**, like GitHub, GitLab etc.
- **Robust default branch detection** (`symbolic-ref`, remote HEAD, fallback).
- **Skips empty source repos** gracefully without breaking the run.
- **Initial empty commit** in the monorepo if no commits exist yet.
- **Immediate per-repo cleanup** + final workspace cleanup (`trap cleanup EXIT`) — no leftover temp dirs.
- **Detailed merge commit messages** with source repo & branch info.
- **Safe subdir validation** to prevent path traversal risks.

***

## 🛠 Requirements

- `bash`
- `git`
- [`git-filter-repo`](https://github.com/newren/git-filter-repo) (must be in `$PATH`)

***

## 🚀 Quick Start

1. **Clone this repo**
   ```bash
   git clone https://github.com//multirepos-to-monorepo.git
   cd multirepos-to-monorepo
   ```

2. **Configure your migration**
   - Open `merge-repos.sh`
   - Update:
     - `MONOREPO_NAME` → name of the destination monorepo.
     - `REPOS_TO_IMPORT` → list of repos in the following format:
     ```bash
     # "<git_url> <subdir>"
     REPOS_TO_IMPORT=(
       "https://github.com/myorg/service-a.git service-a"
       "git@github.com:myorg/libB.git libB"
     )
     ```
     - You can also organize repos into subdirectories:
     ```bash
     # "<git_url> <subdir>"
     REPOS_TO_IMPORT=(
       "https://github.com/myorg/service-a.git services/service-a"
       "https://github.com/myorg/service-a.git services/service-b"
       "git@github.com:myorg/libB.git libraries/libA"
       "git@github.com:myorg/libB.git libraries/libB"
     )
     ```

3. **Run the script**
   ```bash
   chmod +x merge-repos.sh
   ./merge-repos.sh
   ```

4. **Verify the results**
   - Inspect your monorepo in your Git provider — each imported repo will be under its own folder.
   - Tags will appear with prefixes if `PREFIX_TAGS=true`.

***

## ⚙ Configuration Reference

| Variable | Description                           |
|----------|---------------------------------------|
| `MONOREPO_NAME` | Destination repo name                 |
| `MONOREPO_DEFAULT_BRANCH` | e.g., `main`                          |
| `MONOREPO_URL` | URL for your destinatio monorepo      |
| `PREFIX_TAGS` | `true` = prefix tags with subdir name |
| `REPOS_TO_IMPORT` | Array of `<git_url> <subdir>`         |

***

## 🔍 How It Works

1. Clones your empty destination repository.
2. Clones each source repo into a **temporary directory** inside a workspace.
3. Detects the default branch of imported repos automatically:
   - Tries remote HEAD (`symbolic-ref`), then `git remote show origin`, then common names like `main` or `master`.
4. Optionally renames tags by prefixing with <subdir> to prevent collisions.
5. Runs `git filter-repo --to-subdirectory-filter` to move history into its subfolder.
6. Merges into the monorepo branch with `--allow-unrelated-histories`.
7. Pushes monorepo (and tags) to your Git provider and sets default branch.
8. Deletes the individual temp clone **immediately** and cleans up the whole temp workspace on exit.

***

## 🛡 Special Cases Handled

- **Empty source repo** → detected & skipped with a warning.
- **Empty monorepo branch** → automatically starts with an empty commit.
- **Existing temp remotes** → removed before reuse to avoid Git conflicts.
- **Unsafe subdir names** (`..` or starting `/`) → skipped to prevent security issues.
- **Temp space cleanup**:
  - Per-repo clone deleted after merge.
  - Global temp workspace deleted on script exit — even on failure.

***

## 📄 License
This project is licensed under the MIT License — see the [LICENSE](./LICENSE) file for details.
