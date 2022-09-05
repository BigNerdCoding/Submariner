# Submariner

Submariner is a Subsonic client for Mac. Originally developed by Rafaël Warnault, it was no longer maintained, and in 2012, he released it under a 3-clause BSD license.

As of 2022, I (Calvin Buckley) am fixing it up for modern macOS and Subsonic implementations. The goal is fix issues regarding compatibility, fix old bugs, add new features, modernize the application, and see what direction it should be taken in with Rafaël.

Please see the [old README](https://github.com/Read-Write/Submariner/blob/a1a10eb131eda3a073dab69423065464e9fab3ac/README.md) for past details.

## Building

1. Clone recursively (i.e. `git clone --recursive`). Failing that, initialize submodules recursively (`git submodule update --init --recursive`).

2. You need to build SFBAudioEngine's dependencies first. `cd SFBAudioEngine` and then `make -C XCFrameworks`.

3. Use Xcode or `xcbuild` to build.

## Third-Party

This project includes the following libraries via a submodule:

* SFBAudioEngine by Stephen F. Booth ([https://github.com/sbooth/SFBAudioEngine](https://github.com/sbooth/SFBAudioEngine))

More libraries are vendored (...and likely outdated), see copyright headers on files.

## Release Notes:

### Version x.x (likely, 2.0)

Note there is still much to be done before a release.

* Now requires macOS 11.x
* Overhauled UI to fit modern macOS design and UI conventionsa
  * Basic dark mode support
  * SF Symbols for UI elements
  * Tracklist and now playing view moved to sidebar
  * Expanded menu bar
* Uses App Sandboxing
* Remembers last opened view
* Updates tracks from server
* Uses disc numbers for sorting
* Updated to to latest version of SFBAudioEngine, and uses AVFoundation instead of QuickTime
* Notifications for currently playing track
* Use MPNowPlayingInformationCenter instead instead of a menu applet and hooking system media keys
* Now uses built-in NSURLSession instead of library for HTTP connections
* Uses NSPopover instead of MAAttachedWindow
* Informs the local server about playing cached tracks
* Uses Subsonic token auth
* Refactored to use ARC instead of GC

### Version 1.1:

* Add Lossless support for local player.
* Add Mini-Player Menu, callable via a customizable hot-key shortcut.
* Add Max Cover Size setting.
* Add zoom setting for album browser views.
* Improve authentication by supporting password encoding.
* Improve global design, navigation and frame persistence.
* Improve player progress bar stability and design.
* Improve Track-list design.
* Improve cache-streaming engine stability.
* Improve general speed, around 20% faster.
* Fix bug in "Import Audio Files" feature when "Link" option is chosen.
* Fix special character bug in server password.
* Fix memory leaks around REST API

### Version 1.0:

* Initial release.
