# Manual steps after running BaseInstallDev.ps1

1. **WSL** — install via Settings > Optional Features > Windows Subsystem for Linux
   (The script only updates an existing WSL install, it cannot perform the first-time install.)

2. **AWS profile** — `aws configure --profile dev`

3. **Docker** — install Docker Desktop, then verify it is running: `docker ps`
