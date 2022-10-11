"===============================================================================
"
"
"  :unlet g:CPP_DEV_Version | runtime! plugin/cpp-dev.vim
"
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

let g:currentWindow=winnr()

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
"===============================================================================
function! ConanArch()
   let arch=trim(system('grep -m 1 "^[ ]*arch=" conaninfo.txt | cut -d''='' -f2'))
   return arch
endfunction

"===============================================================================
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
   let command=":!ssh " . GetBoard() . " \"pidof " . a:process . " | xargs kill -9"
   exe command 
endfunction

"
" -- Copy the executable corresponding to the test directory name
"    to the ARM processor
"
"===============================================================================
function! CopyTestExecutable()
   if IsArmProcessor()
      if !DoesTestFixtureHaveExecutable()
         return 'no executable'
      endif
      let command=':!scp build/bin/' . GetDirectoryName() . ' ' . GetBoard() . ':'
      exe command . ' 2>&1 | tee /tmp/vim-log.txt'
      redraw
      return "success"
   endif
   return 'Not an Arm processor'
endfunction

"===============================================================================
"
" -- Copy the all test executables to the ARM processor
"
"===============================================================================
function! CopyAllTestExecutables()
   if IsArmProcessor()
      let command=':!sshpass -p "abcd123" scp build/bin/Test_* ' . GetBoard() . ':'
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
      let command=':!sshpass -p "abcd123" scp build/bin/TestRunner ' . GetBoard() . ':'
      exe command
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
" -- Command to copy the resources directory to the ARM processor
"
"===============================================================================
function! CopyResourcesDirCommand()
   if IsArmProcessor()
      let command=':!sshpass -p "abcd123" scp -r resources/ ' . GetBoard() . ':'
      exec command
      redraw
      return 'succeeded'
   endif
   return 'Not an Arm processor'
endfunction

"===============================================================================
"
" -- Copy the entire resources directory to ARM processor
"
"===============================================================================
function! CopyResourcesToTarget()
   if IsArmProcessor()
      if IsResourcesDir()
         call CopyResourcesDirCommand()
      endif
      call CopyAllTestExecutables()
      return 'succeeded'
   endif
   return 'Not an Arm processor'
endfunction

"===============================================================================
"
" -- Generate the command to run all 'build/bin/Test_*' binaries
"
"===============================================================================
function! RunAllRemoteTests()
   if IsArmProcessor()
      let command='!sshpass -p "abcd123" ssh ' . GetBoard() . ' "find -type f -name \"Test_*\" -exec {} \;"'
   else
      let command='!find build/bin -type f -name "Test_*" -exec {} \;'
   endif
   return command
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

   if IsArmProcessor()
      call CopyTestExecutable()
      let command=':!ssh ' . GetBoard() . ' ". /etc/profile; export BROKER_IP=\"127.0.0.1\"; ./' . executable . ' ' . gtest_filter[0] . '"'
   else
      let command=':!./build/bin/' . executable . ' ' . gtest_filter[0]
   endif

   exe command . ' 2>&1 | tee /tmp/gtestoutput.txt'
   redraw
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

   if IsArmProcessor()
      let file=CopyTestExecutable()
      let command=':!ssh ' . GetBoard() . ' ./' . executable . ' ' . gtest_filter[0] 
   else
      let command=':!./build/bin/' . executable . ' ' . gtest_filter[0]
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
   let command=RunAllRemoteTests()
   exec command . " 2>&1 | tee /tmp/gtestoutput.txt"
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

   if IsArmProcessor()
      call CopyTestRunner()
      let command=':!ssh ' . GetBoard() . ' ./TestRunner ' . gtest_filter[0] 
   else
      let command=':!build/bin/TestRunner ' . gtest_filter[0]
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
   let g:currentWindow=winnr()
   if IsArmProcessor()
      call CopyTestRunner()
      let command=':!ssh ' . GetBoard() . ' ./TestRunner '
   else
      let command=':!build/bin/TestRunner ' 
   endif

   exe command . ' 2>&1 | tee /tmp/gtestoutput.txt'
   redraw
   exe ':cg /tmp/gtestoutput.txt | copen' 
   redraw
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
map <F8> :w <bar>echo CopyResourcesToTarget()<cr><cr><cr>
map <F10> :w <bar>call BuildAll()<cr>

noremap <Leader>c :noh<cr>
noremap <Leader>d :split<bar> YcmCompleter GoToDeclaration<cr>
noremap <Leader>f :YcmCompleter FixIt<cr>
noremap <Leader>n :tabnew<bar>:copen<cr><bar><C-w>_<cr>
noremap <Leader>q :q<cr>
noremap <Leader>w :w<cr>
noremap <Leader>r :split<bar> YcmCompleter GoToReferences<cr>

nnoremap <leader>i :tabnew<bar>call OpenNerdTreePanel()<CR>
nnoremap <leader>D :tabclose<CR>

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

