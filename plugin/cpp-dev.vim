"===============================================================================
"
"
"  When developing vimscripts for this plugin, use the command below to
"  reinstall it after making changes (don't include the ':' when pasting to the 
"  command line):
"
"  :unlet g:CPP_DEV_Version | runtime! plugin/cpp-dev.vim
"
"  Author:  Bill de Bruyn
"  email:   bill@azul3d.com
"
"===============================================================================

"
" Prevent duplicate loading:
"
if exists("g:CPP_DEV_Version") || &cp
 finish
endif
"
let g:CPP_DEV_Version= "0.0.1"

let g:testDirectory=''
let g:gtest_filter='*.*'
let g:isMosquittoInstalled=0      " Used to prevent needless copies to target
let g:isResourceDirInstalled=0    " Used for prevent needless copies to target

"===============================================================================
"  g:gcov 
"     llvm - run the llvm code coverage tools (default) Expects llvm-15
"     gnu  - run the gcov and lcov code coverage tools. Expects version 9
"===============================================================================
let g:gcov='llvm'
let g:NO_PID=-1
let g:firefoxPid=g:NO_PID
let g:firefoxWindow=0
let g:midoriPid=g:NO_PID
let g:midoriWindow=0

let g:currentWindow=winnr()

"===============================================================================
"
" -- Check if a file exists
"
"===============================================================================
function! GetUbuntuCodeName()
    let l:os_info = system('grep DISTRIB_CODENAME /etc/lsb-release')

    if l:os_info =~ 'jammy'
        return 'jammy'
    endif

    if l:os_info =~ 'focal'
        return 'focal'
    endif

    return 'Unknown version'
endfunction

"===============================================================================
"
" -- Check if we are Jammy
"
"===============================================================================
function! IsJammy()
   if GetUbuntuCodeName() == 'jammy'
      return 1
   endif
   return 0
endfunction

"===============================================================================
"
" -- Check if we are Focal
"
"===============================================================================
function! IsFocal()
   if GetUbuntuCodeName() == 'focal'
      return 1
   endif
   return 0
endfunction

"===============================================================================
"
" -- Check if a file exists
"
"===============================================================================
function! FileExists(filepath)
   if filereadable(a:filepath)
      return 1
   endif

   return 0
endfunction

"===============================================================================
"
" -- Stripe the filename from the path. Return just the path
"
"===============================================================================
function! GetDirectoryPath(filePath)
    let l:dirPath = fnamemodify(a:filePath, ':h')

    if l:dirPath == '.'
       return ''
    endif

    let l:dirPath= l:dirPath . '/'
    return l:dirPath
endfunction

"===============================================================================
"
" -- Create a directory on the host from a path/filname
"
"===============================================================================
function! MakeDirectoryFromPath(fullPath)
   let l:dirPath = fnamemodify(a:fullPath, ':h')
   let l:command = 'mkdir -p ' . shellescape(l:dirPath)
   let l:command=l:command . ' 2>/dev/null'
   "echo 'MakeDirectoryFromPath: ' . l:command
   call system(l:command)

   if v:shell_error
      echo "Failed to create directory: " . l:dirPath
      return 0
   else
      return 1
   endif
endfunction

"===============================================================================
"
" -- Transfer options
"
"===============================================================================
function! GetTransferOptions()
   if IsJammy()
      return ' -o HostKeyAlgorithms=+ssh-rsa '
   endif
   return ''
endfunction

"===============================================================================
"
" -- Execute ssh command to target
"
"===============================================================================
function! Ssh(command)
   let l:cmd='ssh ' . GetTransferOptions() . ' ' . GetBoard() . ' '
   let l:cmd .= shellescape(a:command, 1)
   echo l:cmd
   let results=system(l:cmd)

   if v:shell_error
      echoerr "Failed " . a:command
      return 0
   endif
   
   if len(l:results)==0
      return 1
   endif

   return l:results
endfunction

"===============================================================================
"
" -- Execute ssh command to target
"     isToPath -  0:  do not create the host path on the target. Copy of the
"                     file is to the root directory.
"                 1:  Create the host path on the target and copy the target
"                     file to it.
"
"===============================================================================
function! FileToTarget(pathFilename, path)
   if (IsArmProcessor())
      if a:path == ''
         let l:path=''
      else
         let l:path=a:path
         let l:command='mkdir -p ' . l:path

         if !Ssh(l:command)
            echo 'ERROR: failed to executed
            return 0
         endif
      endif

      " if a:isToPath == 0
      "    let l:command='scp ' . GetTransferOptions() . ' ' . a:pathFilename . ' ' . GetBoard() . ':'
      "    echo "let l:command='scp ' . GetTransferOptions() . ' ' . a:pathFilename . ' ' . GetBoard() . ':'"
      " else
         let l:command='scp ' . GetTransferOptions() . ' ' . a:pathFilename . ' ' . GetBoard() . ':' . l:path 
      " endif

      let l:command=l:command . ' 2>/dev/null'
      " echo 'command=' . l:command
      call system(l:command)

      if v:shell_error
         echoerr "Failed " . l:command
         return 0
      endif

      return 1
   endif
endfunction

"===============================================================================
"
" -- Test if file exists on target
"
"===============================================================================
function! IsFileOnTarget(targetPathFilename)
   let l:command="test -f " . a:targetPathFilename . " && echo '1' || echo '0'"
   "let l:command="\"" . l:command . "\""
   return Ssh(l:command)
endfunction

"===============================================================================
"
" -- Execute ssh command to target
"
"===============================================================================
function! TargetFileToHost(targetPathFilename, hostPathFilename)
   if (IsArmProcessor())
      let l:command='scp ' . GetTransferOptions() . ' ' . GetBoard() . ':' . a:targetPathFilename . ' ' . a:hostPathFilename
      let l:command=l:command . ' 2>/dev/null'
      call system(l:command)

      if v:shell_error
         echoerr "Failed " . l:command
         return 0
      endif

      return 1
   endif
endfunction

"===============================================================================
"
" -- Generate the filename for a sha256 hash file
"
"===============================================================================
function! GenerateSHA256Filename(filepath)
   let l:outputFile=a:filepath . '.sha256'
   return l:outputFile
endfunction

"===============================================================================
"
" -- Calculate sha256 hash of <filename> and return the hash value
"
"===============================================================================
function! GenerateSHA256Hash(filename)
   let l:command = 'sha256sum ' . shellescape(a:filename) . ' | cut -d " " -f1'
   let l:hash = system(l:command)

   if v:shell_error
       echoerr "Failed to compute SHA256 hash for " . a:filename
       return 0
   endif

   return l:hash
