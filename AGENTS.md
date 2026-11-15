# Project GitHub sync

After changing a file tracked by this project or creating a new file that belongs
to the shared project, commit and push the relevant changes to
`https://github.com/yousefgharib335/selected-project` on `main` before handing
the work back. The project owner has authorized this routine sync.

The local `project/` directory corresponds to the repository root. If the
workspace is not a Git checkout, use a fresh checkout of the private repository
and copy the relevant changes into it at the same relative paths. Review the
remote version and the staged diff first. Preserve teammates' work, resolve
compatible changes, and never force-push or overwrite a conflicting edit.

Include related source files, documentation and shareable deliverables. Respect
the repository's ignore rules and keep machine-local outputs, credentials, and
unrelated files out of commits. Run the appropriate checks and verify that the
commit reached GitHub. If there is nothing to sync, skip the commit. If a push
fails, report the reason and which changes remain local.
