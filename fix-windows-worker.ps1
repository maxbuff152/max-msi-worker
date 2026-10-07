#Requires -Version 5.1
# Retired compatibility entrypoint. Never patch or launch the Windows worker.
throw "Windows-native Max-MSI is unsupported (T-F70597). Use START-MAX-MSI.cmd or bootstrap-max-msi.ps1 for WSL Ubuntu. Run install-autostart.ps1 once to disable any legacy native task."
