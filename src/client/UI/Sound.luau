--!strict
-- UI sound hook. AudioController installs the real player at startup so UI
-- components can make sound without depending on the audio system.
local Sound = {}

Sound.play = function(_name: string) end :: (name: string) -> ()

return Sound
