BashLibrary
===========
<pre>
A BASH library with useful functions.
There is also a bin directory with useful scripts.
Copyright:
  2013 - 2023 by Cecil Westerhof
Contact:
  bash@decebal.nl

There is a LinkedIn group where this library is discussed:
    http://tinyurl.com/BASHScripting
</pre>
At the moment the functions are not very well documented. Generating
some useful functions has a higher priority. Most functions are easy to
understand, but when there is a function that would benefit greatly from
better documentation: let me know.

If you would like to see a certain function: let me know.

To install the library on your system run install.sh.
Use ‘source /usr/local/bash/BASHInitialisation.sh’ (in .bashrc) to
initialise the library.
To use the scripts add /usr/local/bash/bin to your PATH.


The files contain the following functions:

In BASHInitialisation.sh:
- addToPath
- calc
- canRun
- chall
- cdll
- checkInteger
- checkNetworkInterface
- checkReadableDirectory
- checkReadOnlyVariables
- cleanPath
- commandExists
- convertInput
- defaultPS_OPTIONS
- elementInList
- fatal
- filterCommand
- getCPUTemperature
- getOptionValue
- getPathDirs
- isInteger
- isInteractive
- isVarSet
- loadXmodmapExtra
- logDRY
- logError
- logMsg
- nrOfDirs
- nrOfFiles
- nrOfFilesAndDirs
- psCommand
- psGrep
- psPid
- psPpid
- psStatus
- psUser
- removeFromPath
- screent
- showMessage
- stackTrace
- stripLeadingZeros
- taggedMsg
- taggedMsgAndStackTrace
- valueInArray
- variableExist
- warning
In interactive mode also:
- +=
- -=
- ==

In disk.sh:
- changedToday
- diskFree
- diskUsage
- doUnzip
- getDirTree
- getFunctionsFromFile
- includeFile
- isReadableFile
- localFind
- pushdCheck
- removeSpacesFromFileNames
- removeSpecialCharsFromFileName
- sizeOfFolder

In network.sh:
- checkInternetConnection
- checkWiFi
- connectedToNetwork
- getIPs

In random.sh:
- getRandom
- getRandomInRange
- getUUID

In system.sh:
- getMemInfoFromPID
- getMemInfoFromString
- getVMPeak

In systemd.sh:
- checkJournal
- illegalLogin
- showJournalctl

In time.sh:
- getSeconds
- waitMinutes
- waitSeconds

The bin directory contains:
- clojure
- installGuestAdditions.sh
- swapUsage.sh: with links to
  - memUsage.sh
  - memUsageProgram.sh
  - programsUsingMem.sh
  - programsUsingSwap.sh
  - swapUsageProgram.sh
