#!/bin/bash

# Blackmagic DeckLink SDK headers — for FFmpeg's decklink output muxer (-f decklink).
# Headers committed in-tree at decklink-sdk/include/ (private fork; not redistributed).
# Only applies to Windows targets — that's where the broadcast playout box runs.

ffbuild_enabled() {
    [[ $TARGET == win* ]] || return -1
    return 0
}

# No download — headers are committed in-repo.
ffbuild_dockerdl() {
    return 0
}

# Skip the standard download/build flow; copy headers directly into the build prefix.
ffbuild_dockerstage() {
    to_df "COPY --link decklink-sdk/include/. \$FFBUILD_DESTPREFIX/include/"
}

ffbuild_configure() {
    echo --enable-decklink
}

ffbuild_unconfigure() {
    echo --disable-decklink
}
