**On macOS**, click the Apple menu > *About This Mac* and read *Memory*. Or open *Terminal* (in *Applications* > *Utilities*) and run

```sh
sysctl -n hw.memsize | awk '{print $1/2^30 " GB"}'
```

**On Windows**, open *Settings* > *System* > *About* and read *Installed RAM*. Or open *Windows PowerShell* and run

```powershell
(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB
```

On Windows, the number can be a little below the installed amount (e.g., 15.8 for 16 GB).

**In R**, on either system, run

```r
ps::ps_system_memory()$total / 1024^3
```

(If R says there is no package called 'ps', run `install.packages("ps")` first.)
