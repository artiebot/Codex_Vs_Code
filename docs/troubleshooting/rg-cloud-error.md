# Ripgrep OneDrive Cloud Error (os error 389)

## Symptom
Running ripgrep from Windows PowerShell inside this repo prints messages such as:

`
rg: ...\\venv\\lib\\python3.11\\site-packages\\...\\*.pyc: The cloud operation was unsuccessful. (os error 389)
`

## Cause
OneDrive keeps many files in env/ and site-packages/ as cloud placeholders. When ripgrep walks those directories it touches files that are not hydrated locally, so the OS reports os error 389 and the search fails.

## Fix
1. Keep searches rooted at the repo by running ripgrep as:
   `powershell
   rg "<pattern>" -n -S -uu --hidden .
   `
   Using . lets ripgrep honor .rgignore.
2. Ignore heavy and placeholder-prone paths by adding these globs to .rgignore and .continueignore:
   `
   venv/
   **/__pycache__/**
   **/*.pyc
   **/site-packages/**
   node_modules/
   build/
   dist/
   .git/
   .vscode/
   **/*.png
   **/*.jpg
   **/*.zip
   **/*.csv
   `
3. Mirror the same exclusions in .vscode/settings.json under search.exclude so VS Code UI searches avoid OneDrive-only placeholders.

## Optional alternatives
- In File Explorer, right-click the project folder and choose **OneDrive → Always keep on this device** to hydrate the virtual files.
- Move the Python env directory outside of OneDrive (e.g. C:\venvs\feeder) and point VS Code to that interpreter.

Following these steps prevents ripgrep from touching cloud-only files and keeps searches fast and reliable.