endfunction

"===============================================================================
"
" -- Get the hash value from <pathFilename> and save to <filename>.sha256
"
"===============================================================================
function! WriteSHA256File(pathFilename, hash)
   " echo 'WriteSHA256File: outputFile=' . a:pathFilename
   return writefile([a:hash[:-2]], a:pathFilename)
endfunction

"===============================================================================
"
" -- Copies sha256 hash file from target to host
"
"===============================================================================
function! CopySHA256ToTarget(filename, path)
   if (IsArmProcessor())
      if !FileToTarget(a:filename, a:path)
         echo 'Error: Failed to transfer: ' . a:filename
         return 0
      endif
   endif
   return 1
endfunction

"===============================================================================
"
" -- Copies sha256 hash file from target to host
"
"===============================================================================
function! CopySHA256FromTarget(targetPathFilename, hostPathFilename)
   if (IsArmProcessor())
      if !TargetFileToHost(a:targetPathFilename, a:hostPathFilename)
         return 0
      endif

      return a:hostPathFilename
   endif

   return
endfunction

"===============================================================================
"
" -- Compare sha256 hash to a file containing a hash to check for equality
"
"===============================================================================
function! IsEqualSHA256Hash(file1, hash2)
   "
   "  Remove extranous characters
   "
   let l:hash2 = a:hash2[:-2]

   let l:hash1 = readfile(a:file1)

    if empty(l:hash1)
       echo 'ERROR: no hash found in file ' . file1
       return 0
    endif

    let l:hash1=trim(l:hash1[0])

    if l:hash1 == l:hash2
       return 1
    endif

    return 0
endfunction

"===============================================================================
"
" -- Check to see if the target file is identical to the host file. 
"    Perform sha256 hash on the host file. Check if the target has a file
"    with the extension .sta256. If the target does not have the file, then
"    a file transfer is necessary. Create the .sta256 file and send it
"    to the target as well as the target file. If the sta256 file exists on the 
"    target, copy it to the host. Compare the contents of the target file against 
"    the hash of the host file. If it does not match, then copy the host version 
"    of the .sta256 file to the target and the target file. Otherwise, the file 
"    transfer does not have to take place.
"
"===============================================================================
function IsFileTransferable(pathFilename)

   "
   "  Create a hash value from the file
   "
   let l:hash=GenerateSHA256Hash(a:pathFilename)

   "
   "  Generate the <filename>.sha256 filename plus path
   "
   let l:sha256PathFilename=GenerateSHA256Filename(a:pathFilename)
   "
   "  Generate the /tmp/<filename>.sha256 path filename
   "
   let l:hostPathFilename='/tmp/' . l:sha256PathFilename
   
   "
   "  If the hostPathFilename path does not exist, create it
   "
   if !MakeDirectoryFromPath(l:hostPathFilename)
      echo 'ERROR: Cannot crate directory from ' . l:hostPathFilename
      return 0
   endif

   "
   "  Do not assume the <filename>.sha256 file exists on the target
   "  filesystem.
   "
   let l:isTargetSHAFileExist=0

   "
   "  Check if the <filename>.sha256 exists on the target filesystem
   "
   if IsFileOnTarget(l:sha256PathFilename)
      "
      "  Copy the <filename>.sha256 to host directory
      "
      if TargetFileToHost(l:sha256PathFilename, l:hostPathFilename)
         "
         "  Indicate we have the sha256 file
         "
         let l:isTargetSHAFileExist=1
      else
         echo 'FAILED to transfered sha256 to target'
      endif
   endif

   "
   "  Assume the <filename>.sha256 does not match
   "
   let l:isTransferable=1

   "
   "  If the target <filename>.sha256 is on the host,
   "  comapare the hash value for equal.
   "
   if l:isTargetSHAFileExist
      if IsEqualSHA256Hash(l:hostPathFilename, l:hash)
         "
         "  Hash values are equal, no need to perform a file transfer
         "
         let l:isTransferable=0
      endif
   endif

   "
   "  If a file transfer is required, transfer it
   "
   if l:isTransferable
      "
      "  Create a <filename>.sha256 file in the tmp dir
      "
      call WriteSHA256File(l:hostPathFilename, l:hash)
      "
      "  Copy the /tmp/file to the target
      "
      call CopySHA256ToTarget(l:hostPathFilename, GetDirectoryPath(a:pathFilename))
      return 1
   endif

   return 0
endfunction


"===============================================================================
"
" -- Search C++ specification files for occurances of a string
"
"===============================================================================
function! SearchSpec(value)
   let command=':!find -type f -name "*.h" | xargs grep -n "' . a:value . '"' 
   exe command . ' 2>&1 | tee /tmp/SearchSpecOutput.txt'
   redraw
   exe ':cg /tmp/SearchSpecOutput.txt | copen' 
   redraw
endfunction

"===============================================================================
"
" -- Search C++ implementation files for occurances of a string
"
"===============================================================================
function! SearchImpl(value)
   let command=':!find -type f -name "*.cpp" | xargs grep -n "' . a:value . '"' 
   exe command . ' 2>&1 | tee /tmp/SearchImplOutput.txt'
   redraw
   exe ':cg /tmp/SearchImplOutput.txt | copen' 
   redraw
endfunction

"===============================================================================
"
" -- returns the test fixture name and the test instance
"    If no test was found at the starting location,
"    then false is returned, otherwise true.
"
"===============================================================================
function! GetFixtureAndTestNames()
   let p=getcurpos()
   let startingPoint=p[1]+1
   call cursor(p[1]+1,p[2])
   let end=search("^TEST_F(", 'bn')
   call cursor(p[1],p[2])
   "
   " -- If the ending point wraps around to the end of the
   "    file, then no test at the starting cursor location.
   "
   if end > startingPoint
      return ['','',0,'ERROR: no test found under cursor']
   endif

   let s=getline(end)
   let gtest_filter=''
   "
   " -- Verify the search got the test fixture name.
   "
   " -- Note: The test fixture name should match the name of the
   "    test file. 
   if len(s) > 0
      let filename=trim(split(split(s,',')[0],'(')[1])
      let testname=trim(split(split(s,',')[1],')')[0])
      return [filename, testname,1]
   endif
   return ['','',0]
endfunction

