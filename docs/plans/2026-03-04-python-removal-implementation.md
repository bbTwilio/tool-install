# Python/Textual Removal Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove all Python/Textual components and consolidate around shell/GUM/Ansible implementation.

**Architecture:** Clean removal of Python code, preservation of Ansible roles, enhancement of shell script with browser feature.

**Tech Stack:** Bash, GUM (TUI), Ansible, YAML

---

## Task 1: Backup and Move Ansible Configuration

**Files:**
- Move: `tool-installer/config/ansible/` → `config/ansible/`
- Delete: `config/ansible/roles/ngrok/`
- Delete: `config/ansible/roles/nodejs/`

**Step 1: Backup existing minimal config**

```bash
cp -r config/ansible config/ansible.backup
```

**Step 2: Remove old minimal roles**

```bash
rm -rf config/ansible/roles/ngrok
rm -rf config/ansible/roles/nodejs
```

**Step 3: Copy complete Ansible setup from tool-installer**

```bash
cp -r tool-installer/config/ansible/* config/ansible/
```

**Step 4: Verify roles copied correctly**

```bash
ls -la config/ansible/roles/
```
Expected: aws_cli, git, ngrok, nodejs directories present

**Step 5: Commit Ansible migration**

```bash
git add config/ansible/
git commit -m "chore: migrate complete Ansible roles from tool-installer"
```

---

## Task 2: Move tools.yaml Configuration

**Files:**
- Move: `tool-installer/config/tools.yaml` → `config/tools.yaml`

**Step 1: Copy tools.yaml to new location**

```bash
cp tool-installer/config/tools.yaml config/tools.yaml
```

**Step 2: Verify file copied correctly**

```bash
head -20 config/tools.yaml
```
Expected: YAML content with tool definitions

**Step 3: Commit tools.yaml migration**

```bash
git add config/tools.yaml
git commit -m "chore: move tools.yaml to config directory"
```

---

## Task 3: Update Shell Script Paths

**Files:**
- Modify: `install-tools.sh:10-11`

**Step 1: Update TOOLS_YAML path**

```bash
# Old line 10:
TOOLS_YAML="${SCRIPT_DIR}/tool-installer/config/tools.yaml"
# New line 10:
TOOLS_YAML="${SCRIPT_DIR}/config/tools.yaml"
```

**Step 2: Update ANSIBLE_DIR path**

```bash
# Old line 11:
ANSIBLE_DIR="${SCRIPT_DIR}/tool-installer/config/ansible"
# New line 11:
ANSIBLE_DIR="${SCRIPT_DIR}/config/ansible"
```

**Step 3: Test path resolution**

```bash
bash -n install-tools.sh
```
Expected: No syntax errors

**Step 4: Commit path updates**

```bash
git add install-tools.sh
git commit -m "fix: update config paths in install-tools.sh"
```

---

## Task 4: Add Browser Launch Feature

**Files:**
- Modify: `install-tools.sh` (add after line ~350, in post-installation section)

**Step 1: Add browser launch function**

Add after the log_message function (around line 32):

```bash
# Function to open tool documentation in browser
open_tool_docs() {
    local tool_name=$1
    local tool_url=$2

    if [[ -n "$tool_url" ]]; then
        if gum confirm "Open $tool_name documentation in browser?"; then
            open "$tool_url" 2>/dev/null || {
                echo "Could not open browser automatically"
                echo "Documentation URL: $tool_url"
            }
        fi
    fi
}
```

**Step 2: Integrate with post-installation**

Add in the post-installation section after showing instructions:

```bash
# After line ~360 (in show_post_install_instructions function)
# Add documentation browser prompt
if [[ -n "${post_install_docs[$tool]}" ]]; then
    open_tool_docs "$tool" "${post_install_docs[$tool]}"
fi
```

**Step 3: Test syntax**

```bash
bash -n install-tools.sh
```
Expected: No syntax errors

**Step 4: Commit browser feature**

```bash
git add install-tools.sh
git commit -m "feat: add browser launch for tool documentation"
```

---

## Task 5: Remove Python Directories

**Files:**
- Delete: `tool-installer/` (entire directory)
- Delete: `src/installer/` (empty directory)

**Step 1: Verify no uncommitted changes in tool-installer**

```bash
ls -la tool-installer/
```
Expected: Directory listing showing Python files

**Step 2: Remove tool-installer directory**

```bash
rm -rf tool-installer
```

**Step 3: Remove empty src/installer directory**

```bash
rm -rf src/installer
```

**Step 4: Verify removal**

```bash
ls -la | grep -E "tool-installer|src"
```
Expected: No tool-installer, src might show if other subdirs exist

**Step 5: Commit removals**

```bash
git add -A
git commit -m "chore: remove Python/Textual implementation and empty directories"
```

---

## Task 6: Update README

**Files:**
- Rename: `README-shell-installer.md` → `README.md`

**Step 1: Rename README file**

```bash
mv README-shell-installer.md README.md
```

**Step 2: Update title in README**

Edit first line:
```markdown
# Tool Installer - Shell Script + Gum UI
```

**Step 3: Remove comparison section**

Remove lines 123-133 (Python comparison table)

**Step 4: Commit README update**

```bash
git add README.md README-shell-installer.md
git commit -m "docs: rename and update README for single implementation"
```

---

## Task 7: Clean Up and Test

**Files:**
- Modify: `test-installer.sh` (if needed)
- Modify: `test-installer-windows.sh` (if needed)

**Step 1: Update test script paths if needed**

```bash
grep -n "tool-installer" test-installer.sh test-installer-windows.sh
```
If matches found, update paths to use `config/` instead

**Step 2: Remove backup if everything works**

```bash
rm -rf config/ansible.backup
```

**Step 3: Run installer in test mode**

```bash
./install-tools.sh
```
Expected: Tool selection menu appears with GUM UI

**Step 4: Test tool detection**

Select "Cancel" and verify already installed tools show ✓

**Step 5: Final commit**

```bash
git add -A
git commit -m "chore: complete Python removal and cleanup"
```

---

## Task 8: Verification

**Step 1: Check for any remaining Python files**

```bash
find . -name "*.py" -o -name "requirements*.txt" -o -name "*.pyc"
```
Expected: No results

**Step 2: Verify config structure**

```bash
tree config/
```
Expected: Clean structure with ansible/ and tools.yaml

**Step 3: Test full installation flow**

```bash
./install-tools.sh
```
Select an uninstalled tool and verify installation works

**Step 4: Document success**

```bash
echo "✅ Python/Textual removal complete" >> docs/plans/2026-03-04-python-removal-implementation.md
date >> docs/plans/2026-03-04-python-removal-implementation.md
```

---

## Success Criteria

- [ ] No Python files remain in project
- [ ] Ansible roles successfully moved to config/ansible/
- [ ] tools.yaml accessible at config/tools.yaml
- [ ] install-tools.sh works with new paths
- [ ] Browser launch feature integrated
- [ ] README updated to reflect single implementation
- [ ] All tests pass✅ Python/Textual removal complete
Wed, Mar  4, 2026  3:07:06 PM
