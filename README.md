# jkbar-i3

A Quickshell Bar for i3 WM

This is a pet project I built for my i3 desktop as an alternative to Polybar. 

My goal was to keep this bar light in resources.

I wanted something a little more modern that I could enjoy in an X11 environment.

New:  

* Wallpaper selector now has right-click preview window.  Both wallpaper drawer and preview closes when clicking outside of the drawer.

* Wallpaper selector will auto scroll when mouse hovers within 50px of either the right or left edge of the gallery display.

* Wallpaper Drawer and Control Centre Popup has a light-box effect when opened if using picom with blur.

* Improvements to general aesthetics and colours.

* Added full colour Emojis for the bar items and weather module.

* Buttons now have a hover glow effect when moused over.

* Added Brightness Control to the Control Center

* Activate brightnessctl if the slider isn't working:

			# 1. Add your user account to BOTH permissions groups required by Debian/MX Linux
			sudo usermod -aG video,input $USER
			
			# 2. Grant brightnessctl native system execution privileges so it bypasses group lockouts
			sudo chmod +s $(which brightnessctl)


Dependencies:  Quickshell, JetBrainsMono Nerd Font, jq (for layout switcher), feh (for wallpaper), gsimplecal (calendar when righ-clicking clock), pavucontrol (for right-click volume).
  xdotool (for active window), brightnessctl, redshift

The obvious minimum requirements:  BSPWM, sxhkd, rofi, a polkit (ie, lxpolkit, or mate-polkit), and a working config of course.

Make a folder in your config directory (ie - ~/.config/i3/jkbar) and extract the qml files there.

Add this to your i3 config:  

			
			exec_always --no-startup-id qs -p ~/.config/i3/jkbar/shell.qml -d -n >/dev/null 2>&1

My video featuring JKBar can be found here:

https://www.youtube.com/watch?v=hHRG6Z3KZpc

* For full color Emojis in the bar use "Twemoji Mozilla" fonts.

* To install them, open your terminal & add these lines:

      mkdir ~/.local/share/fonts

      wget -O ~/.local/share/fonts/TwemojiMozilla.ttf https://github.com/mozilla/twemoji-colr/releases/download/v0.7.0/Twemoji.Mozilla.ttf

      clear cache:  fc-cache -fv

* JKBar was created for my own personal use, however anyone is free to use it, but I don't have time to offer support or hold someone's hand to set it up.
  But, if you know your way around a little scripting or an AI prompt, this can serve as a pretty good starting point for customizing your own quickshell bar
  as this code may need some tweaking to suit your own unique environment.
 

