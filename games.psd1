# Games whose saves saveshim (Install-Saveshim.ps1) redirects to a per-user folder.
# The paths below are where GOG Galaxy installs games, with Galaxy in its
# default C:\Program Files (x86) or in C:\Program Files. A game whose folder
# is not on this PC is skipped with a warning, so entries for games you don't
# have can stay.
#
# One entry per save folder:
#   Name           Short name, used for messages and the compatibility fix.
#                  Letters, digits, '-' and '_' only.
#   Exe            File name of the program that writes the saves (for GOG
#                  games: the primary playTask in goggame-*.info). Several
#                  games may have the same Exe (e.g. scummvm.exe); the script
#                  combines them into one fix.
#   SavePath       Full path of the save folder inside the game folder.
#                  CHECK THIS: Galaxy and the offline installer use
#                  different game folders. Either one path, or a list of
#                  the places the game may be in, @('...', '...'); the
#                  first one whose game folder exists is used.
#   UserStore      Where each user's saves go. Use these placeholders, which
#                  are filled in per user:
#                    %USERPROFILE%   the user's folder, e.g. C:\Users\<user>
#                    %USERNAME%      the account name, e.g. <user>
#                    %USERAPPDATA%   %USERPROFILE%\AppData\Roaming
#                  Examples:
#                    '%USERAPPDATA%\Pharaoh\Saves'
#                    'D:\savegames\%USERNAME%\Pharaoh'
#   RelativePaths  Optional, default $false. $true if the game asks for short
#                  paths like "Save\file.sav" instead of the full path.
#                  Pharaoh does, so it needs $true.
@{
    Games = @(
        @{
            Name          = 'Pharaoh'
            Exe           = 'Pharaoh.exe'
            SavePath      = @(
                'C:\Program Files (x86)\GOG Galaxy\Games\Pharaoh Gold\Save'
                'C:\Program Files\GOG Galaxy\Games\Pharaoh Gold\Save'
            )
            UserStore     = '%USERAPPDATA%\Pharaoh\Saves'
            RelativePaths = $true
        }

        # ScummVM games: SavePath is the savepath= line in the game's .ini
        # (next to the game). Each game gets its own folder under ScummVM's
        # own default save folder.
        @{
            Name          = 'Kyrandia'
            Exe           = 'scummvm.exe'
            SavePath      = @(
                'C:\Program Files (x86)\GOG Galaxy\Games\Legend of Kyrandia\DAT\saves'
                'C:\Program Files\GOG Galaxy\Games\Legend of Kyrandia\DAT\saves'
            )
            UserStore     = '%USERAPPDATA%\ScummVM\Saved games\Kyrandia'
        }
    )
}
