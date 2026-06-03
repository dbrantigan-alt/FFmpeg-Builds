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
    # Stage .idl files, install widl, compile to Win-style .h + _i.c headers,
    # install into FFBUILD_DESTPREFIX/include. On Ubuntu 24.04+ widl was moved
    # out of mingw-w64-tools; we try mingw-w64-tools + wine (the base image
    # already has wine but with no widl in /usr/bin), then locate widl via
    # find. Falls back loudly with diagnostic info if widl can't be located.
    to_df 'COPY --link decklink-sdk/idl /tmp/decklink-idl'
    to_df 'RUN set -xe && \\'
    to_df '    apt-get update -o Acquire::AllowInsecureRepositories=true && \\'
    to_df '    apt-get install -y --no-install-recommends --allow-unauthenticated mingw-w64-tools 2>&1 | tail -5 && \\'
    to_df '    (apt-get install -y --no-install-recommends --allow-unauthenticated wine64-tools 2>&1 | tail -3 || true) && \\'
    to_df '    rm -rf /var/lib/apt/lists/* && \\'
    to_df '    WIDL=$(command -v widl 2>/dev/null || find /usr /opt -name "widl" -type f -executable 2>/dev/null | head -1) && \\'
    to_df '    if [ -z "$WIDL" ]; then \\'
    to_df '        echo "=== ERROR: widl not found ===" >&2 && \\'
    to_df '        echo "=== Installed mingw/wine packages: ===" >&2 && \\'
    to_df '        dpkg -l 2>/dev/null | grep -iE "wine|mingw|widl" >&2 && \\'
    to_df '        echo "=== Files matching widl on filesystem: ===" >&2 && \\'
    to_df '        find / -iname "*widl*" -o -iname "*genidl*" 2>/dev/null >&2 && \\'
    to_df '        exit 1; \\'
    to_df '    fi && \\'
    to_df '    echo "Using widl: $WIDL" && \\'
    to_df '    cd /tmp/decklink-idl && \\'
    to_df '    "$WIDL" -h -H DeckLinkAPI.h DeckLinkAPI.idl && \\'
    to_df '    "$WIDL" -u -U DeckLinkAPI_i.c DeckLinkAPI.idl && \\'
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
