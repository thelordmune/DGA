_G.__DEV__ = game:GetService('RunService'):IsStudio()

local REQUIRED_MODULE = require(script._Index['ytrev_replion@2.0.0-rc.1']['replion'])
export type ServerReplion<T = any> = REQUIRED_MODULE.ServerReplion<T>
export type ClientReplion<T = any> = REQUIRED_MODULE.ClientReplion<T>
return REQUIRED_MODULE
