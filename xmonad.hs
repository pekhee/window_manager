import           System.Posix.Env (getEnv)
import           System.IO
import           Graphics.X11.ExtraTypes.XF86
import           Data.Word (Word32, Word64)

import           Data.Monoid (All)
import           XMonad

import           XMonad.Config.Desktop
import           XMonad.Config.Gnome
import           XMonad.Config.Kde
import           XMonad.Config.Xfce

import           XMonad.Layout.LayoutModifier (ModifiedLayout)
import           XMonad.Layout.NoBorders
import           XMonad.Layout.Fullscreen
import           XMonad.Layout.Grid
import           XMonad.Layout.ResizableTile

import           XMonad.Hooks.ManageDocks
import           XMonad.Hooks.DynamicLog

import           XMonad.Util.EZConfig
import           XMonad.Util.Run (spawnPipe)

import qualified XMonad.StackSet as W

myModMask :: KeyMask
myModMask = mod4Mask -- use the Windows key as mod

myBorderWidth :: Word32
myBorderWidth = 2        -- set window border size

myTerminal :: String
myTerminal = "gnome-terminal"  -- preferred terminal emulator

--
-- key bindings
--

myKeys :: [((KeyMask, KeySym), X ())]
myKeys = [
   ((myModMask, xK_d), spawn "dmenu_run")        -- For running apps
 , ((myModMask, xK_a), sendMessage MirrorShrink) -- for  ResizableTall
 , ((myModMask, xK_z), sendMessage MirrorExpand) -- for  ResizableTall
 ]

-- key bindings used only in stand alone mode (without KDE)
myStandAloneKeys :: [((KeyMask, KeySym), X ())]
myStandAloneKeys = [
   ((myModMask, xK_x),             spawn "xscreensaver-command -lock")
 , ((0, xF86XK_MonBrightnessUp),   spawn "xbacklight -inc 10")
 , ((0, xF86XK_MonBrightnessDown), spawn "xbacklight -dec 10")
 , ((0, xF86XK_AudioRaiseVolume),  spawn "amixer -D pulse sset Master 10%+")
 , ((0, xF86XK_AudioLowerVolume),  spawn "amixer -D pulse sset Master 10%-")
 , ((0, xF86XK_AudioMute),         spawn "amixer -D pulse sset Master toggle")
 ]

--
-- hooks for newly created windows
--

myManageHook :: ManageHook
myManageHook = composeAll [manageDocks, fullscreenManageHook, coreManageHook]

coreManageHook :: ManageHook
coreManageHook = composeAll . concat $
  [ [ className   =? c --> doFloat           | c <- myFloats]
  , [ className   =? c --> doF (W.shift "9") | c <- mailApps]
  ]
  where
    myFloats      = [
       "MPlayer"
     , "Gimp"
     , "Plasma-desktop"
     , "plasmashell"
     , "Klipper"
     , "Keepassx"
     ]
    mailApps      = ["Thunderbird"]

--
-- startup hooks
--

myStartupHook :: X ()
myStartupHook = return ()

--
-- layout hooks
--

myLayoutHook = lessBorders Screen $ fullscreenFull $ avoidStruts coreLayoutHook

coreLayoutHook :: Choose ResizableTall (Choose (Mirror ResizableTall) (Choose Full Grid)) a
coreLayoutHook = tiled ||| Mirror tiled ||| Full ||| Grid
  where
    -- default tiling algorithm partitions the screen into two panes
    tiled   =  ResizableTall nmaster delta ratio []
    -- The default number of windows in the master pane
    nmaster = 1
    -- Default proportion of screen occupied by master pane
    ratio   = 1/2
    -- Percent of screen to increment by when resizing panes
    delta   = 3/100

--
-- event hook
--

myEventHook :: Event -> X Data.Monoid.All
myEventHook = composeAll [fullscreenEventHook, docksEventHook]

--
-- log hook (for xmobar)
--

myLogHook :: Handle -> X ()
myLogHook xmproc = dynamicLogWithPP xmobarPP
  { ppOutput = hPutStrLn xmproc
  , ppTitle  = xmobarColor "green" "" . shorten 50
  }

-- desktop :: String -> XConfig
desktop :: String -> XConfig (ModifiedLayout AvoidStruts (Choose Tall (Choose (Mirror Tall) Full)))
desktop "gnome"         = gnomeConfig
desktop "xmonad-gnome"  = gnomeConfig
desktop "kde"           = kde4Config
desktop "kde-plasma"    = kde4Config
desktop "plasma"        = kde4Config
desktop "xfce"          = xfceConfig
desktop _               = desktopConfig

xmobarFor :: Integer -> IO Handle
xmobarFor n = spawnPipe $ "/usr/bin/xmobar ~/.xmonad/xmobar.hs -x " ++ show n

--
-- main function (no configuration stored there)
--

main :: IO ()
main = do
  session <- getEnv "DESKTOP_SESSION"
  let defDesktopConfig = maybe desktopConfig desktop session
      myDesktopConfig = defDesktopConfig
        { modMask         = myModMask
        , borderWidth     = myBorderWidth
        , startupHook     = myStartupHook
        , layoutHook      = myLayoutHook
        , manageHook      = myManageHook <+> manageHook defDesktopConfig
        , handleEventHook = myEventHook
        } `additionalKeys` myKeys

  mproc0 <- xmobarFor 0
  mproc1 <- xmobarFor 1

  xmonad $ myDesktopConfig
    { logHook  = myLogHook mproc0 <+> myLogHook mproc1
    , terminal = myTerminal
    } `additionalKeys` myStandAloneKeys
