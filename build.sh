#!/bin/sh
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

set -e

### Function to do the task of the non-standard realpath utility.  This does
### not expand links, however.
expandpath() {
    (
        cd "$1" && pwd
    )
}

### Ensure >= go1.12 is installed.
go_ver_str="$(go version | cut -d ' ' -f 3)"
go_ver="${go_ver_str#go}"

oldIFS="$IFS"
IFS='.'
set -- $go_ver
IFS="$oldIFS"
go_maj="$1"
go_min="$2"

if [ "$go_maj" = "" ]
then
    printf "* Error: could not extract go version (version string: %s)\n" \
        "$go_ver_str"
    exit 1
fi

if [ "$go_min" = "" ]
then
    go_min=0
fi

if [ ! "$go_maj" -gt 1 ] && [ ! "$go_min" -ge 12 ]
then
    printf "* Error: go 1.12 or later is required (detected version: %s)\n" \
        "$go_maj"."$go_min".X
    exit 1
fi

### Create a temporary go tree in /tmp.
installdir="$(expandpath "$(dirname "$0")")"
godir="$(mktemp -d /tmp/mynewt.XXXXXXXXXX)"
mynewtdir="$godir"/src/mynewt.apache.org
repodir="$mynewtdir"/newt
newtdir="$repodir"/newt
dstfile="$installdir"/newt/newt

mkdir -p "$mynewtdir"
ln -s "$installdir" "$repodir"

### Collect version information.
GIT_HASH="$(git rev-parse --short HEAD || echo 'none')"
if [ $GIT_HASH != "none" ]; then
    GIT_DIRTY="$(git status --porcelain)"
    if [ ! -z "$GIT_DIRTY" ]; then
        GIT_HASH=$GIT_HASH"-dirty"
    fi
fi

DATE="$(date +%F_%R)"

### Build newt.
(
    cd "$newtdir"

    # Include the build date in `newt version`.
    EXTRA_OPTS="-X mynewt.apache.org/newt/newt/newtutil.NewtDate=$DATE"

    # Include the git hash and dirty state in `newt version`.
    if [ $GIT_HASH != "none" ]; then
        EXTRA_OPTS="${EXTRA_OPTS} -X mynewt.apache.org/newt/newt/newtutil.NewtGitHash=$GIT_HASH"
    fi

    # Allow the user to override the version reported by `newt version`.
    if [ "$NEWT_VERSION_STR" != "" ]
    then
        EXTRA_OPTS="${EXTRA_OPTS} -X mynewt.apache.org/newt/newt/newtutil.NewtVersionStr=$NEWT_VERSION_STR"
    fi

    printf "Building newt.  This may take a minute...\n"
    unset GOPATH
    go build -ldflags "$EXTRA_OPTS"

    printf "Successfully built executable: %s\n" "$dstfile"
)

### Delete the temporary directory.
# We have to relax permissions on the directory's contents; modules in
# $GOPATH/pkg are write-protected.
chmod -R 755 "$godir"
rm -rf "$godir"
