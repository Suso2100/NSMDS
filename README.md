#-NSMDS-#

NSMDS (Not SteamModed) is an experimental mod loader and framework for Android builds of Balatro created using Balatro Mobile Maker.

Requires LÖVE Portable and Balatro Mobile Maker.

#-INSTALLATION-#

Step 1. Extract Balatro.exe from your game directory.

Step 2. Add the core folder in the same folder as main.lua.

Step 3. Add `require "core/loader"` near the beginning of main.lua.

Step 4. Add `NSMDS.load_mods()` inside of `function love.load()`, before `G:start_up()`.

Step 5. Add `t.externalstorage = true` inside of `function love.conf(t)` inside of conf.lua.

Step 6. Zip all the files and rename the .zip file to .love instead of .zip.

Step 7. Append the .love file to Love.exe to create a fused executable.

Step 8. Rename the resulting .exe to Balatro.exe.

Step 9. Use Balatro Mobile Maker to make an .apk file using that .exe.

Step 10. Enjoy!


#-USAGE-#

Go to Data/com.unofficial.balatro

Search for the "mods" folder.

Put all your mods in that folder.

Restart Balatro.

Enjoy!

#-REQUIRED ACTIONS-#

Inside of Data/com.unofficial.balatro/files/save/game create "nsmds" folder

Inside of /nsmds folder create "disable_mods"

This is for disable mods inside of the game

IS AN EXPERIMENTAL VERSION, THIS MAY CAUSE CRASHES AND BUGS