"===============================================================================
"
" -- Determine if we are running in an ARM container
"    by examining the environment variable containing
"    the name of the container image.
"
"===============================================================================
function! IsArmProcessor()
   return len(matchstr($DOCKER, 'armv8-[a-z]*-img')) > 0
endfunction

"===============================================================================
"
" -- returns default ssh/scp login and ip address
"
"===============================================================================
function! GetBoard()
   return 'root@' . $BOARD
endfunction

"===============================================================================
"
" -- returns only the immediate above directory 
"
"===============================================================================
function! GetDirectoryName()
   return expand('%:h:t')
endfunction

"===============================================================================
"
" -- returns the file name without the file extension
"
"===============================================================================
function! GetFilenameNoExt()
   return expand('%:t:r')
endfunction

"===============================================================================
"
" -- returns test directory path of the current test
"
"===============================================================================
function! GetTestBuildDirectory()
   let testDirectory=GetDirectoryName()
   let path='build/tests/' . testDirectory . '/CMakeFiles/' . testDirectory . '.dir'
   return path
endfunction

"===============================================================================
"
" -- copies the relevant binaries and configuration file to the target
"    environment. Required to support MQTT development.
"
"===============================================================================
function! InstallMosquitto()
   if (g:isMosquittoInstalled)
      return
   endif
   if (IsArmProcessor())
      let path='/repo/.conan/data/mosquittov2/2.0.15/local/stable/package/*'
      let command=':!scp -o HostKeyAlgorithms=+ssh-rsa ' . path . '/config/mosquitto.conf ' . GetBoard() . ':'
      exe command
      let command=':!scp -o HostKeyAlgorithms=+ssh-rsa ' . path . '/bin/mosquitto* ' . GetBoard() . ':'
      exe command
      redraw
   else
      let command=':!sudo cp /repo/mosquittov2/build/src/mosquitto /usr/bin'
      exe command
      let command=':!sudo cp /repo/mosquittov2/build/client/mosquitto_* /usr/bin'
      exe command
      redraw
   endif
   let g:isMosquittoInstalled=1
   return 'succeeded'
endfunction

"===============================================================================
"
" -- Resets the global variable indicating mosquitto install to uninstalled
"
"===============================================================================
function! ResetMosquittoInstall()
   let g:isMosquittoInstalled=0
endfunction

"===============================================================================
"
" -- Verify the filename and the test fixture name
"    match
"
"===============================================================================
function! DoesTestFixtureFilenameMatch()
   let filename=GetFilenameNoExt()
   let fixture=GetFixtureAndTestNames()
   if !fixture[2]
      return 0
   endif
   if filename == fixture[0]
      return 1
   endif
   return 0
endfunction

"===============================================================================
"
" -- Verify the test fixture has a corresponding executable
"
"===============================================================================
function! DoesTestFixtureHaveExecutable()
   let directoryName=GetDirectoryName()
   let executable='build/bin/' . directoryName
   return !empty(expand(glob(executable)))
endfunction

"===============================================================================
"
" -- returns the string containing gtestfilter command line option for a test fixture name and optionally
"    the test instance. The last attribute in the list is a boolean value
"    indicate the success of the call.
"
" -- Call this function only after verifying the test fixture name
"    matches the filename, the filename has a corresponding executable
"    and that if as single test is being asked for, that the 
"    test name is valid.
"
"===============================================================================
function! GTestFilter(hasSingle)
   let names=GetFixtureAndTestNames()

   if !names[2]
      return [names[3],0]
   endif

   if len(names[0]) > 0
      let fixture=names[0]
   else
      "
      " Error: single requested but no single test found
      "
      if hasSingle
         return ['ERROR: fixture name not found',0]
      endif
      let fixture='*'
   endif
   if len(names[1]) > 0
      let test=names[1]
   else
      "
      " Error: single requested but no single test found
      "
      if hasSingle
         return ['ERROR: test name not found under cursor',0]
      endif
      let test='*'
   endif
   if a:hasSingle==1
      let gtest_filter='--gtest_filter=' . fixture . '.' . test
   else
      let gtest_filter='--gtest_filter=' . fixture . '.*'
   endif
   return [gtest_filter,1]
endfunction

"===============================================================================
"
" -- Build the test fixture of the active vim buffer
"
"===============================================================================
function! BuildTestFixture()
   let fixture=GetDirectoryName()
   let g:currentWindow=winnr()
   exe ':!ninja -C build -v tests/' . fixture . '/all 2>&1 | tee /tmp/buildoutput.txt'
   exe "cg /tmp/buildoutput.txt | copen"
endfunction

"===============================================================================
"
"===============================================================================
function! ConanArch()
   let arch=trim(system('grep -m 1 "^[ ]*arch=" conaninfo.txt | cut -d''='' -f2'))
   return arch
endfunction

"===============================================================================
"
"===============================================================================
function! ConanPackage()
   let arch=trim(ConanArch())
   exec "silent !rm -rf " . trim(arch) . "-package"
   exec "silent !conan package -pf " . trim(arch) . "-package ."
   exec "redraw!"
   return arch
endfunction

"===============================================================================
"
" -- Performs a build on the entire repo
"
"===============================================================================
function! BuildAll()
   let g:currentWindow=winnr()
   exec "!conan build .  2>&1 | tee /tmp/buildoutput.txt"
   exec "cg /tmp/buildoutput.txt | copen"
endfunction

function! PKill(process)
   " let command=":!ssh " . GetBoard() . "  -o HostKeyAlgorithms=+ssh-rsa \"pidof " . a:process . " | xargs kill -9"
   " exe command 
   let command="\"pidof " . a:process . " | xargs kill -9"
   return Ssh(l:command)
endfunction

function! IsTestRunning()
   let command='ps aux|grep "\-\-gtest_filter"'
   let test=substitute(system(command), '\n\+$', '', '') | echo strtrans(test)
   return len(test)
endfunction

function! KillTests()
   if (IsTestRunning())
      let kill="ps aux|grep '\-\-gtest_filter' | sed 's/ \+/ /g' |cut -d' ' -f2 |xargs kill -9"
      echo 'KillTests: kill=' . kill
      return Ssh(kill)
      " let command=":!ssh " . GetBoard() . "  -o HostKeyAlgorithms=+ssh-rsa " . kill 
      " let results=substitute(system(command), '\n\+$', '', '') | echo strtrans(results)
      " return results
   endif
   return "No tests running"
endfunction

