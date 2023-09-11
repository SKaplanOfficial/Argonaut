#@osa-lang:AppleScript
(*
 * Example script utilizing the Argonaut library.
 *
 * Controls Music.app using simple command-line arguments.
 *
 * To invoke:
 * Play next song or resume playback: osascript MusicController.scpt play
 * Skip to next song: osascript MusicController.scpt skip
 * Play a specific song: osascript MusicController.scpt play "Don't Stop Believin'"
 * Begin playing a playlist: osascript MusicController.scpt play -p "Classical Music"
 * Get information about a song: osascript MusicController.scpt -s "Don't Stop Believin'" -i
 * Get information about a playlist: osascript MusicController.scpt -p "Classical Music" -i
 * Export a playlist to a file: osascript MusicController.scpt -p "Classical Music" -e ~/Downloads/classical -f xml
 * Dumb export data to the Terminal without writing to a file: osascript MusicController.scpt -p "Classical Music" -d
 * Export to file AND dump to Terminal: osascript MusicController.scpt -e ~/Downloads/classical -p "Classical Music" -f txt -d
 *)

use script "Argonaut" version "1.0"

script ResultHandler
	property nl : "
"

	on playSong(songTitle)
		try
			tell application "Music" to play track songTitle
		end try
	end playSong

	on playPlaylist(playlistName)
		try
			tell application "Music" to play playlist playlistName
		on error err
			log err
		end try
	end playPlaylist

	on getSongInfo(songTitle)
		try
			tell application "Music"
				if songTitle is missing value then
					try
						set theSong to current track
					on error
						log "No song currently playing."
						return
					end try
				else
					set theSong to track songTitle
				end if
				return "Song:		" & songTitle & nl & "Artist:		" & (get theSong's artist) & nl & "Album:		" & (get theSong's album) & nl & "Year:		" & (get theSong's year) & nl & "Duration:	" & (get theSong's time)
			end tell
		on error err
			log err
		end try
		return ""
	end getSongInfo

	on getPlaylistInfo(playlistName)
		try
			tell application "Music"
				set thePlaylist to playlist playlistName
				return "Playlist:	" & playlistName & nl & "# of Tracks:	" & (count thePlaylist's tracks) & nl & "Duration:	" & (get thePlaylist's time)
			end tell
		on error err
			log err
		end try
		return ""
	end getPlaylistInfo

	on exportPlaylist(playlistName, theFormat, destination)
		try
			tell application "Music"
				set exportDestination to destination as text
				set exportFormat to M3U8

				ignoring case
					if theFormat is "text" or theFormat is "txt" then
						set exportFormat to plain text
						if exportDestination is not "missing value" and exportDestination does not end with ".txt" then
							set exportDestination to exportDestination & ".txt"
						end if
					else if theFormat is "unicode" then
						set exportFormat to Unicode text
						if exportDestination is not "missing value" and exportDestination does not end with ".txt" then
							set exportDestination to exportDestination & ".txt"
						end if
					else if theFormat is "xml" then
						set exportFormat to XML
						if exportDestination is not "missing value" and exportDestination does not end with ".xml" then
							set exportDestination to exportDestination & ".xml"
						end if
					else if theFormat is "m3u" then
						set exportFormat to M3U
						if exportDestination is not "missing value" and exportDestination does not end with ".m3u" then
							set exportDestination to exportDestination & ".m3u"
						end if
					else if exportDestination is not "missing value" and exportDestination does not end with ".m3u8" then
						set exportDestination to exportDestination & ".m3u8"
					end if
				end ignoring

				set thePlaylist to playlist playlistName
				if exportDestination as text is "missing value" then
					return (export thePlaylist as exportFormat)
				else
					export thePlaylist as exportFormat to exportDestination
				end if
			end tell
		on error err
			log err
		end try
		return ""
	end exportPlaylist

	on handle(args, theSummary)
		set output to ""

		set infoArg to item 3 of (list arguments)
		if infoArg's status's state is valid then
			if theSummary's song is not "" then
				set output to getSongInfo(theSummary's song)
			else
				if theSummary's playlist is "" then
					set output to getSongInfo(missing value)
				end if
			end if

			if theSummary's playlist is not "" then
				if theSummary's song is not "" then
					set output to output & nl & nl
				end if
				set output to output & getPlaylistInfo(theSummary's playlist)
			end if
		end if

		set dumpArg to item 6 of (list arguments)
		if dumpArg's status's state is valid then
			if output is not "" then
				set output to output & nl & nl
			end if
			set output to output & exportPlaylist(theSummary's playlist, theSummary's format, missing value)
		end if

		if theSummary's export is not "" then
			exportPlaylist(theSummary's playlist, theSummary's format, theSummary's export)
		end if

		if theSummary's command is "open" then
			tell application "Music" to activate
		else if theSummary's command is "play" and theSummary's song is not "" then
			playSong(theSummary's song)
		else if theSummary's command is "play" and theSummary's playlist is not "" then
			playPlaylist(theSummary's playlist)
		else if theSummary's command is "play" then
			tell application "Music" to play
		else if theSummary's command is "skip" then
			tell application "Music" to next track
		else if theSummary's command is "pause" then
			tell application "Music" to pause
		else if theSummary's command is "stop" then
			tell application "Music" to stop
		else if theSummary's command is "quit" then
			tell application "Music" to quit
		end if
		return output
	end handle
end script

on run argv
	add argument "command" help text "The command to invoke on Music.app." accepted values {"open", "play", "skip", "pause", "stop", "quit"} without required
	add argument "song" flag "s" help text "The title of the song to play or get information about." without required
	add argument "info" flag "i" type ArgFlag help text "Gets info about a song, playlist, or the current track (default)" without required
	add argument "playlist" flag "p" help text "The name of the playlist to play or get information about." without required
	add argument "export" flag "e" type ArgPath help text "Exports a playlist as an M3U8 file (or another format if specified using --format)" without required
	add argument "dump" flag "d" type ArgFlag dependencies {"playlist"} help text "Dump export data to the Terminal instead of writing it to a file." without required
	add argument "format" flag "f" accepted values {"text", "txt", "unicode", "xml", "m3u", "m3u8", "XML", "M3U", "M3U8"} dependencies {"playlist"} help text "The format to export a playlist in." without required

	set config to {command name:"Music Controller", short description:"A terminal interface for controlling Music.app and querying basic information from it."}
	initialize argument parser configuration config

	if class of argv is not list then
		error "This script must be run from the commandline"
	end if
	handle arguments argv when no errors ResultHandler
end run