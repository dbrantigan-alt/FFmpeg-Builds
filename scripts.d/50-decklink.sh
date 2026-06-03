#!/bin/bash

# Blackmagic DeckLink SDK — Win .idl files compiled via widl (MinGW's IDL
# compiler, equivalent to Microsoft's MIDL) at docker build time.
#
# ffmpeg's libavdevice/decklink_common.cpp, when targeting Windows, includes
# `DeckLinkAPI_i.c` (the MIDL-generated UUID table) and expects
# Windows-style COM types (HRESULT, REFIID via guiddef.h, not LinuxCOM.h
# shims). The Linux SDK headers don't satisfy this — they define COM types
# in conflicting ways and don't ship an _i.c file. Using widl on the Win
# .idl files produces the correct Windows headers + UUID file for cross-
# compile via MinGW.
#
# SDK files committed at decklink-sdk/idl/ in-tree (private fork; the SDK is
# not redistributable so this repo must stay private).

ffbuild_enabled() {
    [[ $TARGET == win* ]] || return -1
    return 0
}

ffbuild_dockerdl() {
    return 0
}

ffbuild_dockerstage() {
    # Stage .idl files in a temp dir, compile with widl, install outputs into
    # the build include prefix. widl is in mingw-w64-tools, available in the
    # BtbN base-win64 image's MinGW toolchain.
    to_df 'COPY --link decklink-sdk/idl /tmp/decklink-idl'
    to_df 'RUN set -xe && cd /tmp/decklink-idl && \\'
    to_df '    widl -h -H DeckLinkAPI.h DeckLinkAPI.idl && \\'
    to_df '    widl -u -U DeckLinkAPI_i.c DeckLinkAPI.idl && \\'
    to_df '    mkdir -p "$FFBUILD_DESTPREFIX/include" && \\'
    to_df '    cp DeckLinkAPI.h DeckLinkAPI_i.c DeckLinkAPIVersion.h "$FFBUILD_DESTPREFIX/include/" && \\'
    to_df '    rm -rf /tmp/decklink-idl'
}

ffbuild_configure() {
    # --enable-nonfree is required: Decklink links against Blackmagic's
    # proprietary SDK, which makes the resulting binary non-redistributable.
    # Acceptable for our private internal use (broadcast playout box).
    echo --enable-decklink
    echo --enable-nonfree
}

ffbuild_unconfigure() {
    echo --disable-decklink
}
