# NSMDS
NSMDS (Not SteamModed) is an experimental mod loader and framework for Android builds of Balatro created using Balatro Mobile Maker.
Require LÖVE portable and Balatro mobile maker


#-INSTALATION-#

Step 1. Extract Balatro.exe from your game directory
Step 2. Add the core folder in the same folder of main.lua
Step 3. Add 'require "core/loader"' in the second line of main.lua
Step 4. Add 'NSMDS.load_mods()' inside of 'function love.load()' before 'G:start_up()'
Step 5. zip all the files and rename to .love instead of .zip
Step 6. Copy the data of the .love to Love.exe
Step 7. Rename the .exe to Balatro.exe
step 8. Use Balatro Mobile Maker to make a .apk file using that .exe
step 9. Enjoy


#-USAGE-#
Go to Data/com.unnoficial.balatro
Search for the "mods" folder
Put all the mods in that folder
Restart Balatro
Enjoy
