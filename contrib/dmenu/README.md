`passmenu` is a [dmenu][]-based interface to [pass][], the standard Unix
password manager. This design allows you to quickly copy a password to the
clipboard without having to open up a terminal window if you don't already have
one open. If `--type` is specified, the password is typed using [xdotool][]
instead of copied to the clipboard.

On wayland [dmenu-wl][] is used to replace dmenu and [ydotool][] to replace xdotool.
Note that the latter requires access to the [uinput][] device, so you'll probably
need to add an extra udev rule or similar to give certain non-root users permission.

# Usage

    passmenu [--type] [dmenu arguments...]

[dmenu]: http://tools.suckless.org/dmenu/
[xdotool]: http://www.semicomplete.com/projects/xdotool/
[pass]: http://www.zx2c4.com/projects/password-store/
[dmenu-wl]: https://github.com/nyyManni/dmenu-wayland
[ydotool]: https://github.com/ReimuNotMoe/ydotool
[uinput]: https://www.kernel.org/doc/html/v4.12/input/uinput.html