"===============================================================================
"
" -- Copy the executable corresponding to the test directory name
"    to the ARM processor
"
"===============================================================================
function! CopyTestExecutable()
   "call InstallMosquitto()
   if IsArmProcessor()
      if !DoesTestFixtureHaveExecutable()
         return 'no executable'
      endif

      call KillTests()
      let pathFilename='build/bin/' . GetDirectoryName()

      if IsFileTransferable(l:pathFilename)
         echo 'copying test to target...'
         let results=FileToTarget(l:pathFilename, '')
         echo 'done copying test to target'
         return l:results
      endif

      return 0
   endif
endfunction

"===============================================================================
"
" -- Copy the all test executables to the ARM processor
"
"===============================================================================
function! CopyAllTestExecutables()
   if IsArmProcessor()
      let command=':!scp -o HostKeyAlgorithms=+ssh-rsa build/bin/Test_* ' . GetBoard() . ':'
      exe command
      redraw
      return 'succeeded'
   endif
   return 'Not an Arm processor'
endfunction

"===============================================================================
"
" -- Copy the TestRunner to the ARM processor
"
"===============================================================================
function! CopyTestRunner()
   if IsArmProcessor()
      let command=':!scp -o HostKeyAlgorithms=+ssh-rsa build/bin/TestRunner ' . GetBoard() . ':'
      silent exe command
      redraw
      return 'succeeded'
   endif
   return 'Not an Arm processor'
endfunction

"===============================================================================
"
" -- Is there a resources directory
"
"===============================================================================
function! IsResourcesDir()
   return isdirectory('resources')
endfunction

"===============================================================================
"
" -- 
"
"===============================================================================
function! CopyDirToTaget(directory, path)
    let l:dir = a:directory =~ '/$' ? a:directory : a:directory . '/'
    let l:files = split(glob(l:dir . '*'), "\n")

    for l:file in l:files
        if IsFileTransferable(l:file)
            call FileToTarget(l:file, a:path)
         endif
    endfor
endfunction

"-"===============================================================================
"-"
"-" -- Command to copy the resources directory to the ARM processor
"-"
"-"===============================================================================
"-function! CopyResourcesDirCommand()
"-   if IsArmProcessor()
"-      let command=':!scp -o HostKeyAlgorithms=+ssh-rsa -r resources/ ' . GetBoard() . ':'
"-      exec command
"-      redraw
"-      return 'succeeded'
"-   endif
"-   return 'Not an Arm processor'
"-endfunction

"===============================================================================
"
" -- Copy the entire resources directory to ARM processor
"
"===============================================================================
function! CopyResourcesToTarget()
   if IsArmProcessor()
      if IsResourcesDir()
         call CopyDirToTaget('resources/', 'resources/')
         "if !g:isResourceDirInstalled
         "   call CopyResourcesDirCommand()
         "   let g:isResourceDirInstalled=0
         "endif
      endif
   endif
endfunction

"===============================================================================
"
" -- Generate the command to run all 'build/bin/Test_*' binaries
"
"  TODO: Running GCOV on all tests files will not work as implemented below
"  It will fail when merging the source with the execution data. Source will
"  be in different folders relative to the single profraw file.
"===============================================================================
function! RunAllRemoteTests()
   if IsArmProcessor()
      let command='!ssh ' . GetBoard() . '  -o HostKeyAlgorithms=+ssh-rsa "find -type f -name \"Test_*\" -exec {} \;"'
      silent exec command . " 2>&1 | tee /tmp/gtestoutput.txt"
      redraw!
   else
      if IsGCOV()
        silent call system("rm -rf build/cov; mkdir -p build/cov")
        "
        let test=GetDirectoryName()
        "
        let command=':!echo "\n"'
        silent exec command . " 2>&1 | tee /tmp/gtestoutput.txt"
        "
        let qualifier='LLVM_PROFILE_FILE=build/cov/' . test . '.profraw '
        let command=':!' . qualifier . ' ./build/bin/' . test
        silent exec command . " 2>&1 | tee -a /tmp/gtestoutput.txt"
        "
        let command=':!llvm-profdata-15 merge build/cov/' . test . '.profraw -o build/cov/' . test . '.profdata'
        silent exec command . " 2>&1 | tee -a /tmp/gtestoutput.txt"
        "
        let command=':!llvm-cov-15 show -instr-profile=build/cov/' . test . '.profdata  -format=html --show-branches=count --show-branch-summary -output-dir=build/cov/' . test . ' build/bin/' . test
        silent exec command . " 2>&1 | tee -a /tmp/gtestoutput.txt"
        "
        redraw!
      else
        let command=':!find build/bin -type f -name "Test_*" -exec {} \;'
        silent exec command . " 2>&1 | tee /tmp/gtestoutput.txt"
        redraw!
      endif
   endif
endfunction

"===============================================================================
"
" -- Run one fixture and one test in the fixture
"    where the cursor is located
"
"===============================================================================
function! GTestOneFixtureOneTest()
   "
   " -- Verify the fixture and file names match
   "
   if !DoesTestFixtureFilenameMatch()
      let filename=GetFilenameNoExt()
      let error='ERROR: file name and test fixture name do not match: ' . filename
      echo error
      return error
   endif
   "
   " -- Verify there is an executable
   "
   if !DoesTestFixtureHaveExecutable()
      let filename=GetFilenameNoExt()
      let error='ERROR: no executable found for ' . filename
      echo error
      return error
   endif

   let g:currentWindow=winnr()
   let gtest_filter=GTestFilter(1)

   if !gtest_filter[1]
      echo gtest_filter[0]
      return gtest_filter[0]
   endif

   let executable=GetDirectoryName()
   call CopyTestExecutable()
   call CopyResourcesToTarget()

   if IsArmProcessor()
      echo KillTests()
      let command=':!ssh ' . GetTransferOptions() . ' ' . GetBoard() . ' ". /etc/profile; export BROKER_IP=\"127.0.0.1\"; ./' . executable . ' ' . gtest_filter[0] . '"'
      exe command . ' 2>&1 | tee /tmp/gtestoutput.txt'
   else
      if IsGCOV()
         let qualifier='LLVM_PROFILE_FILE=' . GetLlvmBuildPath() . 'default.profraw '
      else
         let qualifier=''
      endif
      let command=':!' . qualifier . './build/bin/' . executable . ' ' . gtest_filter[0]
      echo 'GTestOneFixtureOneTest: ' . command
      exe command . ' 2>&1 | tee /tmp/gtestoutput.txt'
   endif

   " echo 'GTestOneFixtureOneTest: ' . command
   " exe command . ' 2>&1 | tee /tmp/gtestoutput.txt'
   " redraw
  exe ':cg /tmp/gtestoutput.txt | copen' 
  redraw
