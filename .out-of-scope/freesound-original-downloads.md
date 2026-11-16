# Freesound original-file downloads

Meme sound browsing saves Freesound's HQ preview (an mp3 of about 128 kbps), not the uploader's original file.

## Why this is out of scope

Freesound serves originals only through OAuth2. That means a browser login, a stored refresh token in sops or user state, and a refresh path that can break silently. Previews need just the API key that's already in sops.

The sounds are short meme and soundboard clips, mostly played through Discord, which re-encodes voice audio at a lower bitrate anyway. A 128 kbps preview is indistinguishable there, so the extra auth machinery buys nothing audible.

Reopen this if a specific saved preview audibly suffers (clipping, artefacts) where the original wouldn't.

## Prior requests

- HefKer/nixos-issues#153: "memes: Freesound OAuth2 for original-quality sound downloads"