endfunction

"===============================================================================
"
" -- Command to run all of the tests in a test fixture
"
"===============================================================================
function! GTestFixture()
   "
   " -- Verify the fixture and file names match
   "
   if !DoesTestFixtureFilenameMatch()
      let filename=GetFilenameNoExt()
      let error='ERROR: file name and test fixture name do not match: ' . filename
      echo error
      return error
   endif
   "
   " -- Verify there is an executable
   "
   if !DoesTestFixtureHaveExecutable()
      let filename=GetFilenameNoExt()
      let error='ERROR: no executable found for ' . filename
      echo error
      return error
   endif

   let g:currentWindow=winnr()
   let gtest_filter=GTestFilter(0)

   if !gtest_filter[1]
      echo gtest_filter[0]
      return gtest_filter[0]
   endif

   let executable=GetDirectoryName()
   call CopyTestExecutable()

   if IsArmProcessor()
      let command=':!ssh ' . GetBoard() . ' -o HostKeyAlgorithms=+ssh-rsa  ./' . executable . ' ' . gtest_filter[0] 
   else
      if IsGCOV()
         let qualifier='LLVM_PROFILE_FILE=' . GetLlvmBuildPath() . 'default.profraw '
      else
         let qualifier=''
      endif
      let command=':!' . qualifier . './build/bin/' . executable . ' ' . gtest_filter[0]
   endif


   exe command . ' 2>&1 | tee /tmp/gtestoutput.txt'
   redraw
   exe ':cg /tmp/gtestoutput.txt | copen' 
   redraw
endfunction

"===============================================================================
"
" -- Execute all 'build/bin/Test_*' binaries
"
"===============================================================================
function! GTestAllFixtures()
   let g:currentWindow=winnr()
   call CopyTestExecutable()
   call RunAllRemoteTests()
   exec 'cg /tmp/gtestoutput.txt | copen'
endfunction

"===============================================================================
"
" -- Supports legacy TestRunner
"
"===============================================================================
function! GTestTestRunner()
   let g:currentWindow=winnr()
   let gtest_filter=GTestFilter(0)

   if !gtest_filter[1]
      echo gtest_filter[0]
      return gtest_filter[0]
   endif

   let executable=GetDirectoryName()
   call CopyTestExecutable()

   if IsArmProcessor()
      call CopyTestRunner()
      let command=':!ssh ' . GetBoard() . '  -o HostKeyAlgorithms=+ssh-rsa ./TestRunner ' . gtest_filter[0] 
   else
      let command=':!let LLVM_PROFILE_FILE=build/tests/Test_Engine/CMakeFiles/Test_Engine.dir | build/bin/TestRunner ' . gtest_filter[0]
   endif

   exe command . ' 2>&1 | tee /tmp/gtestoutput.txt'
   redraw
   exe ':cg /tmp/gtestoutput.txt | copen' 
   redraw
endfunction

"===============================================================================
"
" -- Supports legacy TestRunner
"
"===============================================================================
function! GTestAllTestRunner()
   call CopyTestExecutable()

   let g:currentWindow=winnr()
   if IsArmProcessor()
      call CopyTestRunner()
      let command=':!ssh ' . GetBoard() . '  -o HostKeyAlgorithms=+ssh-rsa ./TestRunner '
   else
      let command=':!build/bin/TestRunner ' 
   endif

   exe command . ' 2>&1 | tee /tmp/gtestoutput.txt'
   redraw
   exe ':cg /tmp/gtestoutput.txt | copen' 
   redraw
endfunction

"===============================================================================
"
" -- Run python
"
"===============================================================================
function! RunPython()
   let command=':IPythonCellRun' 
   exe command 
endfunction

"===============================================================================
"===============================================================================
function! RestoreEditWindow()
   exe g:currentWindow . "wincmd w"
endfunction

"===============================================================================
"===============================================================================
function! OpenNerdTreePanel()
   let g:currentWindow=winnr()
   if g:NERDTree.IsOpen()
      let g:currentWindow-=1
   else
      let g:currentWindow+=1
   endif
   exec "NERDTreeToggle"
   call RestoreEditWindow()
endfunction

"===============================================================================
"===============================================================================
function! Strip(input_string)
    return substitute(a:input_string, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction

"===============================================================================
"===============================================================================
function! Chomp(string)
    return substitute(a:string, '\n\+$', '', '')
endfunction

"===============================================================================
"===============================================================================
function! TrimStringList(list)
   let i = 0
   let s = len(a:list)
   while i < s
      let a:list[i] = Strip(a:list[i])
      let i += 1
   endwhile
   return a:list
endfunction

"===============================================================================
"===============================================================================
function! BuildDir()
   let s = resolve(expand("./build"))
   let b = split(s, "/")[1]
   return b
endfunction

"===============================================================================
"===============================================================================
function! IsDebug(directoryName)
   let isMatch = 0
   if (a:directoryName ==? "build-x86_64-Linux-Debug")
      let isMatch = 1
      let r = "install-debug.sh"
   endif
   return [ isMatch, r ]
endfunction

"===============================================================================
"===============================================================================
function! IsRelease(directoryName)
   let isMatch = 0
   if (a:directoryName ==? "build-x86_64-Linux-Release")
      let isMatch = 1
      let r = "install-debug.sh"
   endif
   return [ isMatch, r ]
endfunction

"===============================================================================
"===============================================================================
function! IsArmRelease(directoryName)
   let isMatch = 0
   if (a:directoryName ==? "build-Aarch64-Linux-Release")
      let isMatch = 1
      let r = "install-debug.sh"
   endif
   return [ isMatch, r ]
endfunction

"===============================================================================
"===============================================================================
function! GetInstallType()
   let b = BuildDir()

   let r = IsDebug(b)
   if r[0]
      return r[1]
   endif

   let r = IsRelease(b)
   if r[0]
      return r[1]
   endif

   let r = IsArmRelease(b)
   if r[0]
      return r[1]
   endif

endfunction

"===============================================================================
" Common GCOV functions
"===============================================================================

"---------------------------------------------------------------------------------
" returns True if the environment variable CONAN_PROFILE is set to
" 'install-gcov'
"---------------------------------------------------------------------------------
function! IsGCOV()
   let profile=$CONAN_PROFILE
   let substring=stridx(profile,'gcov')
   if substring > 0
      return 1
   endif
   return 0
endfunction

"===============================================================================
" GCOV using 'llvm'
" Uses gtest and CMake
" Works with clang version 10
"===============================================================================

"---------------------------------------------------------------------------------
" returns the test build direcctory
"---------------------------------------------------------------------------------
function! GetTestDirectory()
   if IsGCOV()
      let path='build/bin/' . GetDirectoryName()
      return path
   endif
   return ''
endfunction

"---------------------------------------------------------------------------------
" returns the path to where the default.profraw file is written
"---------------------------------------------------------------------------------
function! GetLlvmProfileFile()
   if IsGCOV()
      let path='let LLVM_PROFILE_FILE="build/tests/' . GetDirectoryName() . '/CMakeFiles/' . GetDirectoryName() . '.dir/"'
      return path
   endif
   return ''
endfunction

"---------------------------------------------------------------------------------
" returns the path to where the default.profraw file is written
"---------------------------------------------------------------------------------
function! GetLlvmBuildPath()
   if IsGCOV()
      let path='build/cov/' . GetDirectoryName() . '/'
      return path
   endif
   return ''
endfunction

"---------------------------------------------------------------------------------
" returns the path to where the default.profraw file is written
"---------------------------------------------------------------------------------
function! GetLlvmHtmlPath()
   if IsGCOV()
      let path=GetLlvmBuildPath() . 'html/'
      return path
   endif
   return ''
endfunction

"---------------------------------------------------------------------------------
" returns 1 if the default.profraw exists otherwise 0
"---------------------------------------------------------------------------------
function! IsProfRawExist()
   if IsGCOV()
      let path=GetLlvmBuildPath() . '/default.profraw'
      let isExist=!empty(expand(path))
      return isExist
   endif
   return 0
endfunction

"---------------------------------------------------------------------------------
" returns 1 if the default.profdata exists otherwise 0
"---------------------------------------------------------------------------------
function! IsProfDataExist()
   if IsGCOV()
      let path=GetLlvmBuildPath() . '/default.profdata'
      let isExist=!empty(expand(path))
      return isExist
   endif
   return 0
endfunction

"---------------------------------------------------------------------------------
" returns 1 if the html files exists otherwise 0
"---------------------------------------------------------------------------------
function! IsHtmlExist()
   if IsGCOV()
      let path=GetLlvmHtmlPath() . '/index.html'
      let isExist=!empty(expand(path))
      return isExist
   endif
   return 0
endfunction

"---------------------------------------------------------------------------------
" returns path to index file including the filename
"---------------------------------------------------------------------------------
function! GetHtml()
   if IsGCOV()
      let repo=fnamemodify(getcwd(), ':t')
      let path='file:///repo/' . repo . '/' . GetLlvmBuildPath() . 'index.html'
      return path
   endif
   return 0
endfunction

"---------------------------------------------------------------------------------
" executes the llvm-profdata merge command to combine all tests
"---------------------------------------------------------------------------------
function! ExecuteLlvmProfdata()
   if IsGCOV() && IsProfRawExist()
      let command=':!llvm-profdata-15 merge ' . GetLlvmBuildPath() . 'default.profraw -o ' . GetLlvmBuildPath() . 'default.profdata'
      silent exe command . ' 2>&1 | tee /tmp/gcov.txt'
      return 1
   endif
   return 0
endfunction

"---------------------------------------------------------------------------------
" executes the llvm-cov show command to html
"---------------------------------------------------------------------------------
function! ExecuteLlvmCovShow()
   if IsGCOV() && IsProfDataExist()
      let command=':!llvm-cov-15 show ' . GetTestDirectory() . ' -instr-profile=' . GetLlvmBuildPath(). 'default.profdata  -format=html --show-branches=count --show-branch-summary -output-dir=' . GetLlvmHtmlPath()
      silent exe command . ' 2>&1 | tee /tmp/gcov.txt'
      return 1
   endif
   return 0
endfunction

"---------------------------------------------------------------------------------
" 
"---------------------------------------------------------------------------------
function! GetListOfFirefoxPids()
   let response=system('pgrep firefox')
   let response=split(response, '\n')
   return response
endfunction

"---------------------------------------------------------------------------------
" 
"---------------------------------------------------------------------------------
function! GetFirefoxWindowId(pid)
   let command='xdotool search --pid ' . a:pid
   let windows=system(command)
   let windows=split(windows, '\n')
   let i=len(windows)
   if i==0
      return -1
   endif
   return windows[i-1]
endfunction

"---------------------------------------------------------------------------------
" 
"---------------------------------------------------------------------------------
function! SetBrowser(pid)
   let g:firefoxPid=a:pid
   return g:firefoxPid
endfunction

"---------------------------------------------------------------------------------
" 
"---------------------------------------------------------------------------------
function! IsGCovBrowser()
   let pids=GetListOfFirefoxPids()
   for pid in pids
      if pid ==# g:firefoxPid
         return pid
      endif
   endfor
   return 0
endfunction

"---------------------------------------------------------------------------------
" 
"---------------------------------------------------------------------------------
function! IsThereAGCovTest()
   if g:firefoxPid != 0
      let pids=GetListOfFirefoxPids()
      for pid in pids
         let window=system('xdotool search --pid ' . g:firefoxPid . ' -name ' . GetHtml() . ' |tail -1')
      endfor
      return system('xdotool windowactivate --sync ' . window)
   endif
   return 0
endfunction

"---------------------------------------------------------------------------------
" display gcov in html
"---------------------------------------------------------------------------------
function! StartFirefox()
   let pid=system('firefox & sleep 2; echo $(pgrep firefox | tail -1)')
   let pid=split(pid, '\n')
   let i=len(pid)
   let g:firefoxPid=pid[i-1]
   let g:firefoxWindow=GetFirefoxWindowId(g:firefoxPid)
   return [g:firefoxPid, g:firefoxWindow]
endfunction

"---------------------------------------------------------------------------------
" 
"---------------------------------------------------------------------------------
function! CreateAFirefoxTab()
   if g:firefoxWindow != 0
      let window=g:firefoxWindow
      let html=GetHtml()
      " let command='xdotool key --window ' . window . ' ctrl+t ; xdotool key --window ' . window . ' ; xdotool key --window ' . window . ' ctrl+l; xdotool key --window ' . window . ' key --delay 250 type ' . html . ' ; xdotool key --window ' . window . ' --delay 100 "Return"'; 
      let command='xdotool key --window ' . window . ' ctrl+t key --delay 50 ctrl+l; xdotool type "' . html . '" ; xdotool key --delay 1000 "Return"'
      echo command
      let result= system(command)
      return result
   endif
   return 0
endfunction

"---------------------------------------------------------------------------------
" 
"---------------------------------------------------------------------------------
function! Return()
   if g:firefoxWindow != 0
      let window=g:firefoxWindow
      let command='xdotool key --delay 250 --window ' . window . ' "Return"'
      call system(command)
      return 1
   endif
   return 0
endfunction

"---------------------------------------------------------------------------------
" Check if any  of the firfox pids are mine. If not, create a new instance. 
" Use the existing tab to grab the html file. 
"---------------------------------------------------------------------------------
function! OpenFirefox()
   if g:firefoxPid !=# g:NO_PID
     let isMatch=0
     let pids=split(system('pgrep firefox'), '\n')
     let command='echo ' . ''.join(pids) . ' > /tmp/firefox.txt'
     silent call system(command)
     for pid in pids
        if pid ==# g:firefoxPid
           let isMatch=1
           break
        endif
     endfor
     if !isMatch
        let g:firefoxPid=g:NO_PID
     endif
   endif
   if g:firefoxPid ==# g:NO_PID
      let g:firefoxPid=system('firefox&')
      let command='echo "restarting firefox" >> /tmp/firefox.txt'
      silent call system(command)
      sleep 3
   endif

   let command='xdotool search -pid ' . g:firefoxPid
   let windows=system(command)
   let window=windows[len(windows)-1]

   let html=GetHtml()
   let command='xdotool key --window ' . window . ' ctrl+t; sleep 0.5; xdotool key --window ' . window . ' ctrl+l; sleep 0.5; xdotool type "' . html . '" ; sleep 0.5; xdotool key "Return"'
   silent call system(command)

   " let command='xdotool key --window ' . window . ' "Return"'
   " silent call system(command)

   redraw!

   return g:firefoxPid
endfunction

function! OpenMidori()
   silent call system('epiphany ' . GetHtml() . ' &')
   redraw!
endfunction

"---------------------------------------------------------------------------------
" 
"---------------------------------------------------------------------------------
function PrintPid()
   return [ g:firefoxPid, g:firefoxWindow]
endfunction

"---------------------------------------------------------------------------------
" display gcov in html
"---------------------------------------------------------------------------------
function! ExecuteBrowser()
   if IsGCOV() && IsHtmlExist()
      call StartFirefox()
      let index=GetHtml()
      let command='xdotool search "Mozilla Firefox" windowactivate --sync key --delay 500 ctrl+l key --delay 250 --clearmodifiers type "' . index . '" ; xdotool key --delay 1000 "Return"'
      call system(command)
      return 1
   endif
   return 0
endfunction

"---------------------------------------------------------------------------------
" executes the llvm-cov show command to html
"---------------------------------------------------------------------------------
function! LlvmGcov()
   if IsGCOV() 
      let isProfData=ExecuteLlvmProfdata()
      if !isProfData
         return -1
      endif
      let isProfHtml=ExecuteLlvmCovShow()
      if !isProfHtml
         return -2
      endif
      return OpenMidori()
      "return OpenFirefox()
   endif
   redraw!
   return 0
endfunction

"===============================================================================
" GCOV using 'lcov' and 'genhtml' 
" Uses gtest and CMake
" Works with clang version 10
" sudo vim /usr/bin/llvm-gcov.sh
"    #!/bin/bash
"    exec llvm-cov-10 gcov "$@"
" sudo chmod +x /usr/bin/llvm-gcov.sh
" ref: https://logan.tw/posts/2015/04/28/check-code-coverage-with-clang-and-lcov/
"===============================================================================

"---------------------------------------------------------------------------------
" CMake binary directory for gtest fixture
"---------------------------------------------------------------------------------
function! GetCMakeBinaryTestDir()
   let testDir=GetDirectoryName()
   let p="build/tests/" . testDir . "/CMakeFiles/" . testDir . ".dir"
   return p
endfunction

"---------------------------------------------------------------------------------
" 'lcov' command using clang. See reference above for /usr/bin/llvm-gcov.sh
" Creates a separate directory for each gtest fixture
"---------------------------------------------------------------------------------
function! GetLcovCommand()
   let testFile=GetFilenameNoExt()
   let lcov="lcov --capture --directory . --base-directory . --gcov-tool llvm-gcov.sh -o " . testFile . ".info"
   return lcov
endfunction

"---------------------------------------------------------------------------------
" 'genhtml' command creates the `index.html' file used later
"---------------------------------------------------------------------------------
function! GetGenHtmlCommand()
   let testFile=GetFilenameNoExt()
   let genhtml="genhtml " . testFile . ".info --output-directory " . testFile
   return genhtml
endfunction

"---------------------------------------------------------------------------------
" 'lcov' appears to require running in in the same directory as the '.gcda' files.
" Using 'cd' to the test directory
"---------------------------------------------------------------------------------
function! GetGcovChangeDirCommand()
   let cd="cd " . GetCMakeBinaryTestDir() 
   return cd
endfunction

"---------------------------------------------------------------------------------
" Combines the change director, the lcov and genhtml commands into one command
"---------------------------------------------------------------------------------
function! GetGcovCommand()
   let command=":!" . GetGcovChangeDirCommand() . " && " . GetLcovCommand() . " && " . GetGenHtmlCommand()
   return command
endfunction

"---------------------------------------------------------------------------------
" The path to the 'index.html' file after genhtml runs
"---------------------------------------------------------------------------------
function! GetTargetGcdaFilename()
   let target="\"" . GetCMakeBinaryTestDir() . "/" . GetFilenameNoExt() . ".gcda\""
   return target
endfunction

"---------------------------------------------------------------------------------
" Checks if lcov can be run. Returns true if it can be run, otherwise false
"---------------------------------------------------------------------------------
function! IsGcovRunnable()
   let isRunnable=!empty(expand(GetTargetGcdaFilename()))
   return isRunnable
endfunction

"---------------------------------------------------------------------------------
" Runs the gcov commands and outputs the results into a temporary file
"---------------------------------------------------------------------------------
function! RunGcovTarget()
   let isRunnable=0
   if IsGcovRunnable()
      let command=GetGcovCommand()
      exe command . ' 2>&1 | tee /tmp/gcov.txt'
      let isRunnable=1
   endif
   return isRunnable
endfunction

"---------------------------------------------------------------------------------
" Returns the name of the genhtml directory
"---------------------------------------------------------------------------------
function! GetGcovTargetDirName()
   let dirName=getcwd() . '/' . GetCMakeBinaryTestDir() . '/' . GetFilenameNoExt() 
   return dirName
endfunction

"---------------------------------------------------------------------------------
" Checks if genhtml was generated. Returns true if the directory exists, 
" otherwise false
"---------------------------------------------------------------------------------
function! IsGcovTargetDir()
   let isExist=!empty(expand(GetGcovTargetDirName()))
   return isExist
endfunction

"---------------------------------------------------------------------------------
" Get the path and filename to 'index.html'
"---------------------------------------------------------------------------------
function! GetGcovTargetIndexHtml()
   if IsGcovTargetDir()
      let indexHtml=GetGcovTargetDirName() . "/index.html"
      return indexHtml
   endif
   return ""
endfunction

"---------------------------------------------------------------------------------
" Check if 'index.html' exists for a test and if true, then open it in firefox
"---------------------------------------------------------------------------------
function! OpenGcovInBrowser(logFilename)
   if IsGcovTargetDir()
      let command=":!firefox " . GetGcovTargetIndexHtml() . ' 2>&1 | tee ' . a:logFilename
      exe command
      return command
   endif
   return 'Error: lcov and/or genhtml data not available'
endfunction

"---------------------------------------------------------------------------------
" Echo the full file name and path to the test's index.html file. Store the 
" results in a temporary file.
"---------------------------------------------------------------------------------
function! EchoIndexHtmlPath(filePathName)
   let command=':!echo ' . GetGcovTargetIndexHtml() . ' > ' . a:filePathName
   exe command
   return command
endfunction

"---------------------------------------------------------------------------------
" Runs all the commands to generate gcov and then opens it in Firefox. The full
" path to the 'index.html' is generated to the quickfix window for convenience 
" should the user wish to open it in another browser.
"---------------------------------------------------------------------------------
function! RunGcovOnTest()
   let g:currentWindow=winnr()
   if g:gcov == 'llvm'
      call LlvmGcov()
   else
      if RunGcovTarget()
         if IsGcovTargetDir()
            let logFilename='/tmp/gcov.txt'
            call OpenGcovInBrowser(logFilename)
            call EchoIndexHtmlPath('/tmp/index.txt')
            exe ':cg /tmp/index.txt | copen' 
         endif
      endif

endfunction

"===============================================================================
"===============================================================================
function! WhichLibrary(filename)
python3 << EOF
#-----------------------------------------
#
# Given a file, find the CMakeLists.txt file.
# Use the set(target... convention to find name of the library
#
import os, vim

try:
   t = vim.eval('a:filename')
   path, filename = os.path.split(t)

   searching_for = 'CMakeLists.txt'
   last_root    = path
   current_root = path
   found_path   = None

   while found_path is None and current_root:
      pruned = False

      for root, dirs, files in os.walk(current_root):
         if not pruned:
            try:
               # Remove the part of the tree we already searched
               del dirs[dirs.index(os.path.basename(last_root))]
               pruned = True
            except ValueError:
               pass

         if searching_for in files:
            # found the file, stop
            found_path = os.path.join(root, searching_for)
            break

      # Otherwise, pop up a level, search again
      last_root    = current_root
      current_root = os.path.dirname(last_root)

   import re

   with open(found_path) as f:
      data = f.read().replace('\n', '')

   p = re.compile('set\(target[ ]*"([a-zA-Z_-]*)"\)')
   m = p.match(data)

   vim.command("let l:libraryName = '%s'" % m.group(1))

except:
   pass

#-----------------------------------------
EOF
   return l:libraryName
endfunction

"
" /\v(TEST_F\([A-Za-z_]*,[ ]*)
"

nnoremap <Leader>n :call OpenNerdTreePanel()<cr>
nnoremap <silent> <Leader>v :NERDTreeFind<CR>

nmap <Leader>ce :!export-package.sh<cr>

inoremap jk <esc>

noremap <Leader>cc :!cd build; make clean; cd ..; conan build .<cr>
noremap <Leader>ce :!cd build; make clean; cd ..; conan build .; export-package.sh<cr>

map <F1> :ccl <bar>call RestoreEditWindow()<cr>
map <F2> :w <bar>call GTestOneFixtureOneTest()<cr><cr>
map <F3> :w <bar>call GTestFixture()<cr><cr>
map <F4> :w <bar>call GTestAllFixtures()<cr>
map <F5> :w <bar>call BuildTestFixture()<cr>
map <F6> :w <bar>call GTestTestRunner()<cr><cr>
map <F7> :w <bar>call GTestAllTestRunner()<cr><cr>
map <F8> :w <bar>call RunPython()<cr>
map <F9> :w <bar>echo LlvmGcov()<cr><cr><cr>
" map <F9> :w <bar>echo RunGcovOnTest()<cr><cr><cr>
map <F10> :w <bar>call BuildAll()<cr>
map <F11> :IPythonCellRestart<cr>

noremap <Leader>c :noh<cr>
noremap <Leader>d :split<bar> YcmCompleter GoToDeclaration<cr>
noremap <Leader>f :YcmCompleter FixIt<cr>
noremap <Leader>n :tabnew<bar>:copen<cr><bar><C-w>_<cr>
noremap <Leader>q :q<cr>
noremap <Leader>w :w<cr>
noremap <Leader>r :split<bar> YcmCompleter GoToReferences<cr>

nnoremap <leader>i :tabnew<bar>call OpenNerdTreePanel()<CR>
nnoremap <leader>D :tabclose<CR>

nnoremap ]l :lnext<CR>
nnoremap [l :lprev<CR>

nmap <C-h> <C-w>h
nmap <C-j> <C-w>j
nmap <C-k> <C-w>k
nmap <C-l> <C-w>l

" " window
nmap <leader>wh :topleft  vnew<CR>
nmap <leader>wl :botright vnew<CR>
nmap <leader>wk :topleft  new<CR>
nmap <leader>wj :botright new<CR>
" buffer
nmap <leader>s<left>   :leftabove  vnew<CR>
nmap <leader>s<right>  :rightbelow vnew<CR>
nmap <leader>s<up>     :leftabove  new<CR>
nmap <leader>s<down>   :rightbelow new<CR>

